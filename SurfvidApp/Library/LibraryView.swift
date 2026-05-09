import SwiftUI
import Photos

struct LibraryView: View {
    @EnvironmentObject var appViewModel: AppViewModel

    var body: some View {
        switch appViewModel.authStatus {
        case .notDetermined:
            PermissionPromptView()
                .onAppear {
                    Task { await appViewModel.requestPhotosAccess() }
                }
        case .denied, .restricted:
            PermissionDeniedView()
        case .authorized, .limited:
            libraryContent
        @unknown default:
            PermissionPromptView()
                .onAppear {
                    Task { await appViewModel.requestPhotosAccess() }
                }
        }
    }

    private var libraryContent: some View {
        VStack(spacing: 0) {
            libraryHeader
            titleBlock
            tabRow
            if appViewModel.assets.isEmpty {
                emptyState
            } else {
                videoList
            }
        }
        .background(Color(.systemBackground))
    }

    // Header: "SURFVID" wordmark + video count badge
    private var libraryHeader: some View {
        HStack(alignment: .top) {
            Text("SURFVID")
                .font(.caption.weight(.medium))
                .tracking(1.2)
                .foregroundColor(Color(.secondaryLabel))
            Spacer()
            Text("\(appViewModel.assets.count) videos")
                .font(.caption)
                .foregroundColor(Color(.secondaryLabel))
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // Title + subtitle
    // UI-SPEC Typography: Display role — 38pt semibold SF Pro Display, tracking -1.4pt
    // UI-SPEC Copywriting: "Pick a recording" / "Skim it with your finger. Mark In and Out to clip."
    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Pick a recording")
                .font(.custom("SF Pro Display", size: 38))
                .fontWeight(.semibold)
                .tracking(-1.4)
                .foregroundColor(Color(.label))
            Text("Skim it with your finger. Mark In and Out to clip.")
                .font(.body)
                .foregroundColor(Color(.secondaryLabel))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    // Source tab bar: Photos (active) | iCloud | Files (inactive, v1 read-only)
    // UI-SPEC: active tab has accent underline 1.5pt; inactive tabs are secondaryLabel
    private var tabRow: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Active tab — "Photos"
                VStack(spacing: 4) {
                    Text("Photos")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color(.label))
                    Rectangle()
                        .fill(Color.orange)
                        .frame(height: 1.5)
                }
                .frame(maxWidth: .infinity)

                // Inactive tabs — not interactive in v1
                ForEach(["iCloud", "Files"], id: \.self) { label in
                    VStack(spacing: 4) {
                        Text(label)
                            .font(.subheadline)
                            .foregroundColor(Color(.secondaryLabel))
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 1.5)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 24)

            Divider()
        }
    }

    // Video list — List with .plain style; rows use LibraryCell
    // UI-SPEC LIB-01: most-recently-added first (LIB-02 satisfied by PHFetchRequest sort in AppViewModel)
    private var videoList: some View {
        List(appViewModel.assets, id: \.localIdentifier) { asset in
            LibraryCell(asset: asset)
                .onTapGesture { appViewModel.pickVideo(asset) }
                .listRowInsets(EdgeInsets(top: 16, leading: 24, bottom: 16, trailing: 24))
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
    }

    // Empty state — UI-SPEC States Required + Copywriting
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "film")
                .font(.system(size: 48, weight: .thin))
                .foregroundColor(Color(.tertiaryLabel))
            Text("No videos found")
                .font(.title2.weight(.semibold))
                .foregroundColor(Color(.label))
            Text("Your camera roll has no videos, or access is limited. Open Settings to change permissions.")
                .font(.body)
                .foregroundColor(Color(.secondaryLabel))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }
}

// MARK: - Permission Prompt View
// UI-SPEC: .notDetermined state — trigger iOS system dialog immediately (no custom pre-prompt)
struct PermissionPromptView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64, weight: .thin))
                .foregroundColor(Color(.tertiaryLabel))
            Text("Photos access required")
                .font(.title2.weight(.semibold))
            Text("Surfvid needs read access to your camera roll to show your videos.")
                .font(.body)
                .foregroundColor(Color(.secondaryLabel))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Permission Denied View
// UI-SPEC Copywriting: "Photos access required" + "Open Settings" CTA
struct PermissionDeniedView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64, weight: .thin))
                .foregroundColor(Color(.tertiaryLabel))
            Text("Photos access required")
                .font(.title2.weight(.semibold))
            Text("Surfvid needs read access to your camera roll to show your videos.")
                .font(.body)
                .foregroundColor(Color(.secondaryLabel))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.body.weight(.semibold))
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.orange)
            .foregroundColor(.white)
            .clipShape(Capsule())
            Spacer()
        }
        .background(Color(.systemBackground))
    }
}
