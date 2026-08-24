//
//  QrWidget.swift
//  QrWidget
//
//  Created by Justin on 8/21/26.
//

import SwiftUI
import WidgetKit

struct QrProvider: AppIntentTimelineProvider {
    private let appGroupId = "group.com.example.homeWidgetApp.QrWidget"

    /// Base storage keys — card ID is appended for multi-card support.
    private let keyImagePathBase = "qr_widget_image_path"
    private let keyBgColorBase = "qr_widget_bg_color"
    private let keyCardLabelBase = "qr_widget_card_label"
    private let keyActiveCards = "qr_widget_active_cards"

    func placeholder(in context: Context) -> QrEntry {
        QrEntry(
            date: Date(),
            configuration: SelectCardIntent(),
            image: nil,
            bgColor: .white,
            cardLabel: "QR"
        )
    }

    func snapshot(for configuration: SelectCardIntent, in context: Context)
        async -> QrEntry
    {
        loadEntry(configuration: configuration)
    }

    func timeline(for configuration: SelectCardIntent, in context: Context)
        async -> Timeline<QrEntry>
    {
        let entry = loadEntry(configuration: configuration)
        /// .never — updates are triggered by Flutter via home_widget
        return Timeline(entries: [entry], policy: .never)
    }

    private func loadEntry(configuration: SelectCardIntent) -> QrEntry {
        let userDefaults = UserDefaults(suiteName: appGroupId)

        let activeCards = self.activeCards(userDefaults)

        /// Use the card chosen in the widget config. Fall back to the first active card
        /// when the widget hasn't been configured yet, or when the card it was configured
        /// for has since been removed in the app — otherwise the widget is stuck on the
        /// placeholder until the user reconfigures it by hand.
        let configuredCardId = configuration.card?.id
        let cardId =
            configuredCardId.flatMap { activeCards.contains($0) ? $0 : nil }
            ?? activeCards.first

        let imagePath = cardId.flatMap {
            userDefaults?.string(forKey: "\(keyImagePathBase)_\($0)")
        }
        let bgColorArgb =
            (cardId.flatMap {
                userDefaults?.object(forKey: "\(keyBgColorBase)_\($0)") as? Int
            }) ?? 0xFFFF_FFFF
        let cardLabel =
            (cardId.flatMap {
                userDefaults?.string(forKey: "\(keyCardLabelBase)_\($0)")
            }) ?? "QR"

        let uiImage = imagePath.flatMap { loadImage(at: $0) }

        /// Parse ARGB integer to SwiftUI Color.
        let a = Double((bgColorArgb >> 24) & 0xFF) / 255.0
        let r = Double((bgColorArgb >> 16) & 0xFF) / 255.0
        let g = Double((bgColorArgb >> 8) & 0xFF) / 255.0
        let b = Double(bgColorArgb & 0xFF) / 255.0
        let bgColor = Color(red: r, green: g, blue: b, opacity: a)

        return QrEntry(
            date: Date(),
            configuration: configuration,
            image: uiImage,
            bgColor: bgColor,
            cardLabel: cardLabel
        )
    }

    /// Loads the QR PNG Flutter rendered for a card.
    ///
    /// Flutter stores an absolute path, which a device migration or iCloud restore
    /// invalidates: UserDefaults comes back with paths into the old App Group container
    /// while the container itself is mounted under a new UUID. The file name is stable, so
    /// fall back to rebuilding the path against the container this process actually has —
    /// otherwise the widget shows the placeholder forever despite the data looking present.
    private func loadImage(at storedPath: String) -> UIImage? {
        if let image = UIImage(contentsOfFile: storedPath) {
            return image
        }

        guard
            let container = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: appGroupId
            )
        else { return nil }

        let rebuilt =
            container
            .appendingPathComponent("home_widget")
            .appendingPathComponent((storedPath as NSString).lastPathComponent)

        return UIImage(contentsOfFile: rebuilt.path)
    }

    private func activeCards(_ defaults: UserDefaults?) -> [String] {
        let active = defaults?.string(forKey: keyActiveCards) ?? ""
        return active.split(separator: ",").map(String.init).filter {
            !$0.isEmpty
        }
    }
}

struct QrEntry: TimelineEntry {
    let date: Date
    let configuration: SelectCardIntent
    let image: UIImage?
    let bgColor: Color
    let cardLabel: String
}

struct QrWidgetEntryView: View {
    var entry: QrProvider.Entry

    var body: some View {
        if let image = entry.image {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .accessibilityLabel(Text("QR code for \(entry.cardLabel)"))
        } else {
            VStack {
                Image(systemName: "qrcode")
                    .font(.largeTitle)
                Text("Open app to configure")
                    .font(.caption)
            }
            .foregroundColor(.gray)
        }
    }
}

struct QrWidget: Widget {
    let kind: String = "QrWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectCardIntent.self,
            provider: QrProvider()
        ) { entry in
            QrWidgetEntryView(entry: entry)
                .containerBackground(entry.bgColor, for: .widget)
        }
        .configurationDisplayName("QR Code")
        .description("Display your QR code on your home screen.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemMedium) {
    QrWidget()
} timeline: {
    QrEntry(
        date: .now,
        configuration: SelectCardIntent(),
        image: nil,
        bgColor: .white,
        cardLabel: "Preview"
    )
}
