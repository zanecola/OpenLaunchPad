import SwiftUI

@main
struct OpenLaunchPadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environment(appDelegate.viewModel)
                .environment(appDelegate.config)
        }
        .commands {
            CommandMenu("Pages") {
                Button("Previous Page") {
                    appDelegate.viewModel.showPreviousPage()
                }
                .keyboardShortcut(.leftArrow, modifiers: .command)

                Button("Next Page") {
                    appDelegate.viewModel.showNextPage()
                }
                .keyboardShortcut(.rightArrow, modifiers: .command)
            }
        }

    }
}
