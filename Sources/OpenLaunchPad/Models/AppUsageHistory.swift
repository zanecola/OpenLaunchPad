import Foundation

struct AppUsageRecord: Codable, Equatable, Sendable {
    let bundleID: String
    var launchCount: Int
    var lastLaunchedAt: Date
}

struct AppUsageHistory: Equatable, Sendable {
    private(set) var recordsByBundleID: [String: AppUsageRecord]

    init(records: [AppUsageRecord] = []) {
        recordsByBundleID = [:]
        for record in records where !record.bundleID.isEmpty && record.launchCount > 0 {
            if let existing = recordsByBundleID[record.bundleID] {
                recordsByBundleID[record.bundleID] = AppUsageRecord(
                    bundleID: record.bundleID,
                    launchCount: max(existing.launchCount, record.launchCount),
                    lastLaunchedAt: max(existing.lastLaunchedAt, record.lastLaunchedAt)
                )
            } else {
                recordsByBundleID[record.bundleID] = record
            }
        }
    }

    var records: [AppUsageRecord] {
        recordsByBundleID.values.sorted { $0.bundleID < $1.bundleID }
    }

    mutating func recordLaunch(bundleID: String, at date: Date) {
        guard !bundleID.isEmpty else { return }
        var record = recordsByBundleID[bundleID] ?? AppUsageRecord(
            bundleID: bundleID,
            launchCount: 0,
            lastLaunchedAt: date
        )
        record.launchCount += 1
        record.lastLaunchedAt = max(record.lastLaunchedAt, date)
        recordsByBundleID[bundleID] = record
    }

    mutating func remove(bundleID: String) {
        recordsByBundleID.removeValue(forKey: bundleID)
    }

    mutating func removeAll() {
        recordsByBundleID.removeAll()
    }

    func rankedBundleIDs(limit: Int) -> [String] {
        guard limit > 0 else { return [] }
        return recordsByBundleID.values
            .sorted {
                if $0.launchCount != $1.launchCount {
                    return $0.launchCount > $1.launchCount
                }
                if $0.lastLaunchedAt != $1.lastLaunchedAt {
                    return $0.lastLaunchedAt > $1.lastLaunchedAt
                }
                return $0.bundleID < $1.bundleID
            }
            .prefix(limit)
            .map(\.bundleID)
    }
}
