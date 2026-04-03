import SwiftUI

struct MenuBarView: View {
    @Environment(DictationController.self) private var controller
    @State private var selectedTab: MenuBarTab = .transcripts

    var body: some View {
        VStack(spacing: 0) {
            StatusBar()

            Divider()

            Group {
                switch selectedTab {
                case .transcripts:
                    TranscriptListView()
                case .settings:
                    SettingsView()
                case .about:
                    AboutView()
                }
            }
            .frame(maxHeight: .infinity)

            Divider()

            MenuBarBottomBar(selectedTab: $selectedTab)
        }
        .frame(width: 340, height: 450)
    }
}
