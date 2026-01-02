# home_widget_flutter

A Flutter application that creates customizable QR code home screen widgets for iOS and Android. Generate QR codes from text or URLs and display them directly on your device's home screen for quick access and scanning.

## Features

- Generate QR codes from any text, URL, or data
- Display QR codes as home screen widgets on iOS and Android
- Customize widget labels
- Live preview of QR codes before saving
- Persistent storage of QR code data
- High-resolution QR code generation (1024x1024) for reliable scanning
- Cross-platform support (iOS and Android)

## How It Works

1. Enter the text, URL, or data you want to encode as a QR code
2. Add an optional custom label for your widget
3. Preview the QR code in real-time
4. Tap "Update Widget" to save and sync with your home screen widget
5. Add the widget to your home screen to display your QR code

## Dependencies

- [home_widget](https://pub.dev/packages/home_widget) - Enables home screen widget functionality
- [qr_flutter](https://pub.dev/packages/qr_flutter) - QR code generation
- [path_provider](https://pub.dev/packages/path_provider) - File system access for saving QR code images

## Platform Support

- iOS (using App Groups for data sharing)
- Android (using widget providers)
