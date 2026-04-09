import SwiftUI

struct ShortcutGridView: View {
    let appShortcuts: AppShortcuts
    let recentShortcuts: [Shortcut]
    let modifierLabel: String
    var maxPerGroup: Int = 0
    var totalShortcutCount: Int = 0

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(appShortcuts.appName)
                    .font(theme.font(.title3).bold())
                    .foregroundColor(theme.titleColor)
                Spacer()
                Text(modifierLabel + " held")
                    .font(theme.font(.subheadline))
                    .foregroundColor(theme.labelColor)
            }
            .padding(.bottom, 4)

            Divider().background(theme.dimColor)

            // Recently used section
            if !recentShortcuts.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Recent")
                        .font(theme.font(.subheadline))
                        .foregroundColor(theme.accentColor)

                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 140), spacing: 8)
                    ], spacing: 4) {
                        ForEach(recentShortcuts) { shortcut in
                            ShortcutRow(shortcut: shortcut)
                        }
                    }
                }

                Divider().background(theme.dimColor)
            }

            // Menu groups in columns
            let limitedGroups = maxPerGroup > 0
                ? appShortcuts.groups.map { limitGroup($0, max: maxPerGroup) }
                : appShortcuts.groups
            let columns = distributeGroups(limitedGroups, targetColumns: 3)

            HStack(alignment: .top, spacing: 24) {
                ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(column) { group in
                            GroupSection(group: group, isTruncated: maxPerGroup > 0 && group.shortcuts.count >= maxPerGroup)
                        }
                    }
                    .frame(minWidth: 180)
                }
            }

            // Double-tap hint
            if totalShortcutCount > 0 {
                Divider().background(theme.dimColor)
                HStack {
                    Spacer()
                    Text("double-tap \(modifierLabel) to search all \(totalShortcutCount) shortcuts")
                        .font(theme.font(.caption))
                        .foregroundColor(theme.labelColor)
                    Spacer()
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func limitGroup(_ group: ShortcutGroup, max: Int) -> ShortcutGroup {
        guard group.shortcuts.count > max else { return group }
        return ShortcutGroup(
            menuName: group.menuName,
            shortcuts: Array(group.shortcuts.prefix(max))
        )
    }

    private func distributeGroups(_ groups: [ShortcutGroup], targetColumns: Int) -> [[ShortcutGroup]] {
        guard !groups.isEmpty else { return [] }
        let columnCount = min(targetColumns, groups.count)
        var columns = Array(repeating: [ShortcutGroup](), count: columnCount)
        var heights = Array(repeating: 0, count: columnCount)

        for group in groups {
            let minIndex = heights.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
            columns[minIndex].append(group)
            heights[minIndex] += group.shortcuts.count + 2
        }

        return columns
    }
}

struct GroupSection: View {
    let group: ShortcutGroup
    var isTruncated: Bool = false

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(group.menuName)
                .font(theme.font(.subheadline).weight(.semibold))
                .foregroundColor(theme.labelColor)

            ForEach(group.shortcuts) { shortcut in
                ShortcutRow(shortcut: shortcut)
            }

            if isTruncated {
                Text("...")
                    .font(theme.font(.caption2))
                    .foregroundColor(theme.dimColor)
            }
        }
    }
}

struct ShortcutRow: View {
    let shortcut: Shortcut

    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(spacing: 8) {
            Text(shortcut.displayString)
                .font(theme.monoFont(.callout))
                .foregroundColor(theme.keyColor)
                .frame(width: 80, alignment: .leading)

            Text(shortcut.title)
                .font(theme.font(.callout))
                .foregroundColor(theme.titleColor)
                .lineLimit(1)

            Spacer()
        }
    }
}
