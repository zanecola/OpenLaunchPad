import Foundation
import Testing
@testable import OpenLaunchPad

struct AppUsageHistoryTests {
    @Test
    func recordingLaunchesUpdatesCountAndKeepsLatestTimestamp() throws {
        let firstDate = Date(timeIntervalSince1970: 100)
        let secondDate = Date(timeIntervalSince1970: 200)
        var history = AppUsageHistory()

        history.recordLaunch(bundleID: "com.example.mail", at: secondDate)
        history.recordLaunch(bundleID: "com.example.mail", at: firstDate)

        let record = try #require(history.records.first)
        #expect(record.launchCount == 2)
        #expect(record.lastLaunchedAt == secondDate)
    }

    @Test
    func rankingPrefersFrequencyThenRecentUse() {
        let history = AppUsageHistory(records: [
            AppUsageRecord(
                bundleID: "com.example.frequent",
                launchCount: 3,
                lastLaunchedAt: Date(timeIntervalSince1970: 100)
            ),
            AppUsageRecord(
                bundleID: "com.example.recent",
                launchCount: 2,
                lastLaunchedAt: Date(timeIntervalSince1970: 300)
            ),
            AppUsageRecord(
                bundleID: "com.example.older",
                launchCount: 2,
                lastLaunchedAt: Date(timeIntervalSince1970: 200)
            )
        ])

        #expect(history.rankedBundleIDs(limit: 3) == [
            "com.example.frequent",
            "com.example.recent",
            "com.example.older"
        ])
    }

    @Test
    func userDefaultsStoreRoundTripsHistory() {
        let defaults = InMemoryKeyValueStore()
        let store = UserDefaultsAppUsageStore(defaults: defaults)
        let history = AppUsageHistory(records: [
            AppUsageRecord(
                bundleID: "com.example.mail",
                launchCount: 4,
                lastLaunchedAt: Date(timeIntervalSince1970: 500)
            )
        ])

        store.saveHistory(history)

        #expect(store.loadHistory() == history)
    }
}
