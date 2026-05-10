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
            }
        }
        .animation(.easeOut(duration: 0.2), value: appViewModel.screen)
        .onChange(of: appViewModel.screen) { newScreen in
            switch newScreen {
            case .library:
                AppDelegate.lockOrientation(.portrait)
            case .skim:
                AppDelegate.lockOrientation(.landscape)
            }
        }
    }
}
