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
        .frame(width: 520, height: 430)
        .environment(config)
        .environment(vm)
    }
}

// MARK: - General

private struct GeneralSettingsTab: View {
    @Environment(ConfigStore.self) private var config
    @Environment(LaunchpadViewModel.self) private var vm
    @State private var isConfirmingReset = false

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

            Section("Suggestions") {
                Toggle(
                    "Show Frequently Used row",
                    isOn: $config.showFrequentlyUsedApps
                )

                Text(
                    config.showFrequentlyUsedApps
                        ? "Shows a shortcut row above your apps, ranked by launch frequency and recency. Full screen leaves it out when your apps would not fit beside it."
                        : "The shortcut row is hidden. Existing usage history remains stored until cleared."
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Button("Clear Usage History") {
                    vm.clearAppUsageHistory()
                }
                .disabled(!vm.hasAppUsageHistory)

                Text("Only apps launched through OpenLaunchPad are recorded. This history stays on your Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Layout") {
                Button("Reset Layout…", role: .destructive) {
                    isConfirmingReset = true
                }
                .foregroundStyle(.red)
                .confirmationDialog("Reset Layout?", isPresented: $isConfirmingReset) {
                    Button("Reset Layout", role: .destructive) {
                        Task { await vm.resetToDefault() }
                    }
                } message: {
                    Text("Removes all folders and custom order. A backup is saved first.")
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Appearance

private struct AppearanceSettingsTab: View {
    @Environment(ConfigStore.self) private var config
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        @Bindable var config = config

        Form {
            Section("Icons") {
                HStack {
                    Text("Size")
                    Slider(value: $config.iconSize, in: ConfigStore.iconSizeRange, step: 4)
                    Text("\(Int(config.iconSize))pt")
                        .monospacedDigit()
                        .frame(width: 36)
                }

                Toggle("Show app labels", isOn: $config.iconLabelVisible)
            }

            Section("Full-Screen Layout") {
                Picker("Preferred columns", selection: $config.gridColumns) {
                    Text("Automatic").tag(0)
                    ForEach(4...12, id: \.self) { count in
                        Text("\(count)").tag(count)
                    }
                }

                Text("On smaller displays, full screen uses fewer columns or smaller icons, down to 48 pt, so the page fits.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("While open", selection: $config.autoHidesDockAndMenuBar) {
                    Text("Keep Dock and menu bar").tag(false)
                    Text("Auto-hide both").tag(true)
                }
            }

            Section("Popup Window") {
                Picker("Appearance", selection: $config.popupAppearance) {
                    ForEach(PopupAppearance.allCases, id: \.self) { appearance in
                        Text(appearance.rawValue).tag(appearance)
                    }
                }

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

                LabeledContent("Columns") {
                    Text("\(popupColumnCount) (automatic)")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Text("Popup columns adapt automatically when width or icon size changes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Background") {
                HStack {
                    Text("Dim")
                    Slider(value: $config.backgroundDim, in: ConfigStore.backgroundDimRange)
                    Text("\(Int((config.backgroundDim * 100).rounded()))%")
                        .monospacedDigit()
                        .frame(width: 36)
                }
                .disabled(reduceTransparency)

                Text(
                    reduceTransparency
                        ? "Reduce Transparency is on, so full screen uses a solid dark background."
                        : "Darkens the blurred background behind the full-screen launcher."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section("Animation") {
                Toggle("Animate page and folder transitions", isOn: $config.animatesTransitions)

                HStack {
                    Text("Speed")
                    Slider(value: $config.animationSpeed, in: ConfigStore.animationSpeedRange, step: 0.1)
                    Text("\(config.animationSpeed, specifier: "%.1f")×")
                        .monospacedDigit()
                        .frame(width: 36)
                }
                .disabled(!config.animatesTransitions)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var popupColumnCount: Int {
        AppGridLayout(
            size: CGSize(
                width: config.paneWidth,
                height: max(config.paneHeight - 70, 1)
            ),
            iconSize: config.iconSize,
            requestedColumns: 0,
            showsLabels: config.iconLabelVisible
        ).columnCount
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
