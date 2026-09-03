import SwiftUI

@main
struct LolaBodyApp: App {
    @StateObject private var coordinator = LolaBodyCoordinator()

    var body: some Scene {
        WindowGroup {
            LolaBodyRootView(coordinator: coordinator)
        }
    }
}
