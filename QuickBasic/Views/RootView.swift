import SwiftUI

struct RootView: View {
    @StateObject private var viewModel = IDEViewModel()

    var body: some View {
        RetroIDEView(viewModel: viewModel)
            .onOpenURL { url in
                viewModel.openExternalURL(url)
            }
    }
}
