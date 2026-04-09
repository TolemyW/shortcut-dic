import Foundation

enum FuzzyMatch {

    struct Result {
        let shortcut: Shortcut
        let score: Int
    }

    /// Filter and rank shortcuts by query. Returns matches sorted by relevance.
    /// Searches title, key equivalent, and display string (e.g., "⌘ ⇧ C").
    static func filter(_ shortcuts: [Shortcut], query: String) -> [Shortcut] {
        guard !query.isEmpty else { return shortcuts }
        let q = query.lowercased()

        return shortcuts
            .compactMap { shortcut -> Result? in
                let title = shortcut.title.lowercased()
                let key = shortcut.keyEquivalent.lowercased()
                let display = shortcut.displayString.lowercased()

                // Exact substring in title
                if title.contains(q) {
                    let bonus = title.hasPrefix(q) ? 20 : 0
                    return Result(shortcut: shortcut, score: 100 + bonus)
                }
                // Match on display string (e.g., "⌘ ⇧ c", "⌘ c")
                if display.contains(q) {
                    return Result(shortcut: shortcut, score: 95)
                }
                // Match on key equivalent
                if key.contains(q) {
                    return Result(shortcut: shortcut, score: 90)
                }
                // Fuzzy: all query chars appear in order in title
                if fuzzyContains(title, query: q) {
                    return Result(shortcut: shortcut, score: 50)
                }
                return nil
            }
            .sorted { $0.score > $1.score }
            .map(\.shortcut)
    }

    /// Check if all characters of query appear in order within text.
    private static func fuzzyContains(_ text: String, query: String) -> Bool {
        var textIndex = text.startIndex
        for ch in query {
            guard let found = text[textIndex...].firstIndex(of: ch) else { return false }
            textIndex = text.index(after: found)
        }
        return true
    }
}
