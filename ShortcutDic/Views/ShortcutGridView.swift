import SwiftUI

struct ShortcutGridView: View {
    let appShortcuts: AppShortcuts
    let frequentShortcuts: [Shortcut]
    let modifierLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(appShortcuts.appName)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text(modifierLabel + " held")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.bottom, 4)

            Divider().background(Color.gray.opacity(0.5))

            // Frequently used section
            if !frequentShortcuts.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("★ Frequently Used")
                        .font(.caption)
                        .foregroundColor(.yellow)

                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 140), spacing: 8)
                    ], spacing: 4) {
                        ForEach(frequentShortcuts) { shortcut in
                            ShortcutRow(shortcut: shortcut)
                        }
                    }
                }

                Divider().background(Color.gray.opacity(0.5))
            }

            // Menu groups in columns
            let columns = distributeGroups(appShortcuts.groups, targetColumns: 3)

            HStack(alignment: .top, spacing: 24) {
                ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(column) { group in
                            GroupSection(group: group)
                        }
                    }
                    .frame(minWidth: 160)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(group.menuName)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.gray)

            ForEach(group.shortcuts) { shortcut in
                ShortcutRow(shortcut: shortcut)
            }
        }
    }
}

struct ShortcutRow: View {
    let shortcut: Shortcut

    var body: some View {
        HStack(spacing: 6) {
            Text(shortcut.displayString)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.cyan)
                .frame(width: 50, alignment: .leading)

            Text(shortcut.title)
                .font(.caption)
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer()
        }
    }
}
