import SwiftUI
import AppKit

struct FolderView: View {
    let folder: FolderItem
    let iconSize: Double
    let showLabel: Bool
    let isEditMode: Bool
    let iconProvider: (String) -> NSImage
    var dragPayload: LaunchpadDragPayload?
    var onDragEnded: (LaunchpadDragPayload, CGPoint) -> Void = { _, _ in }
    var onOpen: () -> Void = {}
    var onLaunch: (AppItem) -> Void = { _ in }

    @State private var isHovered = false

    private var previewIcons: [NSImage] {
        folder.apps.prefix(9).map { iconProvider($0.bundleID) }
    }

    var body: some View {
        content.launchpadGestureDrag(payload: dragPayload, onDragEnded: onDragEnded)
    }

    private var content: some View {
        VStack(spacing: 6) {
            folderIcon
                .scaleEffect(isHovered ? 1.08 : 1.0)
                .animation(.spring(duration: 0.15), value: isHovered)

            if showLabel {
                Text(folder.title)
                    .font(.system(size: max(10, iconSize * 0.145)))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 2)
                    .frame(maxWidth: iconSize + 16)
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
                            onDragEnded: handleDragEnded,
                            onTap: { onLaunch(app) }
                        )
                        .launchpadItemFrame(id: app.id)
                    }
                }
            }
            .frame(maxHeight: 420)
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .onTapGesture {}  // absorb taps so background tap closes
        .transition(.scale(scale: 0.85).combined(with: .opacity))
        .onAppear { draftTitle = folder.title }
        .onChange(of: folder.title) { _, title in
            if !isRenaming { draftTitle = title }
        }
        .onChange(of: isRenaming) { wasRenaming, isRenaming in
            if wasRenaming && !isRenaming { commitRename() }
        }
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
        onRename(name)
    }

    private func handleDragEnded(payload: LaunchpadDragPayload, location: CGPoint) {
        guard payload.kind == .app else { return }

        if let targetApp = folder.apps.first(where: { app in
            app.id != payload.itemID && appFrames[app.id]?.contains(location) == true
        }), let frame = appFrames[targetApp.id] {
            let zone = DropZone.classify(x: location.x - frame.minX, width: frame.width)
            _ = onAppDrop(payload, targetApp, zone)
            return
        }

        if !panelFrame.contains(location) {
            _ = onAppDraggedOut(payload)
        }
    }
}
