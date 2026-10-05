import Foundation

/// The UserDefaults calls the settings stores make, so tests can inject an in-memory store
/// instead of writing a plist under ~/Library/Preferences.
protocol KeyValueStoring: AnyObject {
    func object(forKey defaultName: String) -> Any?
    func string(forKey defaultName: String) -> String?
    func data(forKey defaultName: String) -> Data?
    func integer(forKey defaultName: String) -> Int
    func double(forKey defaultName: String) -> Double
    func bool(forKey defaultName: String) -> Bool
    func set(_ value: Any?, forKey defaultName: String)
    func removeObject(forKey defaultName: String)
}

extension UserDefaults: KeyValueStoring {}
