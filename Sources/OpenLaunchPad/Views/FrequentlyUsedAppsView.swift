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
        rowHeight = LaunchpadIconMetrics.cellHeight(
            for: iconSize,
            showsLabel: showsLabels
        ) + 24
    }
}

struct FrequentlyUsedAppsView: View {
    @Environment(LaunchpadViewModel.self) private var vm
    @Environment(ConfigStore.self) private var config

    let presentation: FrequentlyUsedAppsPresentation
    let onLaunch: (AppItem) -> Void

    var body: some View {
        if config.showFrequentlyUsedApps,
           !vm.frequentlyUsedApps(limit: 1).isEmpty {
            GeometryReader { proxy in
                let layout = FrequentlyUsedAppsLayout(
                    width: proxy.size.width,
                    configuredIconSize: config.iconSize,
                    showsLabels: config.iconLabelVisible,
                    presentation: presentation
                )
                let apps = vm.frequentlyUsedApps(limit: layout.visibleCount)

                VStack(spacing: 0) {
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
        let iconSize = min(config.iconSize, presentation.maximumIconSize)
        return LaunchpadIconMetrics.cellHeight(
            for: iconSize,
            showsLabel: config.iconLabelVisible
        ) + 24
    }
}
