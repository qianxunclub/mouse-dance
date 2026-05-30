# MouseDance

A macOS multi-monitor shortcut management tool that helps users quickly switch the cursor between multiple displays using custom keyboard shortcuts.

## Features

### 🎯 Multi-Monitor Support
- Automatically detects all connected displays in the system
- Assigns independent shortcuts to each display
- Supports custom jump shortcut mappings

### ⌨️ Global Shortcuts
- Supports customizable global hotkey combinations
- One-click rapid cursor switching between displays
- Supports modifier key combinations (Command, Option, Control, Shift)

### 🖱️ Cursor Navigation
- Automatically moves the cursor to the target display when the shortcut is pressed
- Displays screen label overlays for easy identification
- Real-time cursor position indicator showing current location

### ⚙️ System Integration
- Detects input monitoring permission status
- Requests necessary system permissions
- Supports Retina displays

## System Requirements

- macOS 11.0 or later
- Requires "Accessibility" permissions to enable global shortcuts and cursor control

## Installation Instructions

### Building from Source

1. Clone the repository:
```bash
git clone https://gitee.com/qianxunclub/mouse-dance.git
```

2. Open the project in Xcode:
```bash
open MouseDance.xcodeproj
```

3. Select the target device and signing configuration in Xcode, then click Run.

## Usage Guide

### Initial Setup

1. Upon launching, the app will request "Accessibility" permissions.
2. Add this app to "System Preferences > Security & Privacy > Privacy > Accessibility".
3. After granting permission, a list of connected displays will be displayed.

### Configuring Shortcuts

1. Click the "Record Shortcut" area on a display card.
2. Press the desired key combination.
3. After saving, pressing the shortcut will move the cursor to the corresponding display.

### Switching Displays

Simply press the shortcut configured for each display, and the cursor will automatically move to that display.

## Project Structure

```
MouseDance/
├── MouseDanceApp.swift       # Application entry and menu bar configuration
├── MouseDanceStore.swift     # Core data storage and management logic
├── ContentView.swift         # Main interface view
├── ShortcutRecorderView.swift # Shortcut recording component
└── Assets.xcassets/          # Application assets
```

## Technology Stack

- **SwiftUI** - User interface framework
- **AppKit** - System-level feature integration
- **CoreGraphics** - Display detection and cursor control
- **CGEvent** - Global event monitoring

## Open Source License

This project is for learning and reference purposes only. Please comply with relevant laws and regulations.