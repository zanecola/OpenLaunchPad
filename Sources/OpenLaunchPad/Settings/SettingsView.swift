import SwiftUI

/// The Settings window's panes, in toolbar order (see SettingsWindowController).
enum SettingsPane: CaseIterable {
    case general
    case appearance
    case shortcuts

    var title: String {
        switch self {
        case .general: "General"
        case .appearance: "Appearance"
        case .shortcuts: "Shortcuts"
        }
    }

    var systemImage: String {
        switch self {
        case .general: "gear"
        case .appearance: "paintbrush"
        case .shortcuts: "keyboard"
        }
    }

    @MainActor @ViewBuilder
    var content: some View {
        switch self {
        case .general: GeneralSettingsTab()
        case .appearance: AppearanceSettingsTab()
        case .shortcuts: ShortcutSettingsTab()
        }
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
                Picker("Frequently Used", selection: $config.frequentlyUsedPlacement) {
                    ForEach(FrequentlyUsedPlacement.allCases, id: \.self) { placement in
                        Text(placement.rawValue).tag(placement)
                    }
                }

                Text(frequentlyUsedDescription)
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
    }

    private var frequentlyUsedDescription: LocalizedStringKey {
        switch config.frequentlyUsedPlacement {
        case .off:
            "Hidden. Existing usage history remains stored until cleared."
        case .popupOnly:
            "A row above the popup's apps. They are ranked by launch frequency and recency when the launcher opens."
        case .popupAndFullScreen:
            "A row above the popup's apps, and a compact shelf below the full-screen search field when your apps fit beside it. They are ranked by launch frequency and recency when the launcher opens."
        }
    }
}

// MARK: - Appearance

private struct AppearanceSettingsTab: View {
    @Environment(ConfigStore.self) private var config
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var config = config

        Form {
            Section("Icons") {
                Picker("Size", selection: $config.iconSizeMode) {
                    ForEach(IconSizeMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                HStack {
                    Text("Custom size")
                    Slider(value: $config.customIconSize, in: ConfigStore.iconSizeRange, step: 4)
                    Text("\(Int(config.customIconSize))pt")
                        .monospacedDigit()
                        .frame(width: 40)
                }
                .dimsTextWhenDisabled()
                .disabled(config.iconSizeMode == .automatic)

                Text(
                    config.iconSizeMode == .automatic
                        ? "Full screen sizes icons to fill its grid. The popup uses 80 pt."
                        : "Full screen draws icons smaller, down to 48 pt, when its grid has no room for this size."
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Toggle("Show app labels", isOn: $config.iconLabelVisible)
            }

            Section("Full-Screen Layout") {
                Picker("Columns", selection: $config.gridColumns) {
                    ForEach(ConfigStore.gridColumnRange, id: \.self) { count in
                        Text("\(count)").tag(count)
                    }
                }
                Picker("Rows", selection: $config.gridRows) {
                    ForEach(ConfigStore.gridRowRange, id: \.self) { count in
                        Text("\(count)").tag(count)
                    }
                }

                Text("Each page holds \(config.pageCapacity) apps. Until you arrange your apps, they fill the pages in name order. After that, apps that no longer fit move to the next page, and extra slots stay free.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Page control", selection: $config.pageControlStyle) {
                    ForEach(PageControlStyle.allCases, id: \.self) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .pickerStyle(.segmented)

                Text("Dots + Arrows adds previous and next arrows that appear when you point at the dots.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Hide menu bar and Dock while open", isOn: $config.autoHidesDockAndMenuBar)

                Text("The grid then uses the whole screen; move the pointer to its edge to show them. macOS can only hide the menu bar together with the Dock.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Popup Window") {
                Picker("Appearance", selection: $config.popupAppearance) {
                    ForEach(PopupAppearance.allCases, id: \.self) { appearance in
                        Text(appearance.rawValue).tag(appearance)
                    }
                }

                Picker("Hover effect", selection: $config.popupHoverEffect) {
                    ForEach(TileHoverEffect.allCases, id: \.self) { effect in
                        Text(effect.rawValue).tag(effect)
                    }
                }
                .pickerStyle(.segmented)

                Text(hoverEffectDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)

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

            Section("Full-Screen Background") {
                Picker("Style", selection: $config.backgroundStyle) {
                    ForEach(BackdropStyle.allCases, id: \.self) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .pickerStyle(.segmented)

                HStack {
                    Text("Blur radius")
                    Slider(value: $config.backgroundBlurRadius, in: ConfigStore.backgroundBlurRadiusRange, step: 4)
                    Text("\(Int(config.backgroundBlurRadius))pt")
                        .monospacedDigit()
                        .frame(width: 40)
                }
                .dimsTextWhenDisabled()
                .disabled(config.backgroundStyle != .wallpaper)

                HStack {
                    Text("Dim")
                    Slider(value: $config.backgroundDim, in: ConfigStore.backgroundDimRange)
                    Text("\(Int((config.backgroundDim * 100).rounded()))%")
                        .monospacedDigit()
                        .frame(width: 36)
                }
                .dimsTextWhenDisabled()
                .disabled(drawnBackground == .solid)

                Text(backgroundDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Animation") {
                Toggle("Animate transitions", isOn: $config.animatesTransitions)

                HStack {
                    Text("Speed")
                    Slider(value: $config.animationSpeed, in: ConfigStore.animationSpeedRange, step: 0.1)
                    Text("\(config.animationSpeed, specifier: "%.1f")×")
                        .monospacedDigit()
                        .frame(width: 36)
                }
                .dimsTextWhenDisabled()
                .disabled(!config.animatesTransitions)

                Text(animationDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    /// Settings can't tell whether the wallpaper can be read, so they assume it can.
    private var drawnBackground: BackdropStyle {
        config.backgroundStyle.resolved(reduceTransparency: reduceTransparency, wallpaperAvailable: true)
    }

    private var backgroundDescription: String {
        switch drawnBackground {
        case .wallpaper:
            reduceTransparency
                ? "Your desktop picture, blurred and dimmed. When it can't be read, the background is solid dark."
                : "Your desktop picture, blurred and dimmed. When it can't be read, Glass is used instead."
        case .glass:
            "Blurs and dims the windows and desktop behind the launcher."
        case .solid:
            config.backgroundStyle == .solid
                ? "A solid dark background."
                : "Reduce Transparency is on, so Glass is replaced by a solid dark background."
        }
    }

    private var animationDescription: String {
        guard config.animatesTransitions else {
            return "The launcher and folders open and close at once, and pages turn at once."
        }
        return reduceMotion
            ? "Opening and closing the launcher and folders, launching an app and turning pages. Reduce Motion is on, so the launcher and folders fade without zooming, pages turn at once, and a pressed app darkens without shrinking."
            : "Opening and closing the launcher and folders, launching an app and turning pages."
    }

    private var hoverEffectDescription: String {
        let effect = switch config.popupHoverEffect {
        case .off: "Apps don't change under the pointer."
        case .highlight: "A rounded plate appears behind the app under the pointer."
        case .lift:
            reduceMotion
                ? "Reduce Motion is on, so the app under the pointer doesn't grow."
                : "The app under the pointer grows slightly."
        }
        return effect + " Full screen has no hover effect, as in Launchpad."
    }

    private var popupColumnCount: Int {
        AppGridLayout(
            size: CGSize(
                width: config.paneWidth,
                height: max(config.paneHeight - 70, 1)
            ),
            iconSize: config.popupIconSize,
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
    }
}

private extension View {
    /// macOS dims a disabled row's controls but not its text, so a slider's label and value would
    /// still read as active.
    func dimsTextWhenDisabled() -> some View {
        modifier(DimsTextWhenDisabled())
    }
}

private struct DimsTextWhenDisabled: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled

    func body(content: Content) -> some View {
        content.foregroundStyle(isEnabled ? .primary : .tertiary)
    }
}
