import SwiftUI
import Photos
import Combine

enum Screen { case library, skim, review }

class AppViewModel: ObservableObject {
    @Published var screen: Screen = .library
    @Published var authStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @Published var assets: [PHAsset] = []

    // Phase 2: clip marking — D-12: flat MVVM, all state in AppViewModel
    struct Clip: Identifiable {
        let id = UUID()
        let start: Double   // seconds
        let end: Double     // seconds
    }

    @Published var clips: [Clip] = []
    @Published var pendingIn: Double? = nil

    let playerController: PlayerController  // D-10: created once in init
    private var cancellables = Set<AnyCancellable>()

    init() {
        self.playerController = PlayerController()
        // Forward PlayerController @Published changes so SkimView re-renders (currentTime, isPlaying)
        playerController.objectWillChange
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
    }
}
