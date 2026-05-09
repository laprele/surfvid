import AVFoundation
import Photos
import Combine

class PlayerController: ObservableObject {
    let player = AVPlayer()
    private var cancellables = Set<AnyCancellable>()

    func load(asset: PHAsset) async {
        let videoOptions = PHVideoRequestOptions()
        videoOptions.isNetworkAccessAllowed = true
        videoOptions.deliveryMode = .automatic

        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestAVAsset(
                forVideo: asset,
                options: videoOptions
            ) { [weak self] avAsset, _, _ in
                guard let self, let avAsset = avAsset else {
                    continuation.resume()
                    return
                }
                let item = AVPlayerItem(asset: avAsset)

                let cancellable = item.publisher(for: \.status)
                    .filter { $0 != .unknown }
                    .first()
                    .sink { [weak self] status in
                        if status == .readyToPlay {
                            self?.player.pause()  // D-09: pause on first frame, no autoplay
                        }
                    }
                self.cancellables.insert(cancellable)

                DispatchQueue.main.async {
                    self.player.replaceCurrentItem(with: item)
                    continuation.resume()
                }
            }
        }
    }
}
