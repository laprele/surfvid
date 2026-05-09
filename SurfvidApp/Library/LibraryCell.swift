import SwiftUI
import Photos

struct LibraryCell: View {
    let asset: PHAsset
    @State private var thumbnail: UIImage? = nil
    @State private var requestID: PHImageRequestID = PHInvalidImageRequestID

    var body: some View {
        HStack(spacing: 14) {
            // Thumbnail — 56×72pt per UI-SPEC; clipShape matches prototype corner radius
            thumbnailView
                .frame(width: 56, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 4) {
                // Video title: use relative date as primary label (PHAsset has no user-facing filename)
                // Phase 2 will resolve the actual PHAsset resource filename if needed
                Text(asset.creationDate.map { relativeDate(for: $0) } ?? "Video")
                    .font(.body)
                    .foregroundColor(Color(.label))
                    .lineLimit(1)
                Text(metadataString)
                    .font(.caption)
                    .foregroundColor(Color(.secondaryLabel))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(Color(.tertiaryLabel))
        }
        .contentShape(Rectangle())
        .onAppear { loadThumbnail() }
        .onDisappear { cancelThumbnail() }
    }

    // UI-SPEC Library Row Thumbnail states: loading → placeholder; loaded → Image; failed → film symbol
    @ViewBuilder
    private var thumbnailView: some View {
        if let thumbnail {
            Image(uiImage: thumbnail)
                .resizable()
                .scaledToFill()
        } else {
            // UI-SPEC: Color(.secondarySystemFill) placeholder — no spinner
            Color(.secondarySystemFill)
        }
    }

    // UI-SPEC Copywriting: "{relative date} · {M:SS}" e.g. "Yesterday · 30:42"
    private var metadataString: String {
        let date = relativeDate(for: asset.creationDate ?? Date())
        let duration = formatDuration(asset.duration)
        return "\(date) · \(duration)"
    }

    // RESEARCH.md Pattern 3 — exact implementation required
    // deliveryMode .opportunistic fires handler TWICE: once degraded, once full quality
    // isSynchronous = false is MANDATORY — synchronous freezes main thread 100-500ms per cell (Pitfall 10)
    private func loadThumbnail() {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isSynchronous = false
        options.isNetworkAccessAllowed = true

        let targetSize = CGSize(width: 56 * 3, height: 72 * 3)  // @3x for retina

        requestID = PHImageManager.default().requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, info in
            // Handler fires on main thread for non-synchronous requests (RESEARCH.md Pattern 3)
            // Check PHImageResultIsDegradedKey to avoid flicker-to-blank (Pitfall 5)
            let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            if !isDegraded, let image = image {
                self.thumbnail = image  // final full-quality — always accept
            } else if self.thumbnail == nil, let image = image {
                self.thumbnail = image  // degraded first pass — use as placeholder
            }
        }
    }

    // Cancel in-flight request when cell scrolls off screen
    // Required to prevent zombie requests building up during fast scroll
    private func cancelThumbnail() {
        if requestID != PHInvalidImageRequestID {
            PHImageManager.default().cancelImageRequest(requestID)
            requestID = PHInvalidImageRequestID
        }
    }
}
