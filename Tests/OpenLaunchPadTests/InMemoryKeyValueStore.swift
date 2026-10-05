import Foundation
@testable import OpenLaunchPad

/// Stands in for UserDefaults so settings tests never create a plist in ~/Library/Preferences.
final class InMemoryKeyValueStore: KeyValueStoring {
    private var values: [String: Any] = [:]

    func object(forKey defaultName: String) -> Any? { values[defaultName] }
    func string(forKey defaultName: String) -> String? { values[defaultName] as? String }
    func data(forKey defaultName: String) -> Data? { values[defaultName] as? Data }
    func integer(forKey defaultName: String) -> Int { (values[defaultName] as? NSNumber)?.intValue ?? 0 }
    func double(forKey defaultName: String) -> Double { (values[defaultName] as? NSNumber)?.doubleValue ?? 0 }
    func bool(forKey defaultName: String) -> Bool { (values[defaultName] as? NSNumber)?.boolValue ?? false }
    func set(_ value: Any?, forKey defaultName: String) { values[defaultName] = value }
    func removeObject(forKey defaultName: String) { values[defaultName] = nil }
}
