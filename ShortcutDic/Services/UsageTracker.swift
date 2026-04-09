import AppKit

@MainActor
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
        let base = storageURL ?? Self.defaultStorageURL()
        self.storageURL = base
        self.recentStorageURL = base.deletingLastPathComponent().appendingPathComponent("recent.json")
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

    // MARK: - Recent Interactions (from search mode)

    struct RecentEntry: Codable {
        let keyEquivalent: String
        let modifiersRawValue: UInt
        let title: String
        let menuPath: String
        let timestamp: Date
    }

    private var recentData: [String: [RecentEntry]] = [:]
    private let recentStorageURL: URL

    func recordRecent(bundleId: String, shortcut: Shortcut) {
        var entries = recentData[bundleId] ?? []
        // Remove duplicate if exists
        entries.removeAll {
            $0.keyEquivalent == shortcut.keyEquivalent &&
            $0.modifiersRawValue == shortcut.modifiers.rawValue
        }
        entries.insert(RecentEntry(
            keyEquivalent: shortcut.keyEquivalent,
            modifiersRawValue: shortcut.modifiers.rawValue,
            title: shortcut.title,
            menuPath: shortcut.menuPath,
            timestamp: Date()
        ), at: 0)
        // Keep max 20 per app
        if entries.count > 20 { entries = Array(entries.prefix(20)) }
        recentData[bundleId] = entries
        saveRecent()
    }

    func recentShortcuts(for bundleId: String, limit: Int) -> [RecentEntry] {
        Array((recentData[bundleId] ?? []).prefix(limit))
    }

    // MARK: - Persistence

    func save() {
        guard let jsonData = try? JSONEncoder().encode(data) else { return }
        try? jsonData.write(to: storageURL, options: .atomic)
    }

    private func saveRecent() {
        guard let jsonData = try? JSONEncoder().encode(recentData) else { return }
        try? jsonData.write(to: recentStorageURL, options: .atomic)
    }

    private func load() {
        if let jsonData = try? Data(contentsOf: storageURL),
           let decoded = try? JSONDecoder().decode([String: [String: UsageEntry]].self, from: jsonData) {
            data = decoded
        }
        if let jsonData = try? Data(contentsOf: recentStorageURL),
           let decoded = try? JSONDecoder().decode([String: [RecentEntry]].self, from: jsonData) {
            recentData = decoded
        }
    }
}
