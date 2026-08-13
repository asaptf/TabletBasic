import Foundation

enum LessonProgressStore {
    static let storageKey = "tabletbasic.completedLessonIDs"

    static func completedIDs(defaults: UserDefaults = .standard) -> Set<String> {
        Set(defaults.stringArray(forKey: storageKey) ?? [])
    }

    static func isComplete(_ id: String, defaults: UserDefaults = .standard) -> Bool {
        completedIDs(defaults: defaults).contains(id)
    }

    static func markComplete(_ id: String, defaults: UserDefaults = .standard) {
        var ids = completedIDs(defaults: defaults)
        ids.insert(id)
        defaults.set(Array(ids).sorted(), forKey: storageKey)
    }

    static func reset(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: storageKey)
    }
}
