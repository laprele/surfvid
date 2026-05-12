import AVFoundation
import Photos
import Combine

enum ExportError: Error {
    case sessionCreationFailed
    case assetUnavailable
    case photosAccessDenied
    case cancelled
    case unknown
}

class ExportManager: ObservableObject {
    // Callbacks set by AppViewModel before starting the export loop
    var onProgress: ((UUID, Float) -> Void)?
    var onClipComplete: ((UUID, URL) -> Void)?
    var onClipFailed: ((UUID, Error) -> Void)?

    // Retained to allow invalidation on unexpected deinit
    private var currentTimer: Timer?

    func exportClip(_ clip: AppViewModel.Clip, phAsset: PHAsset) async throws -> URL {
        // Step 1: Request AVAsset from Photos
        let avAsset = try await requestAVAsset(for: phAsset)

        // Step 2: Build unique output URL in temp directory
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mp4")

        // Step 3: Remove any pre-existing file at output path (Pitfall 2 guard)
        try? FileManager.default.removeItem(at: outputURL)

        // Step 4: Create export session with passthrough preset
        guard let session = AVAssetExportSession(
            asset: avAsset,
            presetName: AVAssetExportPresetPassthrough
        ) else {
            throw ExportError.sessionCreationFailed
        }

        // Step 5: Configure session
        session.outputURL = outputURL
        session.outputFileType = .mp4

        // Threat mitigation T-04-01: guard clip range validity before CMTimeRange construction
        guard clip.end > clip.start else {
            throw ExportError.unknown
        }
        session.timeRange = CMTimeRange(
            start: CMTimeMakeWithSeconds(clip.start, preferredTimescale: 600),
            end:   CMTimeMakeWithSeconds(clip.end,   preferredTimescale: 600)
        )

        // Step 6: Create progress polling timer — Pitfall 1 (no KVO) + Pitfall 3 (.common mode)
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.onProgress?(clip.id, session.progress)
        }
        RunLoop.main.add(timer, forMode: .common)
        currentTimer = timer

        // Step 7: Wrap exportAsynchronously in async/await via withCheckedThrowingContinuation
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.exportAsynchronously {
                // Invalidate timer immediately when export completes
                timer.invalidate()
                switch session.status {
                case .completed:
                    continuation.resume()
                case .failed:
                    continuation.resume(throwing: session.error ?? ExportError.unknown)
                case .cancelled:
                    continuation.resume(throwing: ExportError.cancelled)
                default:
                    continuation.resume(throwing: ExportError.unknown)
                }
            }
        }

        // Step 8: Return output URL after continuation resolves
        return outputURL
    }

    private func requestAVAsset(for phAsset: PHAsset) async throws -> AVAsset {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        // Use .highQualityFormat — export needs original bitstream, not iCloud proxy
        options.deliveryMode = .highQualityFormat

        return try await withCheckedThrowingContinuation { continuation in
            PHImageManager.default().requestAVAsset(
                forVideo: phAsset,
                options: options
            ) { avAsset, _, info in
                if let asset = avAsset {
                    continuation.resume(returning: asset)
                } else {
                    let error = info?[PHImageErrorKey] as? Error
                    continuation.resume(throwing: error ?? ExportError.assetUnavailable)
                }
            }
        }
    }

    func saveToPhotoLibrary(fileURL: URL) async throws {
        // App already holds .readWrite which is a superset of .addOnly — no additional prompt
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw ExportError.photosAccessDenied
        }

        // @Sendable annotation required for Swift 6 concurrency compliance (Pitfall 5)
        try await PHPhotoLibrary.shared().performChanges { @Sendable in
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
        }
    }

    deinit {
        // Safety net: invalidate timer if export is abandoned mid-flight
        currentTimer?.invalidate()
    }
}
