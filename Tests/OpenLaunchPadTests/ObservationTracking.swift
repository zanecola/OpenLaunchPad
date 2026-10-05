import Observation

/// Whether `change` invalidates a view whose body did what `read` does.
func observationFires(when change: () -> Void, reading read: () -> Void) -> Bool {
    let fired = Flag()
    withObservationTracking(read) { fired.value = true }
    change()
    return fired.value
}

/// onChange runs synchronously in the mutating property's willSet, so a plain flag is enough.
private final class Flag: @unchecked Sendable {
    var value = false
}
