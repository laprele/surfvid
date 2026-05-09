import SwiftUI
import Photos
import Combine

enum Screen { case library, skim }

class AppViewModel: ObservableObject {
    @Published var screen: Screen = .library
    @Published var authStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @Published var assets: [PHAsset] = []

    let playerController: PlayerController  // D-10: created once in init

    init() {
        self.playerController = PlayerController()
    }

    func pickVideo(_ asset: PHAsset) {
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
}
