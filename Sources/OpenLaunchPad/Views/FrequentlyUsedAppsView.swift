import SwiftUI

/// Full screen's Frequently Used shelf: one row of unlabeled icons at 0.6 × the grid's icon size
/// on a bar centered between the search field and the grid.
struct FrequentlyUsedShelfLayout {
    static let maximumCount = 9
    static let spacing: CGFloat = 14
    static let horizontalPadding: CGFloat = 16
    static let verticalPadding: CGFloat = 10
    static let cornerRadius: CGFloat = 26
    /// Between the shelf and the grid.
    static let bottomPadding: CGFloat = 12

    let iconSize: CGFloat
    /// Nine, or fewer when nine would not fit `width`.
    let capacity: Int

    init(gridIconSize: CGFloat, width: CGFloat) {
        let iconSize = (gridIconSize * 0.6).rounded()
        let fittingCount = Int((width - Self.horizontalPadding * 2 + Self.spacing) / (iconSize + Self.spacing))
        self.iconSize = iconSize
        capacity = min(max(fittingCount, 1), Self.maximumCount)
    }

    var height: CGFloat {
        iconSize + Self.verticalPadding * 2
    }

    /// What the shelf takes from the grid's height, the gap below it included.
    var reservedHeight: CGFloat {
        height + Self.bottomPadding
    }
}

/// Full screen's Frequently Used apps. Icons have no labels; each names its app in a tooltip.
struct FrequentlyUsedShelf: View {
    @Environment(LaunchpadViewModel.self) private var vm
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let layout: FrequentlyUsedShelfLayout
    let onLaunch: (AppItem) -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: FrequentlyUsedShelfLayout.cornerRadius, style: .continuous)
        HStack(spacing: FrequentlyUsedShelfLayout.spacing) {
            ForEach(vm.frequentlyUsedApps.prefix(layout.capacity)) { app in
                AppIconView(
                    app: app,
                    icon: vm.icon(for: app.bundleID),
                    iconSize: layout.iconSize,
                    showLabel: false,
                    isEditMode: false,
                    onTap: { onLaunch(app) }
                )
                .help(app.title)
            }
        }
        .padding(.horizontal, FrequentlyUsedShelfLayout.horizontalPadding)
        .padding(.vertical, FrequentlyUsedShelfLayout.verticalPadding)
        .background {
            if reduceTransparency {
                // A solid step above the solid backdrop full screen draws then.
                shape.fill(Color(red: 44 / 255, green: 44 / 255, blue: 46 / 255))
            } else {
                Color.clear.glassEffect(.regular, in: shape)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Frequently used applications")
    }
}

/// The popup's Frequently Used apps: one row in the grid's columns between a "Frequently Used"
/// and an "All Apps" header, scrolling with the grid below it.
struct FrequentlyUsedSection: View {
    static let spacingBelowRow: CGFloat = 16

    @Environment(LaunchpadViewModel.self) private var vm
    @Environment(ConfigStore.self) private var config
    let layout: AppGridLayout
    let onLaunch: (AppItem) -> Void

    var body: some View {
        if config.showFrequentlyUsedApps, !vm.frequentlyUsedApps.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                header("Frequently Used")
                    .help("Apps you open from OpenLaunchPad, ranked by how often and how recently you use them. Choose where they appear in Settings.")

                HStack(spacing: layout.columnSpacing) {
                    ForEach(vm.frequentlyUsedApps.prefix(layout.columnCount)) { app in
                        AppIconView(
                            app: app,
                            icon: vm.icon(for: app.bundleID),
                            iconSize: layout.iconSize,
                            showLabel: config.iconLabelVisible,
                            isEditMode: false,
                            onTap: { onLaunch(app) }
                        )
                        .frame(width: layout.cellWidth, height: layout.cellHeight, alignment: layout.tileAlignment)
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Frequently used applications")

                header("All Apps")
                    .padding(.top, Self.spacingBelowRow)
            }
            .frame(width: layout.contentWidth, alignment: .leading)
        }
    }

    private func header(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            // Lines up with the first icon, which is centered in its cell.
            .padding(.leading, (layout.cellWidth - layout.iconSize) / 2)
            .padding(.bottom, 8)
            .accessibilityAddTraits(.isHeader)
    }
}
