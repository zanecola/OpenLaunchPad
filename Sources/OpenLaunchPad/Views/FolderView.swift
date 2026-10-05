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

    @State private var isHovered = false
    @Environment(LaunchpadDragState.self) private var dragState

    private var previewIcons: [NSImage] {
        folder.apps.prefix(9).map { iconProvider($0.bundleID) }
    }

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
                .scaleEffect(isHovered ? 1.08 : 1.0)
                .animation(.spring(duration: 0.15), value: isHovered)

            if showLabel {
                LaunchpadIconLabel(title: folder.title, iconSize: CGFloat(iconSize))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .onHover { isHovered = $0 }
    }

    // 3×3 icon grid inside a rounded-rect container (classic Launchpad folder look)
    private var folderIcon: some View {
        let cellSize = iconSize * 0.28
        let columns = Array(repeating: GridItem(.fixed(cellSize), spacing: 2), count: 3)

        return ZStack {
            RoundedRectangle(cornerRadius: iconSize * 0.22)
                .fill(.ultraThinMaterial)
                .frame(width: iconSize, height: iconSize)

            LazyVGrid(columns: columns, spacing: 2) {
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
            .padding(iconSize * 0.1)
        }
        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
    }
}

// MARK: - Expanded folder overlay

struct FolderExpandedView: View {
    let folder: FolderItem
    let iconSize: Double
    let showLabel: Bool
    let iconProvider: (String) -> NSImage
    var onLaunch: (AppItem) -> Void = { _ in }
    var onRename: (String) -> Void = { _ in }
    var onAppDrop: (LaunchpadDragPayload, AppItem, DropZone) -> Bool = { _, _, _ in false }
    var onAppDraggedOut: (LaunchpadDragPayload) -> Bool = { _ in false }
    var onClose: () -> Void = {}

    private let columns = 5
    @State private var draftTitle = ""
    @State private var appFrames: [UUID: CGRect] = [:]
    @State private var panelFrame: CGRect = .zero
    @State private var activeTarget: FolderDragHoverTarget?
    @State private var isDraggingOutside = false
    @FocusState private var isRenaming: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "pencil")
                    .foregroundStyle(.secondary)
                TextField("Folder Name", text: $draftTitle)
                    .font(.headline)
                    .textFieldStyle(.plain)
                    .focused($isRenaming)
                    .onSubmit(commitRename)
                Spacer()
                Button {
                    commitRename()
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close folder")
            }

            let gridColumns = Array(repeating: GridItem(.fixed(iconSize + 20), spacing: 12), count: columns)
            ScrollView(.vertical) {
                LazyVGrid(columns: gridColumns, spacing: 16) {
                    ForEach(folder.apps) { app in
                        AppIconView(
                            app: app,
                            icon: iconProvider(app.bundleID),
                            iconSize: iconSize * 0.7,
                            showLabel: showLabel,
                            isEditMode: false,
                            dragPayload: LaunchpadDragPayload(itemID: app.id, kind: .app),
                            onDragChanged: handleDragChanged,
                            onDragEnded: handleDragEnded,
                            onTap: { onLaunch(app) }
                        )
                        .overlay(alignment: activeTarget?.alignment(for: app.id) ?? .center) {
                            folderDragTargetIndicator(for: app.id)
                        }
                        .launchpadItemFrame(id: app.id)
                    }
                }
                .padding(.bottom, 18)
            }
            .frame(maxHeight: 420)
            .scrollIndicators(.hidden)
            .launchpadScrollAppearance()
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.16)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 26)
                .allowsHitTesting(false)
            }
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            if isDraggingOutside {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
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
                    .frame(width: iconSize * 0.7 + 20, height: iconSize * 0.7 + 20)
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
