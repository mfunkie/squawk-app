import SwiftUI

struct MenuBarBottomBar: View {
    @Binding var selectedTab: MenuBarTab

    var body: some View {
        HStack {
            Picker("", selection: $selectedTab) {
                ForEach(MenuBarTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Spacer()

            Button("Quit", action: quit)
                .keyboardShortcut("q")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
