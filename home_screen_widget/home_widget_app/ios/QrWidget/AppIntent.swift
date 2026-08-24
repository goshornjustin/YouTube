//
//  AppIntent.swift
//  QrWidget
//
//  Created by Justin on 8/21/26.
//

import AppIntents
import WidgetKit

private let appGroupId = "group.com.example.homeWidgetApp.QrWidget"
private let keyActiveCards = "qr_widget_active_cards"
private let keyCardLabelBase = "qr_widget_card_label"

/// A selectable card, surfaced in the widget's configuration UI.
struct CardEntity: AppEntity, Identifiable {
    let id: String
    let label: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Card" }
    static var defaultQuery = CardQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(label)")
    }
}

/// Reads the active cards (written by Flutter via home_widget) from the shared
/// App Group so the widget configuration sheet can offer a real picker.
struct CardQuery: EntityQuery {
    private func loadCards() -> [CardEntity] {
        let defaults = UserDefaults(suiteName: appGroupId)
        let active = defaults?.string(forKey: keyActiveCards) ?? ""
        let ids = active.split(separator: ",").map(String.init).filter {
            !$0.isEmpty
        }
        return ids.map { id in
            let label =
                defaults?.string(forKey: "\(keyCardLabelBase)_\(id)")
                ?? "QR Code"
            return CardEntity(id: id, label: label)
        }
    }

    func entities(for identifiers: [String]) async throws -> [CardEntity] {
        loadCards().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [CardEntity] {
        loadCards()
    }

    func defaultResult() async -> CardEntity? {
        loadCards().first
    }
}

/// Configuration intent for the QR widget that allows selecting which card to display.
struct SelectCardIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Select Card" }
    static var description: IntentDescription {
        "Choose which card's QR code to display on your home screen."
    }

    @Parameter(title: "Card")
    var card: CardEntity?
}
