import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appViewModel: AppViewModel

    var body: some View {
        ZStack {
            switch appViewModel.screen {
            case .library:
                LibraryView()
                    .transition(.opacity)
            case .skim:
                SkimView()
                    .transition(.opacity)
            case .review:
                ReviewView()
                    .transition(.opacity)
            case .done:
                DoneView()
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: appViewModel.screen)
        .onChange(of: appViewModel.screen) { newScreen in
            switch newScreen {
            case .library:
                AppDelegate.lockOrientation(.portrait)
            case .skim:
                AppDelegate.lockOrientation(.landscape)
            case .review:
                AppDelegate.lockOrientation(.landscape)
            case .done:
                AppDelegate.lockOrientation(.landscape)
            }
        }
    }
}
