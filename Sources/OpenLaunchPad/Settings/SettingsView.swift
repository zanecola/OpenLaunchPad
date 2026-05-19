import SwiftUI

struct SettingsView: View {
    @Environment(ConfigStore.self) private var config
    @Environment(LaunchpadViewModel.self) private var vm

    var body: some View {
        @Bindable var config = config

        TabView {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gear") }

            AppearanceSettingsTab()
                .tabItem { Label("Appearance", systemImage: "paintbrush") }

            ShortcutSettingsTab()
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
        }
        .frame(width: 480, height: 340)
        .environment(config)
        .environment(vm)
    }
}

// MARK: - General

private struct GeneralSettingsTab: View {
    @Environment(ConfigStore.self) private var config
    @Environment(LaunchpadViewModel.self) private var vm

    var body: some View {
        @Bindable var config = config

        Form {
            Section("Dock Icon") {
                Picker("Click action", selection: $config.dockClickMode) {
                    ForEach(DockClickMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Menu Bar") {
                Toggle("Show menu bar icon", isOn: $config.showMenuBarIcon)
            }

            Section("Layout") {
                Button("Reset to Launchpad Order") {
                    Task { await vm.resetToDefault() }
                }
                .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Appearance

private struct AppearanceSettingsTab: View {
    @Environment(ConfigStore.self) private var config

    var body: some View {
        @Bindable var config = config

        Form {
            Section("Icons") {
                HStack {
                    Text("Size")
                    Slider(value: $config.iconSize, in: 48...128, step: 4)
                    Text("\(Int(config.iconSize))pt")
                        .monospacedDigit()
                        .frame(width: 36)
                }

                Stepper("Columns: \(config.gridColumns == 0 ? "Auto" : "\(config.gridColumns)")",
                        value: $config.gridColumns, in: 0...12)

                Toggle("Show app labels", isOn: $config.iconLabelVisible)
            }

            Section("Window (Popup Mode)") {
                HStack {
                    Text("Width")
                    Slider(value: $config.paneWidth, in: 400...1400, step: 20)
                    Text("\(Int(config.paneWidth))")
                        .monospacedDigit()
                        .frame(width: 40)
                }
                HStack {
                    Text("Height")
                    Slider(value: $config.paneHeight, in: 300...900, step: 20)
                    Text("\(Int(config.paneHeight))")
                        .monospacedDigit()
                        .frame(width: 40)
                }
            }

            Section("Background") {
                HStack {
                    Text("Blur")
                    Slider(value: $config.backgroundBlur, in: 0...60)
                    Text("\(Int(config.backgroundBlur))")
                        .monospacedDigit()
                        .frame(width: 28)
                }
            }

            Section("Animation") {
                HStack {
                    Text("Speed")
                    Slider(value: $config.animationSpeed, in: 0.2...2.0, step: 0.1)
                    Text("\(config.animationSpeed, specifier: "%.1f")×")
                        .monospacedDigit()
                        .frame(width: 36)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Shortcuts

private struct ShortcutSettingsTab: View {
    @Environment(ConfigStore.self) private var config

    var body: some View {
        @Bindable var config = config

        Form {
            Section("Global Shortcut") {
                HStack {
                    Text("Open Launchpad")
                    Spacer()
                    ShortcutRecorderView(shortcut: $config.globalShortcut)
                        .frame(width: 150)
                    Button {
                        config.globalShortcut = nil
                    } label: {
                        Image(systemName: "xmark.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Clear shortcut")
                        .disabled(config.globalShortcut == nil)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
