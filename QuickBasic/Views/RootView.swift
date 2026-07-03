import SwiftUI

struct RootView: View {
    @StateObject private var viewModel = IDEViewModel()

    var body: some View {
        RetroIDEView(viewModel: viewModel)
            .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}