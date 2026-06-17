import SwiftUI

@main
struct WhisperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menu-bar app (no main window) — Settings scene is intentionally empty
        Settings { EmptyView() }
    }
}
