import SwiftUI
import ForgeUI

struct ContentView: View {
    let viewModel: ToolsViewModel?

    var body: some View {
        ToolsView(viewModel: viewModel)
            .frame(minWidth: 480, minHeight: 320)
    }
}

#Preview {
    ContentView(viewModel: nil)
}
