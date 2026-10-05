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
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    appDelegate.openSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            // Not Command-arrows, which text fields need for line start and end, and not
            // Control-arrows, which switch Spaces.
            CommandMenu("Pages") {
                Button("Previous Page") {
                    appDelegate.viewModel.showPreviousPage()
                }
                .keyboardShortcut("[", modifiers: .command)

                Button("Next Page") {
                    appDelegate.viewModel.showNextPage()
                }
                .keyboardShortcut("]", modifiers: .command)
            }
        }

    }
}
