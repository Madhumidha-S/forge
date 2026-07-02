import SwiftUI
import ForgeUI

/// Legacy view — superseded by `RootView` in Phase 4E.
///
/// Kept as a thin wrapper around `RootView` so any remaining references
/// (previews, external callers) continue to compile. New code should use
/// `RootView` directly.
struct ContentView: View {
    var body: some View {
        RootView()
    }
}

#Preview {
    ContentView()
}
