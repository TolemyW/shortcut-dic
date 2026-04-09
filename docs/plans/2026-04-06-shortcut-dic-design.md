# ShortcutDic - macOS Shortcut Overlay Design

## Overview

ShortcutDic is a macOS menu bar app. It reads keyboard shortcuts from the active application's menu bar via the Accessibility API, plus system-level shortcuts from macOS preferences, and displays them in a floating HUD panel. It operates in two modes: a quick speed view triggered by long-pressing a modifier key, and a pinned search mode triggered by double-tapping the modifier or pressing a global hotkey.

## Tech Stack

- **Language/Framework**: Swift 5.9 + SwiftUI
- **Keyboard monitoring**: CGEventTap (global, listen-only)
- **Menu bar reading**: AXUIElement (Accessibility API)
- **System shortcuts**: UserDefaults `com.apple.symbolichotkeys` (read-only)
- **Panel**: NSPanel + NSHostingView + SwiftUI
- **Minimum deployment**: macOS 14.0

## Architecture

```
ShortcutDic/
+-- ShortcutDicApp.swift              # @main, MenuBarExtra (LSUIElement)
+-- Assets.xcassets/                  # App icon (all sizes) + menu bar template icon
+-- Models/
|   +-- ShortcutModels.swift          # Shortcut, ShortcutGroup, AppShortcuts
|   +-- AppSettings.swift             # Settings + StorableColor + HotkeyCombo + KeyCodeNames
|   +-- AppTheme.swift                # Theme (custom colors, fonts) via SwiftUI Environment
+-- Services/
|   +-- AppController.swift           # Central state machine + global hotkey monitor
|   +-- KeyMonitor.swift              # CGEventTap: long-press, release, double-tap
|   +-- MenuBarReader.swift           # AX API menu bar reader with cache
|   +-- SystemShortcutReader.swift    # macOS system shortcuts from symbolichotkeys plist
|   +-- UsageTracker.swift            # Frequency + recent interaction tracking
|   +-- ShortcutExecutor.swift        # CGEvent key simulation
+-- Views/
|   +-- OverlayPanel.swift            # NSPanel with activating/non-activating modes
|   +-- ShortcutGridView.swift        # Speed view layout (themed)
|   +-- SearchView.swift              # Search mode layout (themed)
|   +-- SearchTextField.swift         # NSViewRepresentable for key interception
|   +-- HotkeyRecorderView.swift      # Global hotkey recorder widget
|   +-- SettingsView.swift            # Settings form with color pickers
+-- Utilities/
    +-- AccessibilityHelper.swift     # AXIsProcessTrusted wrapper
    +-- FuzzyMatch.swift              # Search scoring: substring > display > key > fuzzy
```

## State Machine

AppController manages three states:

```
         long-press           double-tap / global hotkey
  idle ────────────> speedView ──────────────────────> searchMode
   ^                    |                                  |
   |     release        |          Esc / app switch        |
   +<───────────────────+<─────────────────────────────────+
```

- **idle**: No overlay shown
- **speedView**: Overlay visible, dismissed on modifier release. Content limited by maxPerGroup setting
- **searchMode**: Panel pinned, keyboard focus captured. Full shortcut list with fuzzy search. Enter executes, Esc dismisses

## Data Models

```swift
struct Shortcut: Identifiable, Equatable {
    let title: String                      // "Copy"
    let keyEquivalent: String              // "C"
    let modifiers: NSEvent.ModifierFlags   // .command
    let menuPath: String                   // "Edit"
    var displayString: String              // "⌘ C" (spaced, special keys mapped)
}

struct ShortcutGroup: Identifiable {
    let menuName: String                   // "File", "Edit", "System"
    let shortcuts: [Shortcut]
    func filtered(by:) -> ShortcutGroup
}

struct AppShortcuts {
    let appName: String
    let bundleIdentifier: String
    let groups: [ShortcutGroup]            // App groups + System group
    func filtered(by:) -> AppShortcuts
}

struct StorableColor: Codable, Equatable {
    var hex: String                        // "#00CCCC"
    var nsColor: NSColor
    var color: Color                       // SwiftUI Color
}

struct HotkeyCombo: Codable, Equatable {
    let keyCode: UInt16
    let modifiers: UInt
    var displayString: String              // "⌘ ⇧ Space"
}
```

## Shortcut Sources

### App Shortcuts (MenuBarReader)
- Read via `AXUIElementCreateApplication(pid)` → `kAXMenuBarAttribute` → recursive menu traversal
- Extracts `kAXMenuItemCmdCharAttribute` (key) and `kAXMenuItemCmdModifiersAttribute` (modifiers)
- AX modifier conversion: bit 0=Shift, 1=Option, 2=Control, 3=no-Command
- Cached 5 seconds per app
- Special key handling: Unicode chars (0xF700-series arrows, function keys, etc.) mapped to readable symbols

### System Shortcuts (SystemShortcutReader)
- Read-only from `UserDefaults(suiteName: "com.apple.symbolichotkeys")`
- Parses `AppleSymbolicHotKeys` dictionary: ID → {enabled, parameters[ASCII, VirtualKeyCode, ModifierMask]}
- Modifier mask: bit 17=Shift, 18=Control, 19=Option, 20=Command, 23=Function (ignored)
- Built-in mapping of ~30 hotkey IDs to names (Mission Control, Spotlight, Screenshots, Spaces, etc.)
- Cached in memory (system shortcuts rarely change)

## Core Flows

### Speed View

1. User long-presses modifier key (threshold: 0.3-1.0s configurable)
2. KeyMonitor fires `onLongPress` — only for modifiers in `monitoredModifiers` set
3. AppController checks: not self, not excluded, not game app
4. MenuBarReader reads app shortcuts via AX API (cached 5s)
5. SystemShortcutReader reads system shortcuts from plist
6. Checks modifier still held (prevents stale panel if released during async read)
7. Filters both by pressed modifier, limits app shortcuts to maxPerGroup per group
8. Appends system shortcuts as "System" group
9. Shows OverlayPanel with ShortcutGridView + theme + opacity

### Search Mode

1. User double-taps modifier (release + re-press within configurable window)
   OR presses global hotkey
2. AppController reuses cached shortcuts or fetches fresh (app + system)
3. Locks KeyMonitor (`isLocked = true`, prevents re-triggering)
4. Activates app (`NSApp.activate`), panel becomes key window
5. OverlayPanel finds and focuses NSTextField via view hierarchy traversal
6. Local Esc event monitor as fallback for dismissal
7. FuzzyMatch scores: exact substring (120) > display string (95) > key match (90) > fuzzy (50)
8. Arrow keys navigate, Enter executes selected shortcut
9. Execution: dismiss panel → activate target app → CGEvent simulate keyDown+keyUp
10. Auto-dismisses on `NSApplication.didResignActiveNotification`

### Shortcut Execution

```swift
ShortcutExecutor.execute(shortcut:in:)
  1. app.activate()
  2. 50ms delay
  3. CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
     .flags = convertToEventFlags(modifiers)
     .post(tap: .cghidEventTap)
  4. Matching keyUp event
```

## Settings

### Trigger
| Setting | Type | Default | Range |
|---------|------|---------|-------|
| Monitor ⌘ Command | Bool | true | - |
| Monitor ⌥ Option | Bool | true | - |
| Monitor ⌃ Control | Bool | true | - |
| Global Hotkey | HotkeyCombo? | nil | Any modifier+key combo |
| Long Press Delay | Double | 0.5s | 0.3-1.0s |
| Double-Tap Window | Double | 0.3s | 0.2-0.5s |

### Appearance
| Setting | Type | Default | Range |
|---------|------|---------|-------|
| Shortcut Key Color | StorableColor | #00CCCC (cyan) | Any color |
| Title Color | StorableColor | #FFFFFF (white) | Any color |
| Label Color | StorableColor | #888888 (gray) | Any color |
| Accent Color | StorableColor | #FFCC00 (yellow) | Any color |
| Adapt to Dark/Light Mode | Bool | true | - |
| Panel Opacity | Double | 0.95 | 0.3-1.0 |
| Font Size | Double | 13pt | 9-20pt |
| Panel Position | PanelPosition | .center | Center / 4 corners |

### Display
| Setting | Type | Default | Range |
|---------|------|---------|-------|
| Items per Group | Int | 5 | 3-20 |

### Exclusions
| Setting | Type | Default |
|---------|------|---------|
| Disable in Games | Bool | true |
| Excluded Bundle IDs | [String] | [] |

### General
| Setting | Type | Default |
|---------|------|---------|
| Launch at Login | Bool | false |

## Theme System

`AppTheme` provides colors and font sizes via SwiftUI `EnvironmentValues`:

- Colors are user-customizable via `StorableColor` (hex string persistence)
- `adaptToDarkMode`: when enabled, darkens user colors in light system appearance; uses HUD material for dark, sheet material for light
- Font sizes computed from a single `baseFontSize` setting with style-based offsets (title3: +4, body: +1, caption: -2, etc.)
- Monospaced font variant for shortcut key display

## Icons

- **App Icon**: Magnifying glass with ⌘ symbol on purple-blue gradient background. All macOS sizes generated (16-1024px).
- **Menu Bar Icon**: Template PDF (18x18pt), magnifying glass outline with ⌘ symbol. Auto-adapts to light/dark menu bar.

## Permissions

- **Accessibility** (required): CGEventTap + AXUIElement
- Detected via `AXIsProcessTrusted()`, prompted on first launch
- Permission polling (1s interval) auto-starts KeyMonitor once granted
- System shortcuts reading requires no additional permissions (reads user plist)

## Edge Cases

- **Self-targeting**: Skip reading own menu bar (causes NSMenu thread assertion on background thread)
- **Modifier released during async load**: Check `isModifierHeld` before showing panel
- **App switch during search**: `NSApplication.didResignActiveNotification` auto-dismisses
- **Search mode keyboard isolation**: `KeyMonitor.isLocked` prevents re-triggering
- **Double-tap vs normal usage**: Only fires on solo modifier press (flagsChanged), not modifier+key combos (keyDown)
- **Special key characters**: AX API returns Unicode private-use chars for arrows/F-keys; `readableKey()` maps ~30 special chars to symbols
- **LSUIElement focus**: Must call `NSApp.activate(ignoringOtherApps:)` for panel to become key window
