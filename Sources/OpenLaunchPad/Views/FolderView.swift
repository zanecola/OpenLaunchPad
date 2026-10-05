import SwiftUI
import AppKit

struct FolderView: View {
    let folder: FolderItem
    let iconSize: Double
    let showLabel: Bool
    let isEditMode: Bool
    let iconProvider: (String) -> NSImage
    var dragPayload: LaunchpadDragPayload?
    var onDragChanged: (LaunchpadDragPayload, CGPoint) -> Void = { _, _ in }
    var onDragEnded: (LaunchpadDragPayload, CGPoint) -> Void = { _, _ in }
    var onOpen: () -> Void = {}
    var onLaunch: (AppItem) -> Void = { _ in }

    @State private var hover = LauncherHover()
    @Environment(LaunchpadViewModel.self) private var vm
    @Environment(LaunchpadDragState.self) private var dragState
    /// Also tells which backdrop the tile sits on: the dark full screen or the adaptive popup.
    @Environment(\.launchpadLabelStyle) private var labelStyle

    var body: some View {
        content
            .opacity(dragState.active?.payload.itemID == folder.id ? 0.35 : 1)
            .launchpadGestureDrag(
                payload: dragPayload,
                item: .folder(folder),
                onDragChanged: onDragChanged,
                onDragEnded: onDragEnded
            )
    }

    private var content: some View {
        VStack(spacing: 6) {
            folderIcon
                .scaleEffect(hover.isActive(in: vm.presentationID) ? 1.08 : 1.0)
                .animation(.spring(duration: 0.15), value: hover)

            if showLabel {
                LaunchpadIconLabel(title: folder.title, iconSize: CGFloat(iconSize))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .onHover { hover.update(isHovering: $0, presentationID: vm.presentationID) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(folder.title)
        .accessibilityValue(folder.apps.count == 1 ? "1 app" : "\(folder.apps.count) apps")
        .accessibilityHint("Opens folder")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, onOpen)
    }

    /// A 3×3 preview in an iconSize slot. The tile is 0.805 of the slot, the visible body of a macOS
    /// app icon, so it matches the apps beside it and its label sits on their baseline.
    private var folderIcon: some View {
        let slot = CGFloat(iconSize)
        let tile = slot * 0.805
        let cellSize = tile * 0.29
        let shape = RoundedRectangle(cornerRadius: tile * 0.225, style: .continuous)
        let columns = Array(repeating: GridItem(.fixed(cellSize), spacing: 0), count: 3)
        let previewIcons = folder.apps.prefix(9).map { iconProvider($0.bundleID) }

        return LazyVGrid(columns: columns, spacing: 0) {
            ForEach(0..<9, id: \.self) { i in
                if i < previewIcons.count {
                    Image(nsImage: previewIcons[i])
                        .resizable()
                        .frame(width: cellSize, height: cellSize)
                } else {
                    Color.clear.frame(width: cellSize, height: cellSize)
                }
            }
        }
        .padding(tile * 0.065)
        .frame(width: tile, height: tile)
        .background { tileFill(shape) }
        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
        .frame(width: slot, height: slot)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func tileFill(_ shape: RoundedRectangle) -> some View {
        switch labelStyle {
        case .onDarkBackdrop:
            Color.clear
                .glassEffect(.regular.tint(.white.opacity(0.08)), in: shape)
                .overlay(shape.strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
        case .adaptive:
            shape
                .fill(.quaternary)
                .overlay(shape.strokeBorder(.separator, lineWidth: 0.5))
        }
    }
}

/// Sizes an open folder to its apps: three to five columns, fewer when the space is narrower, and
/// up to three rows before the grid scrolls.
struct FolderPanelLayout {
    static let minimumColumns = 3
    static let maximumColumns = 5
    static let maximumVisibleRows = 3
    static let columnSpacing: CGFloat = 24
    static let rowSpacing: CGFloat = 20
    static let horizontalPadding: CGFloat = 32
    static let verticalPadding: CGFloat = 28
    static let titleHeight: CGFloat = 28
    static let titleSpacing: CGFloat = 12

    let iconSize: CGFloat
    let columnCount: Int
    let cellWidth: CGFloat
    let cellHeight: CGFloat
    let gridWidth: CGFloat
    /// The grid's viewport; more rows scroll.
    let gridHeight: CGFloat

    /// `availableSize` is the space the whole panel, padding and title included, may take.
    init(appCount: Int, iconSize: CGFloat, showsLabels: Bool, availableSize: CGSize) {
        // The same cells as the launcher grid (AppGridLayout).
        let cellWidth = iconSize + 40
        let cellHeight = LaunchpadIconMetrics.cellHeight(for: iconSize, showsLabel: showsLabels)
        let gridSpace = CGSize(
            width: availableSize.width - Self.horizontalPadding * 2,
            height: availableSize.height - Self.verticalPadding * 2 - Self.titleHeight - Self.titleSpacing
        )
        let fittingColumns = Int((gridSpace.width + Self.columnSpacing) / (cellWidth + Self.columnSpacing))
        let columnCount = max(1, min(max(appCount, Self.minimumColumns), Self.maximumColumns, fittingColumns))
        let rowCount = (max(appCount, 1) + columnCount - 1) / columnCount
        let visibleRows = CGFloat(min(rowCount, Self.maximumVisibleRows))

        self.iconSize = iconSize
        self.columnCount = columnCount
        self.cellWidth = cellWidth
        self.cellHeight = cellHeight
        gridWidth = CGFloat(columnCount) * cellWidth + CGFloat(columnCount - 1) * Self.columnSpacing
        gridHeight = max(0, min(visibleRows * cellHeight + (visibleRows - 1) * Self.rowSpacing, gridSpace.height))
    }
}

// MARK: - Expanded folder overlay

struct FolderExpandedView: View {
    let folder: FolderItem
    /// The launcher grid's icon size, so apps look the same inside the folder.
    let iconSize: Double
    let showLabel: Bool
    /// The space the panel may take; it is sized to its apps within it.
    let availableSize: CGSize
    let iconProvider: (String) -> NSImage
    var onLaunch: (AppItem) -> Void = { _ in }
    var onRename: (String) -> Void = { _ in }
    var onAppDrop: (LaunchpadDragPayload, AppItem, DropZone) -> Bool = { _, _, _ in false }
    var onAppDraggedOut: (LaunchpadDragPayload) -> Bool = { _ in false }
    var onClose: () -> Void = {}

    @State private var draftTitle = ""
    @State private var appFrames: [UUID: CGRect] = [:]
    @State private var panelFrame: CGRect = .zero
    @State private var activeTarget: FolderDragHoverTarget?
    @State private var isDraggingOutside = false
    @FocusState private var isRenaming: Bool

    private static let panelShape = RoundedRectangle(cornerRadius: 28, style: .continuous)

    var body: some View {
        let layout = FolderPanelLayout(
            appCount: folder.apps.count,
            iconSize: iconSize,
            showsLabels: showLabel,
            availableSize: availableSize
        )
        let gridColumns = Array(
            repeating: GridItem(.fixed(layout.cellWidth), spacing: FolderPanelLayout.columnSpacing, alignment: .top),
            count: layout.columnCount
        )

        VStack(spacing: FolderPanelLayout.titleSpacing) {
            // As in Launchpad, the title is the rename field: clicking it starts editing.
            TextField("Folder Name", text: $draftTitle)
                .font(.headline)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.center)
                .focused($isRenaming)
                .onSubmit(commitRename)
                // Equal insets keep the title centered clear of the close button.
                .padding(.horizontal, 28)
                .frame(height: FolderPanelLayout.titleHeight)
                .overlay(alignment: .trailing) {
                    Button {
                        commitRename()
                        onClose()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Close folder")
                    .accessibilityLabel("Close Folder")
                }

            ScrollView(.vertical) {
                LazyVGrid(columns: gridColumns, spacing: FolderPanelLayout.rowSpacing) {
                    ForEach(folder.apps) { app in
                        AppIconView(
                            app: app,
                            icon: iconProvider(app.bundleID),
                            iconSize: layout.iconSize,
                            showLabel: showLabel,
                            isEditMode: false,
                            dragPayload: LaunchpadDragPayload(itemID: app.id, kind: .app),
                            onDragChanged: handleDragChanged,
                            onDragEnded: handleDragEnded,
                            onTap: { onLaunch(app) }
                        )
                        .frame(width: layout.cellWidth, height: layout.cellHeight, alignment: .top)
                        .overlay(alignment: activeTarget?.alignment(for: app.id) ?? .center) {
                            folderDragTargetIndicator(for: app.id)
                        }
                        .launchpadItemFrame(id: app.id)
                    }
                }
            }
            .frame(height: layout.gridHeight)
            .scrollIndicators(.hidden)
            .launchpadScrollAppearance()
        }
        .frame(width: layout.gridWidth)
        .padding(.horizontal, FolderPanelLayout.horizontalPadding)
        .padding(.vertical, FolderPanelLayout.verticalPadding)
        .background(.regularMaterial, in: Self.panelShape)
        .overlay {
            if isDraggingOutside {
                Self.panelShape
                    .stroke(Color.primary.opacity(0.58), style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
            }
        }
        .onTapGesture {}  // absorb taps so background tap closes
        .transition(.scale(scale: 0.85).combined(with: .opacity))
        .onAppear { draftTitle = folder.title }
        .onChange(of: folder.title) { _, title in
            if !isRenaming { draftTitle = title }
        }
        .onChange(of: isRenaming) { wasRenaming, isRenaming in
            if wasRenaming && !isRenaming { commitRename() }
        }
        // Clicking outside, Escape and dismissing the launcher remove this view without
        // ending the text field's focus, so commit the draft here too.
        .onDisappear(perform: commitRename)
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { panelFrame = proxy.frame(in: .global) }
                    .onChange(of: proxy.frame(in: .global)) { _, frame in
                        panelFrame = frame
                    }
            }
        }
        .onPreferenceChange(LaunchpadItemFramePreferenceKey.self) { frames in
            appFrames = frames
        }
    }

    private func commitRename() {
        let name = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            draftTitle = folder.title
            return
        }
        draftTitle = name
        if name != folder.title {
            onRename(name)
        }
    }

    @ViewBuilder
    private func folderDragTargetIndicator(for appID: UUID) -> some View {
        if activeTarget?.appID == appID {
            switch activeTarget?.zone {
            case .leading, .trailing:
                Capsule()
                    .fill(Color.primary.opacity(0.82))
                    .frame(width: 4, height: iconSize * 0.62)
            case .center:
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.52), lineWidth: 2)
                    .frame(width: iconSize + 20, height: iconSize + 20)
            case nil:
                EmptyView()
            }
        }
    }

    private func handleDragChanged(payload: LaunchpadDragPayload, location: CGPoint) {
        guard payload.kind == .app else { return }
        activeTarget = hoverTarget(for: payload, at: location)
        isDraggingOutside = activeTarget == nil && !panelFrame.contains(location)
    }

    private func handleDragEnded(payload: LaunchpadDragPayload, location: CGPoint) {
        guard payload.kind == .app else { return }
        defer {
            activeTarget = nil
            isDraggingOutside = false
        }

        if let activeTarget,
           let targetApp = folder.apps.first(where: { $0.id == activeTarget.appID }) {
            _ = onAppDrop(payload, targetApp, activeTarget.zone)
            return
        }

        if !panelFrame.contains(location) {
            _ = onAppDraggedOut(payload)
        }
    }

    private func hoverTarget(for payload: LaunchpadDragPayload, at location: CGPoint) -> FolderDragHoverTarget? {
        guard let targetApp = folder.apps.first(where: { app in
            app.id != payload.itemID && appFrames[app.id]?.contains(location) == true
        }), let frame = appFrames[targetApp.id] else {
            return nil
        }
        return FolderDragHoverTarget(
            appID: targetApp.id,
            zone: DropZone.classify(x: location.x - frame.minX, width: frame.width)
        )
    }
}

private struct FolderDragHoverTarget: Equatable {
    let appID: UUID
    let zone: DropZone

    func alignment(for id: UUID) -> Alignment {
        guard appID == id else { return .center }
        switch zone {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}
