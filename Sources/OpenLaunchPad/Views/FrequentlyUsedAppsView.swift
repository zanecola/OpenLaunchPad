import SwiftUI

enum FrequentlyUsedAppsPresentation {
    case fullScreen
    case popup

    var maximumIconSize: CGFloat {
        switch self {
        case .fullScreen: 80
        case .popup: 72
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .fullScreen: 40
        case .popup: 24
        }
    }
}

struct FrequentlyUsedAppsLayout {
    static let headerHeight: CGFloat = 26

    let visibleCount: Int
    let iconSize: CGFloat
    let cellWidth: CGFloat
    let spacing: CGFloat
    let rowHeight: CGFloat

    init(
        width: CGFloat,
        configuredIconSize: CGFloat,
        showsLabels: Bool,
        presentation: FrequentlyUsedAppsPresentation,
        maximumCount: Int = 7
    ) {
        let iconSize = min(configuredIconSize, presentation.maximumIconSize)
        let cellWidth = iconSize + 32
        let availableWidth = max(width - presentation.horizontalPadding * 2, cellWidth)
        let minimumSpacing: CGFloat = 12
        let fittingCount = max(
            1,
            Int((availableWidth + minimumSpacing) / (cellWidth + minimumSpacing))
        )
        let visibleCount = min(max(maximumCount, 0), fittingCount)
        let naturalSpacing = visibleCount > 1
            ? (availableWidth - CGFloat(visibleCount) * cellWidth) / CGFloat(visibleCount - 1)
            : 0

        self.visibleCount = visibleCount
        self.iconSize = iconSize
        self.cellWidth = cellWidth
        spacing = visibleCount > 1 ? min(max(naturalSpacing, minimumSpacing), 80) : 0
        rowHeight = Self.rowHeight(
            configuredIconSize: configuredIconSize,
            showsLabels: showsLabels,
            presentation: presentation
        )
    }

    static func rowHeight(
        configuredIconSize: CGFloat,
        showsLabels: Bool,
        presentation: FrequentlyUsedAppsPresentation
    ) -> CGFloat {
        LaunchpadIconMetrics.cellHeight(
            for: min(configuredIconSize, presentation.maximumIconSize),
            showsLabel: showsLabels
        ) + 24 + headerHeight
    }
}

struct FrequentlyUsedAppsView: View {
    @Environment(LaunchpadViewModel.self) private var vm
    @Environment(ConfigStore.self) private var config

    let presentation: FrequentlyUsedAppsPresentation
    /// Overrides the configured icon size, so full screen can shrink the row with its grid.
    var iconSize: CGFloat?
    let onLaunch: (AppItem) -> Void

    var body: some View {
        if config.showFrequentlyUsedApps,
           !vm.frequentlyUsedApps(limit: 1).isEmpty {
            GeometryReader { proxy in
                let layout = FrequentlyUsedAppsLayout(
                    width: proxy.size.width,
                    configuredIconSize: iconSize ?? config.iconSize,
                    showsLabels: config.iconLabelVisible,
                    presentation: presentation
                )
                let apps = vm.frequentlyUsedApps(limit: layout.visibleCount)

                VStack(spacing: 0) {
                    HStack {
                        Label("Frequently Used", systemImage: "clock.arrow.circlepath")
                            .font(.caption.weight(.semibold))
                            .help(
                                "Apps launched through OpenLaunchPad are ranked by how often "
                                    + "and how recently you use them. You can turn this off in Settings."
                            )

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, presentation.horizontalPadding)
                    .frame(height: FrequentlyUsedAppsLayout.headerHeight)
                    .accessibilityElement(children: .combine)

                    HStack(spacing: layout.spacing) {
                        ForEach(apps) { app in
                            AppIconView(
                                app: app,
                                icon: vm.icon(for: app.bundleID),
                                iconSize: layout.iconSize,
                                showLabel: config.iconLabelVisible,
                                isEditMode: false,
                                onTap: { onLaunch(app) }
                            )
                            .frame(
                                width: layout.cellWidth,
                                height: LaunchpadIconMetrics.cellHeight(
                                    for: layout.iconSize,
                                    showsLabel: config.iconLabelVisible
                                ),
                                alignment: .top
                            )
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)

                    Divider()
                }
            }
            .frame(height: rowHeight)
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Frequently used applications")
        }
    }

    private var rowHeight: CGFloat {
        FrequentlyUsedAppsLayout.rowHeight(
            configuredIconSize: iconSize ?? config.iconSize,
            showsLabels: config.iconLabelVisible,
            presentation: presentation
        )
    }
}
