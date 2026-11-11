import SwiftUI

@main
struct MacUpdateScannerApp: App {
    @StateObject private var model = ScannerModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 850, minHeight: 560)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
    }
}
