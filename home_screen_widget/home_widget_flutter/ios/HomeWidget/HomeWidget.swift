//
//  HomeWidget.swift
//  HomeWidget
//
//  Created by Justin on 1/1/26.
//

import WidgetKit
import SwiftUI

struct Provider: AppIntentTimelineProvider {
    // Called synchronously before any data is available — used for the loading skeleton.
    // WidgetKit does NOT allow async work or disk/network reads here; return dummy data only.
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), qrValue: "No Data", qrLabel: "QR Code", imagePath: "", configuration: ConfigurationAppIntent())
    }

    // Called when the widget gallery (Add Widget sheet) needs a preview.
    // Reads real data so the preview reflects actual content rather than placeholders.
    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        // IMPORTANT: this suiteName must match exactly in three places:
        //   1. Here (and in timeline below)
        //   2. HomeWidget.setAppGroupId() call in main.dart
        //   3. The iOS App Group entitlement in Runner.entitlements
        // A mismatch causes the widget to silently show "No Data" with no error.
        let userDefaults = UserDefaults(suiteName: "group.com.example.homeWidgetFlutter")
        let qrValue = userDefaults?.string(forKey: "qr_code_value") ?? "No Data"
        let qrLabel = userDefaults?.string(forKey: "qr_code_label") ?? "QR Code"
        let imagePath = userDefaults?.string(forKey: "qr_code_image_path") ?? ""

        return SimpleEntry(date: Date(), qrValue: qrValue, qrLabel: qrLabel, imagePath: imagePath, configuration: configuration)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        // suiteName must match entitlements and Flutter config — see snapshot() comment above.
        let userDefaults = UserDefaults(suiteName: "group.com.example.homeWidgetFlutter")
        let qrValue = userDefaults?.string(forKey: "qr_code_value") ?? "No Data"
        let qrLabel = userDefaults?.string(forKey: "qr_code_label") ?? "QR Code"
        let imagePath = userDefaults?.string(forKey: "qr_code_image_path") ?? ""

        let entry = SimpleEntry(date: Date(), qrValue: qrValue, qrLabel: qrLabel, imagePath: imagePath, configuration: configuration)

        // .never = WidgetKit will not schedule automatic refreshes.
        // Refreshes are triggered manually by Flutter via:
        //   HomeWidget.updateWidget(iOSName: "HomeWidget") in qr_widget.dart
        // which calls WidgetCenter.shared.reloadTimelines(ofKind: "HomeWidget") under the hood.
        return Timeline(entries: [entry], policy: .never)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let qrValue: String
    let qrLabel: String
    let imagePath: String
    let configuration: ConfigurationAppIntent
}

struct HomeWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(spacing: 8) {
            Text(entry.qrLabel)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            if let uiImage = loadImage(from: entry.imagePath) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .padding(8)
            } else {
                Image(systemName: "qrcode")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.gray)
                    .padding(16)
            }
        }
        // Required on iOS 17+: widgets must declare their background via containerBackground.
        // Omitting this causes the background to render incorrectly on iOS 17 and later.
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func loadImage(from path: String) -> UIImage? {
        guard !path.isEmpty else { return nil }
        // path is an absolute filesystem path written by Flutter (not a bundle asset name).
        // Use contentsOfFile:, not UIImage(named:) — named: only looks in the app bundle.
        return UIImage(contentsOfFile: path)
    }
}

struct HomeWidget: Widget {
    // Must match the iOSName passed to HomeWidget.updateWidget(iOSName:) in Flutter.
    // Mismatch = Flutter's reload call targets a different timeline and this widget never updates.
    let kind: String = "HomeWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            HomeWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("QR Code Widget")
        .description("Display your custom QR code")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
