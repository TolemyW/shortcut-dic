# ShortcutDic

A macOS menu bar app that shows keyboard shortcuts for the active application. Long-press a modifier key to see a quick overview, or double-tap to search and execute any shortcut.

## Features

### Two-Mode Interaction

**Speed View** -- Long-press a modifier key (Command, Option, or Control) to see a compact overlay of the current app's shortcuts, filtered by the held modifier. Release to dismiss instantly.

**Search Mode** -- Double-tap the modifier key to pin the panel and search through all shortcuts with fuzzy matching. Use arrow keys to navigate, Enter to execute, Esc or click outside to dismiss.

### Shortcut Sources

- **App Shortcuts**: Reads the active application's menu bar shortcuts via the Accessibility API (AXUIElement)
- **System Shortcuts**: Reads macOS system-level shortcuts from preferences (Spotlight, Mission Control, Spaces, Screenshots, etc.) and displays them in a "System" group
- **Recently Used**: Tracks the 6 most recently executed shortcuts per app and shows them at the top of the speed view

### Global Hotkey

Set a custom global keyboard shortcut to open search mode from anywhere, independent of the long-press trigger.

### Appearance

- **Custom colors**: 4 color pickers for shortcut key, title, label, and accent colors
- **Dark mode adaptation**: Optionally auto-adjusts colors for light/dark system appearance
- **Panel opacity**: Adjustable transparency (30%-100%)
- **Font size**: 9-20pt
- **Panel position**: Center, or any corner of the screen

### Smart Content

- Fuzzy search across shortcut name, key combination, and modifier symbols
- Configurable number of items per menu group in speed view (3-20)
- Special key display: arrows, function keys, Tab, Return, etc. rendered as readable symbols (e.g. `←` `⇥` `⏎`)
- Automatically resolves target app when ShortcutDic is in the foreground (e.g. after clicking the menu bar icon)

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0+ (for building from source)
- Accessibility permission (required to read menu bar shortcuts and monitor keyboard)

## Installation

### From Release

1. Download `ShortcutDic-vX.X.X.zip` from [GitHub Releases](https://github.com/TolemyW/shortcut-dic/releases)
2. Unzip and move `ShortcutDic.app` to `/Applications`
3. Launch the app and grant Accessibility permission when prompted
4. The app runs as a menu bar icon (no Dock icon)

### From Source

```bash
git clone https://github.com/TolemyW/shortcut-dic.git
cd shortcut-dic
xcodebuild build -project ShortcutDic.xcodeproj -scheme ShortcutDic -configuration Release -destination 'platform=macOS'
```

## Usage

| Action | Result |
|--------|--------|
| Long-press modifier key | Show speed view overlay |
| Release modifier key | Dismiss speed view |
| Double-tap modifier key | Open search mode (pinned) |
| Type in search mode | Filter shortcuts by name or key |
| Arrow keys in search | Navigate results |
| Enter in search | Execute selected shortcut |
| Esc / click outside | Dismiss search panel |
| Global hotkey | Open search mode directly |

## Settings

Access settings from the menu bar icon or via the standard Preferences shortcut (⌘,).

| Section | Options |
|---------|---------|
| **Trigger** | Modifier keys to monitor (⌘/⌥/⌃), long-press delay (0.3-1.0s), double-tap window (0.2-0.5s), global hotkey recorder |
| **Appearance** | 4 color pickers, dark mode adaptation, panel opacity, font size, panel position |
| **Display** | Items per group in speed view (3-20) |
| **Exclusions** | Disable in games, exclude apps by bundle ID |
| **General** | Launch at login |

## Architecture

```
ShortcutDic/
├── ShortcutDicApp.swift              # App entry, MenuBarExtra (LSUIElement)
├── Assets.xcassets/                  # App icon + menu bar template icon
├── Models/
│   ├── ShortcutModels.swift          # Shortcut, ShortcutGroup, AppShortcuts
│   ├── AppSettings.swift             # UserDefaults-backed @Published settings
│   └── AppTheme.swift                # Theme via SwiftUI Environment
├── Services/
│   ├── AppController.swift           # State machine: idle → speedView → searchMode
│   ├── KeyMonitor.swift              # CGEventTap: long-press, release, double-tap
│   ├── MenuBarReader.swift           # AXUIElement menu bar shortcut reader + cache
│   ├── SystemShortcutReader.swift    # macOS system shortcuts (symbolichotkeys plist)
│   ├── UsageTracker.swift            # Usage frequency + recent interaction tracking
│   └── ShortcutExecutor.swift        # CGEvent-based shortcut simulation
├── Views/
│   ├── OverlayPanel.swift            # NSPanel: non-activating (speed) / key window (search)
│   ├── ShortcutGridView.swift        # Speed view: grouped shortcut grid
│   ├── SearchView.swift              # Search mode: text field + results list
│   ├── SearchTextField.swift         # NSViewRepresentable keyboard handler
│   ├── HotkeyRecorderView.swift      # Global hotkey recorder widget
│   └── SettingsView.swift            # Settings UI with color pickers
└── Utilities/
    ├── AccessibilityHelper.swift     # Permission detection and prompting
    └── FuzzyMatch.swift              # Multi-tier search ranking algorithm
```

### Key Design Decisions

- **CGEventTap (listen-only)** for modifier key detection -- no key injection, works with any app
- **NSPanel** with dynamic `styleMask` switching between non-activating (speed view, doesn't steal focus) and key window mode (search, accepts text input)
- **Triple-layer ESC handling** -- text field `cancelOperation`, panel-level override, and global event monitor to ensure search mode always dismisses
- **Last external app tracking** -- resolves the frontmost app even when ShortcutDic is active (e.g. after clicking its menu bar icon)
- **No sandbox** -- required for CGEventTap, AXUIElement menu reading, and CGEvent-based shortcut execution

## CI/CD

GitHub Actions workflows run on every push and PR:

| Workflow | Trigger | Action |
|----------|---------|--------|
| **CI** | Push to `main` / PR | Build (Debug) + run 41 unit tests |
| **Release** | Push `v*` tag | Build (Release) → archive → zip → GitHub Release |

### Creating a Release

```bash
git tag v1.0.0
git push origin v1.0.0
```

The release workflow automatically builds the app and uploads `ShortcutDic-v1.0.0.zip` to GitHub Releases with auto-generated release notes.

## License

MIT
