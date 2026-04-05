# ShortcutDic - macOS 快捷键提醒工具设计文档

## 概述

ShortcutDic 是一个 macOS 菜单栏应用，用户长按修饰键（Command/Option/Control）时，会在屏幕上弹出 HUD 浮动面板，显示当前前台应用的可用快捷键清单。通过 Accessibility API 实时读取菜单栏快捷键数据，并追踪用户使用频率，在面板顶部展示常用快捷键。

## 技术选型

- **语言/框架**: Swift + SwiftUI
- **键盘监听**: CGEventTap（全局事件监听）
- **菜单栏读取**: AXUIElement（Accessibility API）
- **面板实现**: NSPanel + SwiftUI
- **最低支持版本**: macOS 13 Ventura

## 架构

```
ShortcutDic/
├── ShortcutDicApp.swift          # App 入口，Menu Bar App（无 Dock 图标）
├── Models/
│   └── ShortcutModels.swift      # 数据模型
├── Services/
│   ├── KeyMonitor.swift          # CGEventTap 修饰键监听
│   ├── MenuBarReader.swift       # AXUIElement 菜单栏读取
│   └── UsageTracker.swift        # 快捷键使用频率追踪
├── Views/
│   ├── OverlayPanel.swift        # NSPanel + SwiftUI HUD
│   ├── ShortcutGridView.swift    # 快捷键网格布局
│   └── SettingsView.swift        # 设置界面
└── Utilities/
    └── AccessibilityHelper.swift # 权限检测与引导
```

### 核心模块

1. **KeyMonitor** - `CGEvent.tapCreate` 全局监听修饰键按下/松开，长按超过阈值（默认 0.5s）后触发面板显示
2. **MenuBarReader** - 通过 `AXUIElementCreateApplication(pid)` 获取前台应用菜单栏，遍历菜单项提取 `kAXMenuItemCmdCharAttribute` 和 `kAXMenuItemCmdModifiersAttribute`
3. **ShortcutStore** - 按菜单名分组的快捷键数据模型，含缓存机制（同一应用短时间内不重复读取）
4. **OverlayPanel** - `NSPanel`（`styleMask: .nonactivatingPanel`）承载 SwiftUI 视图，不抢夺前台应用焦点
5. **UsageTracker** - 监听用户实际按键组合，匹配已知快捷键并记录使用频率，持久化到本地

## 数据模型

```swift
struct Shortcut {
    let title: String                      // 菜单项名称，如 "Copy"
    let keyEquivalent: String              // 按键，如 "C"
    let modifiers: NSEvent.ModifierFlags   // 修饰键组合
    let menuPath: String                   // 所属菜单，如 "Edit"
}

struct ShortcutGroup {
    let menuName: String                   // "File", "Edit", "View" 等
    let shortcuts: [Shortcut]
}

struct AppShortcuts {
    let appName: String
    let bundleIdentifier: String
    let groups: [ShortcutGroup]
}
```

## 核心流程

```
用户长按 ⌘ (超过 0.5s 阈值)
    ↓
KeyMonitor 检测到长按
    ↓
获取前台应用 (NSWorkspace.shared.frontmostApplication)
    ↓
检查排除列表（游戏等）→ 在排除列表中则不显示
    ↓
MenuBarReader 异步读取菜单栏（有缓存则使用缓存）
    ↓
组装 AppShortcuts，按当前按下的修饰键过滤
    ↓
OverlayPanel 淡入显示 HUD（0.15s 动画）
    ↓
用户松开修饰键 → 面板淡出消失
```

## UI 设计

### HUD 面板

- **视觉风格**: 半透明深色毛玻璃背景（`NSVisualEffectView` `.hudWindow` material），白色文字，圆角
- **布局**: 多列网格，每列一个菜单组
- **面板位置**: 用户可配置（居中/左上/右上/左下/右下），默认居中
- **自适应**: 根据快捷键数量自动调整大小，不超过屏幕 80%
- **动画**: 淡入淡出，约 0.15s

### 面板布局

```
┌─────────────────────────────────────────────────┐
│  [App Icon] AppName                     ⌘ held  │
├─────────────────────────────────────────────────┤
│  ★ Frequently Used                              │
│  ────────────────                               │
│  ⌘C  Copy    ⌘V  Paste    ⌘Z  Undo    ⌘A  All │
│                                                 │
│  File              Edit             View        │
│  ──────            ──────           ──────      │
│  ⌘N  New Window    ⌘X  Cut         ⌘1  Icons   │
│  ⌘O  Open          ⌘F  Find        ⌘2  List    │
│  ⌘W  Close         ⌘H  Find &      ⌘3  Columns │
│  ⌘S  Save               Replace    ⌘4  Gallery │
│  ...               ...              ...        │
└─────────────────────────────────────────────────┘
```

### "常用"区域

- 本地持久化每个应用的快捷键使用频率（轻量 JSON 文件）
- 通过 CGEventTap 监听用户实际按键组合，匹配到已知快捷键时计数 +1
- 面板顶部显示当前应用 Top 5-8 个最常用快捷键
- 新安装时该区域为空，随使用逐渐填充

## 设置

- **面板位置**: 居中 / 左上 / 右上 / 左下 / 右下
- **触发延迟**: 滑块 0.3s ~ 1.0s（默认 0.5s）
- **游戏中禁用**: 开关（默认开启），通过 Bundle ID 和 `kLSCategoryGame` 检测游戏应用
- **排除列表**: 用户可手动添加/移除需要排除的应用
- **开机自启动**: 开关
- **辅助功能权限状态**: 显示当前授权状态，提供快捷入口

## 权限

- 必须授予**辅助功能权限**（Accessibility）
- 首次启动检测 `AXIsProcessTrusted()`，未授权弹出引导对话框
- 引导用户到 系统设置 → 隐私与安全 → 辅助功能 添加本应用
- 菜单栏图标旁显示权限状态指示

## 边界情况

- **应用无菜单栏**: 面板显示"当前应用无可用快捷键"
- **菜单栏读取超时**: 2s 超时，显示已获取的部分数据
- **安全输入模式**: CGEventTap 被系统暂停，预期行为，无需特殊处理
- **游戏应用**: 默认排除，用户可在设置中管理排除列表
- **序列键（如 ⌘K → ⌘C）**: MVP 阶段不主动支持，菜单栏无法获取此类数据；后续版本通过用户自定义配置补充

## MVP 范围

### 包含

- CGEventTap 修饰键长按检测与触发
- AXUIElement 菜单栏快捷键实时读取与缓存
- HUD 浮动面板（毛玻璃、多列网格、按修饰键过滤）
- 常用快捷键区域（频率追踪）
- 按菜单名分类分组显示
- 菜单栏图标与状态指示
- 设置界面（位置、延迟、排除列表、游戏模式、开机自启）
- 辅助功能权限引导

### 不包含（后续版本）

- 面板内搜索/过滤
- 序列键/组合键自定义配置
- 自定义快捷键数据库
- 快捷键使用统计面板
- 主题/外观自定义
