import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    static let shared = AppDelegate()
    var orientationLock: UIInterfaceOrientationMask = .portrait

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        return orientationLock
    }

    func lockOrientation(_ mask: UIInterfaceOrientationMask) {
        orientationLock = mask
        UIApplication.shared.connectedScenes.forEach { scene in
            guard let windowScene = scene as? UIWindowScene else { return }
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
            windowScene.keyWindow?.rootViewController?
                .setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }
}
