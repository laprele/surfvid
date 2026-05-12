import SwiftUI
import Photos
import Combine

enum Screen { case library, skim, review, done }

class AppViewModel: ObservableObject {
    @Published var screen: Screen = .library
    @Published var authStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @Published var assets: [PHAsset] = []

    // Phase 2: clip marking — D-12: flat MVVM, all state in AppViewModel
    struct Clip: Identifiable {
        let id = UUID()
        let start: Double   // seconds
        let end: Double     // seconds
        // Phase 4: export state
        var exportProgress: Float = 0.0     // 0.0–1.0, polled from AVAssetExportSession.progress
        var exportedURL: URL? = nil         // set after successful export; nil = not yet exported
    }

    @Published var clips: [Clip] = []
    @Published var pendingIn: Double? = nil
    // Phase 4: export state
    @Published var isExporting: Bool = false
    @Published var currentAsset: PHAsset? = nil     // set in pickVideo; used by startExport

    let playerController: PlayerController  // D-10: created once in init
    let exportManager: ExportManager        // Phase 4: export lifecycle manager
    private var cancellables = Set<AnyCancellable>()

    init() {
        self.playerController = PlayerController()
        self.exportManager = ExportManager()
        // Forward PlayerController @Published changes so SkimView re-renders (currentTime, isPlaying)
        playerController.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        // Forward ExportManager objectWillChange so views observe export state changes
        exportManager.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        // D-06: Returning user with previously granted access sees library immediately,
        // without waiting for requestPhotosAccess() to trigger the fetch.
        if authStatus == .authorized || authStatus == .limited {
            fetchVideos()
        }
    }

    func pickVideo(_ asset: PHAsset) {
        resetForNewVideo()          // reset clip state on each new video load
        currentAsset = asset        // Phase 4: retain for export (set after reset to avoid nil)
        Task {
            await playerController.load(asset: asset)
            await MainActor.run { screen = .skim }
        }
    }

    func requestPhotosAccess() async {
        let status = await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
        await MainActor.run {
            self.authStatus = status
            if status == .authorized || status == .limited {
                self.fetchVideos()
            }
        }
    }

    func fetchVideos() {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType = %d",
                                        PHAssetMediaType.video.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate",
                                                    ascending: false)]
        let result = PHAsset.fetchAssets(with: options)
        var fetched: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in fetched.append(asset) }
        self.assets = fetched
    }

    // D-08: Double-In resets pendingIn — no confirmation, no append.
    func markIn(at time: Double) {
        pendingIn = time
    }

    // D-07: Out before In → autoIn = max(0, time - 15s). Pitfall 7: zero-duration guard.
    func markOut(at time: Double) {
        if let inTime = pendingIn {
            let start = min(inTime, time)
            let end = max(inTime, time)
            guard end > start else { return }
            clips.append(Clip(start: start, end: end))
            pendingIn = nil
        } else {
            let autoIn = max(0, time - 15.0)
            clips.append(Clip(start: autoIn, end: time))
        }
    }

    func resetForNewVideo() {
        clips = []
        pendingIn = nil
        isExporting = false     // Phase 4
        currentAsset = nil      // Phase 4
    }

    // Phase 4: Export all clips sequentially using ExportManager
    func startExport() {
        guard !clips.isEmpty, !isExporting, let asset = currentAsset else { return }
        isExporting = true

        // Wire progress callback — updates per-clip progress on main actor
        exportManager.onProgress = { [weak self] id, progress in
            guard let self else { return }
            if let i = self.clips.firstIndex(where: { $0.id == id }) {
                self.clips[i].exportProgress = progress
            }
        }

        // Wire completion callback — marks clip as done on main actor
        exportManager.onClipComplete = { [weak self] id, url in
            guard let self else { return }
            if let i = self.clips.firstIndex(where: { $0.id == id }) {
                self.clips[i].exportedURL = url
                self.clips[i].exportProgress = 1.0
            }
        }

        // Wire failure callback — leaves clip at current progress state
        exportManager.onClipFailed = { [weak self] id, _ in
            guard let self else { return }
            // Clip stays at whatever progress it reached; no UI change beyond that
            _ = self.clips.firstIndex(where: { $0.id == id })
        }

        // Run sequential export loop in a Task
        Task {
            for clip in clips {
                do {
                    let url = try await exportManager.exportClip(clip, phAsset: asset)
                    try await exportManager.saveToPhotoLibrary(fileURL: url)
                    exportManager.onClipComplete?(clip.id, url)
                } catch {
                    exportManager.onClipFailed?(clip.id, error)
                }
            }
            isExporting = false
            screen = .done
        }
    }
}
