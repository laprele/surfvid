import AVFoundation
import Photos
import Combine
import QuartzCore

class PlayerController: ObservableObject {
    let player = AVPlayer()
    private var cancellables = Set<AnyCancellable>()

    // Phase 2 playback state — consumed by SkimView
    @Published var currentTime: Double = 0
    @Published var isPlaying: Bool = false
    var duration: Double = 0          // set from AVAsset after load; no @Published needed
    var isScrubbing: Bool = false     // set by SkimView DragGesture; guards time observer

    // Seek throttle state (QA1820 chase-time pattern)
    private var chaseTime: CMTime = .zero
    private var isSeekInProgress = false
    private var timeObserverToken: Any?

    // CADisplayLink state
    private var displayLink: CADisplayLink?

    // Retain-cycle-safe proxy: CADisplayLink retains the proxy, not self.
    // Source: RESEARCH.md Pattern 1 (Apple CADisplayLink docs)
    private class DisplayLinkTarget: NSObject {
        weak var owner: PlayerController?
        @objc func tick(link: CADisplayLink) {
            owner?.onDisplayLinkTick()
        }
    }

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
                            self?.isPlaying = false   // sync published state
                        }
                    }
                self.cancellables.insert(cancellable)

                DispatchQueue.main.async {
                    self.player.replaceCurrentItem(with: item)
                    self.duration = avAsset.duration.seconds
                    self.setupTimeObserver()
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Seek throttle (D-05 / QA1820)

    /// Accumulate seek target from DragGesture — does NOT call seek() directly.
    /// Called on every DragGesture.onChanged; actual seek fires on the next display-link tick.
    func updateSeekTarget(_ time: Double) {
        chaseTime = CMTimeMakeWithSeconds(max(0, time), preferredTimescale: 600)
    }

    /// Chase-time flush — called from onDisplayLinkTick (60fps max, one seek in-flight at a time).
    /// Non-zero tolerance = keyframe-accurate seek (~30ms latency). Pitfall 5: never zero-tolerance here.
    private func flushPendingSeek() {
        guard !isSeekInProgress,
              player.currentItem?.status == .readyToPlay else { return }  // Pitfall 1 guard
        let target = chaseTime
        isSeekInProgress = true
        player.seek(
            to: target,
            toleranceBefore: CMTime(seconds: 0.5, preferredTimescale: 600),
            toleranceAfter:  CMTime(seconds: 0.5, preferredTimescale: 600)
        ) { [weak self] finished in
            guard let self else { return }
            if finished {
                self.isSeekInProgress = false
                // Chase if target moved while seek was in-flight
                if CMTimeCompare(self.chaseTime, target) != 0 {
                    self.flushPendingSeek()
                }
            }
            // !finished = interrupted by newer seek; new seek will call this handler when done
        }
    }

    /// Zero-tolerance exact-frame seek — D-05: called ONLY on In/Out mark commit.
    func seekExact(to time: Double) {
        let target = CMTimeMakeWithSeconds(max(0, time), preferredTimescale: 600)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) { _ in }
    }

    // MARK: - CADisplayLink (D-05)

    func startDisplayLink() {
        guard displayLink == nil else { return }
        let proxy = DisplayLinkTarget()
        proxy.owner = self
        let link = CADisplayLink(target: proxy, selector: #selector(DisplayLinkTarget.tick(link:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil   // nil after invalidate to break proxy retain (Pitfall 4)
    }

    private func onDisplayLinkTick() {
        flushPendingSeek()
        // During scrub, update currentTime directly from player (bypasses observer — Pitfall 2)
        currentTime = player.currentTime().seconds
    }

    // MARK: - Periodic time observer (SKIM-06)

    func setupTimeObserver() {
        // Remove any existing observer before adding a new one (safe on repeated load)
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            guard let self, !self.isScrubbing else { return }  // Pitfall 2: guard during scrub
            self.currentTime = time.seconds
        }
    }

    // MARK: - Play/Pause (SKIM-04, D-02)

    func togglePlayPause() {
        if player.timeControlStatus == .playing {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }

    // MARK: - Lifecycle

    deinit {
        stopDisplayLink()
        if let token = timeObserverToken {
            player.removeTimeObserver(token)  // Pitfall 6: mandatory before deinit
        }
    }
}
