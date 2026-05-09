import SwiftUI
import AVFoundation

struct PlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        // PITFALL GUARD: add this print during development to confirm makeUIView fires once
        print("[PlayerView] makeUIView called — should fire exactly once per app launch")
        let view = PlayerUIView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill  // full-bleed per UI-SPEC
        return view
    }

    // CRITICAL: updateUIView must ONLY update properties — never recreate AVPlayerLayer
    // Recreating the layer causes the black screen bug (RESEARCH.md Pitfall 3)
    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.playerLayer.player = player  // safe: same AVPlayer reference on every rebuild
    }
}

// PlayerUIView: UIView subclass whose backing layer is AVPlayerLayer
// This is the correct pattern — do not add AVPlayerLayer as a sublayer of a plain UIView
class PlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
