//
//  HomeWidget.swift
//  HomeWidget
//
//  Created by Justin on 1/1/26.
//

import WidgetKit
import SwiftUI

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), qrValue: "No Data", qrLabel: "QR Code", imagePath: "", configuration: ConfigurationAppIntent())
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        let userDefaults = UserDefaults(suiteName: "group.com.example.homeWidgetFlutter")
        let qrValue = userDefaults?.string(forKey: "qr_code_value") ?? "No Data"
        let qrLabel = userDefaults?.string(forKey: "qr_code_label") ?? "QR Code"
        let imagePath = userDefaults?.string(forKey: "qr_code_image_path") ?? ""

        return SimpleEntry(date: Date(), qrValue: qrValue, qrLabel: qrLabel, imagePath: imagePath, configuration: configuration)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        // Read data from UserDefaults (App Group)
        let userDefaults = UserDefaults(suiteName: "group.com.example.homeWidgetFlutter")
        let qrValue = userDefaults?.string(forKey: "qr_code_value") ?? "No Data"
        let qrLabel = userDefaults?.string(forKey: "qr_code_label") ?? "QR Code"
        let imagePath = userDefaults?.string(forKey: "qr_code_image_path") ?? ""

        let entry = SimpleEntry(date: Date(), qrValue: qrValue, qrLabel: qrLabel, imagePath: imagePath, configuration: configuration)

        // Update policy: .never (manual updates only from Flutter app)
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
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func loadImage(from path: String) -> UIImage? {
        guard !path.isEmpty else { return nil }
        return UIImage(contentsOfFile: path)
    }
}

struct HomeWidget: Widget {
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
