import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    // Static so the value is shared between the SwiftUI-created instance (which
    // receives delegate callbacks) and any caller that holds a different reference.
    // @UIApplicationDelegateAdaptor creates its own instance; a separate `shared`
    // singleton would give the system delegate a stale .portrait lock forever.
    static var orientationLock: UIInterfaceOrientationMask = .portrait

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        AppDelegate.orientationLock
    }

    static func lockOrientation(_ mask: UIInterfaceOrientationMask) {
        orientationLock = mask
        UIApplication.shared.connectedScenes.forEach { scene in
            guard let windowScene = scene as? UIWindowScene else { return }
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
            windowScene.keyWindow?.rootViewController?
                .setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }
}
