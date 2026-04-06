import AppKit

final class UsageTracker {

    struct UsageEntry: Codable {
        let keyEquivalent: String
        let modifiersRawValue: UInt
        var count: Int
    }

    struct TopEntry {
        let keyEquivalent: String
        let modifiers: NSEvent.ModifierFlags
        let count: Int
    }

    private var data: [String: [String: UsageEntry]] = [:]
    private let storageURL: URL

    init(storageURL: URL? = nil) {
        self.storageURL = storageURL ?? Self.defaultStorageURL()
        load()
    }

    static func defaultStorageURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("ShortcutDic", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("usage.json")
    }

    func record(bundleId: String, keyEquivalent: String, modifiers: NSEvent.ModifierFlags) {
        let key = "\(modifiers.rawValue)_\(keyEquivalent)"
        if data[bundleId] == nil {
            data[bundleId] = [:]
        }
        if var entry = data[bundleId]?[key] {
            entry.count += 1
            data[bundleId]?[key] = entry
        } else {
            data[bundleId]?[key] = UsageEntry(
                keyEquivalent: keyEquivalent,
                modifiersRawValue: modifiers.rawValue,
                count: 1
            )
        }
        save()
    }

    func topShortcuts(for bundleId: String, limit: Int) -> [TopEntry] {
        guard let appData = data[bundleId] else { return [] }
        return appData.values
            .sorted { $0.count > $1.count }
            .prefix(limit)
            .map { TopEntry(
                keyEquivalent: $0.keyEquivalent,
                modifiers: NSEvent.ModifierFlags(rawValue: $0.modifiersRawValue),
                count: $0.count
            ) }
    }

    func save() {
        guard let jsonData = try? JSONEncoder().encode(data) else { return }
        try? jsonData.write(to: storageURL, options: .atomic)
    }

    private func load() {
        guard let jsonData = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([String: [String: UsageEntry]].self, from: jsonData) else {
            return
        }
        data = decoded
    }
}
