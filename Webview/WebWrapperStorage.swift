import Foundation

final class WebWrapperStorage {
    private let userDefaults: UserDefaults

    init(suiteName: String = "com.monstertechno.webwrapper") {
        self.userDefaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    func set(_ value: String, forKey key: String) {
        userDefaults.set(value, forKey: key)
    }

    func get(forKey key: String) -> String? {
        userDefaults.string(forKey: key)
    }

    func remove(forKey key: String) {
        userDefaults.removeObject(forKey: key)
    }
}
