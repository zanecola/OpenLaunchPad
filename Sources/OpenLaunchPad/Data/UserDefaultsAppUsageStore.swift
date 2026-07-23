import Foundation

final class UserDefaultsAppUsageStore: AppUsageStoring {
    private static let currentVersion = 1
    private static let storageKey = "appUsageHistory"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = UserDefaults(suiteName: "com.openlaunchpad") ?? .standard) {
        self.defaults = defaults
    }

    func loadHistory() -> AppUsageHistory {
        guard let data = defaults.data(forKey: Self.storageKey),
              let stored = try? JSONDecoder().decode(StoredAppUsageHistory.self, from: data),
              stored.version == Self.currentVersion else {
            return AppUsageHistory()
        }
        return AppUsageHistory(records: stored.records)
    }

    func saveHistory(_ history: AppUsageHistory) {
        let stored = StoredAppUsageHistory(
            version: Self.currentVersion,
            records: history.records
        )
        guard let data = try? JSONEncoder().encode(stored) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}

private struct StoredAppUsageHistory: Codable {
    let version: Int
    let records: [AppUsageRecord]
}
