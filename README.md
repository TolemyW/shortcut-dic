# ShortcutDic

A macOS menu bar app that shows keyboard shortcuts for the active application. Long-press a modifier key to see a quick overview, or double-tap to search and execute any shortcut.

## Features

### Two-Mode Design

**Speed View** -- Long-press a modifier key (Command, Option, or Control) to see a compact overlay of the current app's shortcuts. Release to dismiss.

**Search Mode** -- Double-tap the modifier key to pin the panel and search through all shortcuts. Use arrow keys to navigate, Enter to execute, Esc to dismiss.

### System Shortcuts

Reads system-level keyboard shortcuts from macOS preferences (Spotlight, Mission Control, Spaces, Screenshots, etc.) and displays them alongside app shortcuts in a "System" group.

### Global Hotkey

Set a custom global keyboard shortcut to open search mode from anywhere, independent of the long-press trigger.

### Appearance

- **Custom colors**: Shortcut key, title, label, and accent colors are fully customizable via color picker
- **Dark mode adaptation**: Optionally auto-adjusts colors for light/dark system appearance
- **Panel opacity**: Adjustable transparency (30%-100%)
- **Font size**: Numeric setting (9-20pt)
- **Panel position**: Center, or any corner of the screen

### Smart Content

- Recently used shortcuts appear at the top of the speed view
- Configurable number of items per menu group in speed view (3-20)
- Full shortcut list available in search mode with fuzzy matching
- Search by shortcut name, key combination, or modifier symbols
- Special key display: arrows, function keys, Tab, Return, etc. rendered as readable symbols

## Requirements

- macOS 14.0 or later
- Accessibility permission (required to read menu bar shortcuts and monitor keyboard)

## Installation

1. Build and run from Xcode, or download a release
2. Grant Accessibility permission when prompted
3. The app runs as a menu bar icon (no Dock icon)

## Usage

| Action | Result |
|--------|--------|
| Long-press modifier key | Show speed view overlay |
| Release modifier key | Dismiss speed view |
| Double-tap modifier key | Open search mode (pinned) |
| Type in search mode | Filter shortcuts by name or key |
| Arrow keys in search | Navigate results |
| Enter in search | Execute selected shortcut |
| Esc in search | Dismiss search panel |
| Global hotkey | Open search mode directly |

## Settings

Access settings from the menu bar icon or via the standard Preferences shortcut.

- **Trigger**: Choose which modifier keys to monitor (Command/Option/Control), set long-press delay and double-tap timing, record a global hotkey
- **Appearance**: Custom colors (4 color pickers), dark mode adaptation toggle, panel opacity, font size, panel position
- **Display**: Items per group in speed view
- **Exclusions**: Disable in games, exclude specific apps by bundle ID
- **General**: Launch at login

## Architecture

```
ShortcutDic/
+-- ShortcutDicApp.swift              # App entry, MenuBarExtra (LSUIElement)
+-- Assets.xcassets/                  # App icon + menu bar template icon
+-- Models/
|   +-- ShortcutModels.swift          # Shortcut, ShortcutGroup, AppShortcuts
|   +-- AppSettings.swift             # UserDefaults-backed settings + StorableColor
|   +-- AppTheme.swift                # Theme via SwiftUI Environment
+-- Services/
|   +-- AppController.swift           # State machine: idle/speedView/searchMode
|   +-- KeyMonitor.swift              # CGEventTap: long-press, release, double-tap
|   +-- MenuBarReader.swift           # AXUIElement menu bar shortcut reader
|   +-- SystemShortcutReader.swift    # macOS system shortcuts (symbolichotkeys plist)
|   +-- UsageTracker.swift            # Usage frequency + recent interaction tracking
|   +-- ShortcutExecutor.swift        # CGEvent-based shortcut simulation
+-- Views/
|   +-- OverlayPanel.swift            # NSPanel with focus mode switching
|   +-- ShortcutGridView.swift        # Speed view: grouped shortcut grid
|   +-- SearchView.swift              # Search mode: text field + results list
|   +-- SearchTextField.swift         # NSViewRepresentable keyboard handler
|   +-- HotkeyRecorderView.swift      # Global hotkey recorder widget
|   +-- SettingsView.swift            # Settings UI with color pickers
+-- Utilities/
    +-- AccessibilityHelper.swift     # Permission detection and prompting
    +-- FuzzyMatch.swift              # Search ranking algorithm
```

## How It Works

1. **KeyMonitor** uses a `CGEventTap` (listen-only) to detect modifier key long-press, release, and double-tap events. Supports configurable modifier filtering.
2. Long-press triggers **MenuBarReader** which reads app shortcuts via the Accessibility API (`AXUIElement`), plus **SystemShortcutReader** which reads system shortcuts from `com.apple.symbolichotkeys` preferences.
3. Shortcuts are filtered by the held modifier and displayed in a floating `NSPanel` with configurable theme and opacity.
4. Double-tap detection tracks release-then-press timing within a configurable window (0.2-0.5s).
5. Search mode activates the app (`NSApp.activate`), switches the panel to key-window mode, and enables text input with fuzzy matching.
6. **ShortcutExecutor** simulates key presses via `CGEvent` to execute selected shortcuts in the target app.
7. **AppTheme** provides custom colors and font sizes via SwiftUI Environment, with optional auto-adaptation for dark/light mode.

## License

MIT
