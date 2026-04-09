import SwiftUI

struct SearchView: View {
    let appShortcuts: AppShortcuts
    let modifierLabel: String
    var onExecute: (Shortcut) -> Void = { _ in }
    var onDismiss: () -> Void = {}

    @State private var searchQuery = ""
    @State private var selectedIndex = 0

    @Environment(\.appTheme) private var theme

    private var allShortcuts: [Shortcut] {
        appShortcuts.groups.flatMap(\.shortcuts)
    }

    private var filteredShortcuts: [Shortcut] {
        FuzzyMatch.filter(allShortcuts, query: searchQuery)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text(appShortcuts.appName)
                    .font(theme.font(.title3).bold())
                    .foregroundColor(theme.titleColor)
                Spacer()
                Text("Search Mode")
                    .font(theme.font(.subheadline))
                    .foregroundColor(theme.labelColor)
            }

            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(theme.labelColor)
                    .font(.system(size: 14))
                SearchTextField(
                    text: $searchQuery,
                    textColor: NSColor(theme.titleColor),
                    onMoveUp: { moveSelection(-1) },
                    onMoveDown: { moveSelection(1) },
                    onSubmit: { executeSelected() },
                    onCancel: { onDismiss() }
                )
                .frame(height: 26)
            }
            .padding(8)
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)

            Divider().background(theme.dimColor)

            // Results
            let results = filteredShortcuts
            if results.isEmpty {
                HStack {
                    Spacer()
                    Text("No matches")
                        .font(theme.font(.caption))
                        .foregroundColor(theme.labelColor)
                    Spacer()
                }
                .padding(.vertical, 20)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(results.enumerated()), id: \.element.id) { index, shortcut in
                                SearchResultRow(
                                    shortcut: shortcut,
                                    isSelected: index == selectedIndex
                                )
                                .id(index)
                                .onTapGesture { executeShortcut(shortcut) }
                            }
                        }
                    }
                    .frame(maxHeight: 400)
                    .onChange(of: selectedIndex) { _, newValue in
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }

            // Footer
            Divider().background(theme.dimColor)
            HStack(spacing: 16) {
                Label("navigate", systemImage: "arrow.up.arrow.down")
                Label("execute", systemImage: "return")
                Label("dismiss", systemImage: "escape")
            }
            .font(theme.font(.caption))
            .foregroundColor(theme.labelColor)
        }
        .padding(16)
        .frame(width: 560)
        .onChange(of: searchQuery) { _, _ in
            selectedIndex = 0
        }
    }

    private func moveSelection(_ delta: Int) {
        let count = filteredShortcuts.count
        guard count > 0 else { return }
        selectedIndex = (selectedIndex + delta + count) % count
    }

    private func executeSelected() {
        let results = filteredShortcuts
        guard selectedIndex >= 0, selectedIndex < results.count else { return }
        executeShortcut(results[selectedIndex])
    }

    private func executeShortcut(_ shortcut: Shortcut) {
        onExecute(shortcut)
    }
}

struct SearchResultRow: View {
    let shortcut: Shortcut
    let isSelected: Bool

    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(spacing: 8) {
            Text(shortcut.displayString)
                .font(theme.monoFont(.callout))
                .foregroundColor(theme.keyColor)
                .frame(width: 90, alignment: .leading)

            Text(shortcut.title)
                .font(theme.font(.body))
                .foregroundColor(theme.titleColor)
                .lineLimit(1)

            Spacer()

            Text(shortcut.menuPath)
                .font(theme.font(.caption))
                .foregroundColor(theme.labelColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isSelected ? Color.white.opacity(0.15) : Color.clear)
        .cornerRadius(4)
    }
}
