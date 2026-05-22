enum ItemPlacement: Equatable, Sendable {
    case before
    case after
}

enum DropZone: Equatable, Sendable {
    case leading
    case center
    case trailing

    static func classify(x: Double, width: Double) -> Self {
        guard width > 0 else { return .center }

        let fraction = min(max(x / width, 0), 1)
        if fraction < 0.25 { return .leading }
        if fraction >= 0.75 { return .trailing }
        return .center
    }
}

enum LaunchpadDropIntent: Equatable, Sendable {
    case reorder(ItemPlacement)
    case combineApps
    case addToFolder

    static func resolve(source: LaunchpadDragKind, target: LaunchpadDragKind, zone: DropZone) -> Self {
        switch zone {
        case .leading:
            return .reorder(.before)
        case .trailing:
            return .reorder(.after)
        case .center where source == .app && target == .app:
            return .combineApps
        case .center where source == .app && target == .folder:
            return .addToFolder
        case .center:
            return .reorder(.after)
        }
    }
}
