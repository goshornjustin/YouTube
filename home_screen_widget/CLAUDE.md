# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A Flutter application that creates QR code home screen widgets for iOS and Android. The app generates QR codes from user input and displays them as native home screen widgets.

## Build Commands

All commands should be run from the `home_widget_flutter/` directory:

```bash
# Get dependencies
flutter pub get

# Run the app
flutter run

# Build for specific platform
flutter build ios
flutter build apk

# Run tests
flutter test

# Analyze code (uses flutter_lints)
flutter analyze
```

## Architecture

### Flutter Layer
- [main.dart](home_widget_flutter/lib/main.dart) - App entry point, configures iOS App Group (`group.com.example.homeWidgetFlutter`)
- [qr_widget.dart](home_widget_flutter/lib/qr_widget.dart) - Main UI screen and QR code generation logic
  - Generates high-resolution QR codes (1024x1024) as PNG images
  - Saves data to widget storage via `home_widget` package
  - Triggers widget updates on both platforms

### iOS Widget (WidgetKit + SwiftUI)
Located in `home_widget_flutter/ios/HomeWidget/`:
- [HomeWidget.swift](home_widget_flutter/ios/HomeWidget/HomeWidget.swift) - Widget view and timeline provider
- Reads data from UserDefaults using App Group `group.com.example.homeWidgetFlutter`
- Supports small, medium, and large widget sizes

### Android Widget (AppWidgetProvider)
Located in `home_widget_flutter/android/app/src/main/kotlin/com/example/home_widget_flutter/`:
- [QRWidgetProvider.kt](home_widget_flutter/android/app/src/main/kotlin/com/example/home_widget_flutter/QRWidgetProvider.kt) - Widget provider class
- Reads data from SharedPreferences (`HomeWidgetPreferences`)
- Uses responsive layouts based on widget size (small/medium/large)
- Layouts in `android/app/src/main/res/layout/qr_widget_*.xml`

### Data Flow
1. User enters QR value and label in Flutter app
2. Flutter generates QR code PNG and saves to filesystem
3. Data (value, label, image path) stored via `HomeWidget.saveWidgetData()`
4. `HomeWidget.updateWidget()` triggers platform-specific widget refresh
5. Native widgets read data from platform storage (UserDefaults/SharedPreferences) and display QR image

### Key Identifiers
- iOS Widget Name: `HomeWidget`
- Android Widget Provider: `QRWidgetProvider`
- iOS App Group: `group.com.example.homeWidgetFlutter`
- Android SharedPreferences: `HomeWidgetPreferences`
