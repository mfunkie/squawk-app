import SwiftUI

struct MenuBarView: View {
    var body: some View {
        VStack(spacing: 0) {
            StatusBar()

            Divider()

            TranscriptListView()
                .frame(maxHeight: .infinity)

            Divider()

            MenuBarBottomBar()
        }
        .frame(width: 340, height: 450)
    }
}
