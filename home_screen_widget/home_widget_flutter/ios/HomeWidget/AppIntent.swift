//
//  AppIntent.swift
//  HomeWidget
//
//  Created by Justin on 1/1/26.
//

import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "QR Code Configuration" }
    static var description: IntentDescription { "Display a custom QR code on your home screen." }
}
