# QR Home Widget Architecture

```mermaid
flowchart TD
    subgraph FL["FLUTTER (Dart)"]
        UI["CreateHomeWidget UI<br/>create_home_widget.dart<br/>reads cardId, custom Qr data,"]
        BR["QrHomeWidget bridge<br/>util/home_widget.dart"]
        QR["QrImageView (qr_flutter)<br/>rendered to PNG"]
        HW["home_widget plugin API"]
        UI -->|"updateWidgetForCard(...)"| BR
        BR -->|"build QR widget"| QR
        QR -->|"renderFlutterWidget → PNG file"| HW
        BR -->|"saveWidgetData(keys)"| HW
        BR -->|"updateWidget(android,iOS)"| HW
    end
    subgraph STORE["SHARED STORAGE (per-card keys, cardId suffix)"]
        AND_S["Android SharedPreferences<br/>qr_widget_image_path_&lt;id&gt;<br/>qr_widget_bg_color_&lt;id&gt;<br/>qr_widget_card_label_&lt;id&gt;<br/>qr_widget_active_cards<br/>+ PNG file on disk"]
        IOS_S["iOS UserDefaults<br/>App Group:<br/>group.com.example.yourapp.QrWidget<br/>(same keys) + PNG file"]
    end
    HW -->|Android channel| AND_S
    HW -->|iOS channel| IOS_S
    subgraph AND["ANDROID NATIVE (Glance)"]
        ANR["QrWidgetReceiver<br/>(GlanceAppWidgetReceiver)"]
        ANW["QrWidget.provideGlance()<br/>HomeWidgetPlugin.getData()<br/>decode+downsample bitmap ≤300px"]
        ANC["QrWidgetContent Composable<br/>Image / placeholder<br/>click → MainActivity"]
        ANR --> ANW --> ANC
    end
    subgraph IOS["iOS NATIVE (WidgetKit)"]
        IOP["QrProvider (AppIntentTimelineProvider)<br/>UserDefaults(suiteName: appGroup)<br/>loadEntry(): UIImage + ARGB→Color"]
        IOV["QrWidgetEntryView<br/>Image / placeholder<br/>containerBackground(bgColor)"]
        IOP -->|"Timeline policy .never"| IOV
    end
    AND_S -->|updateWidget triggers refresh| ANR
    IOS_S -->|updateWidget triggers refresh| IOP
```

## Key points

- **Bridge = `home_widget_config.dart`.** Single contract both platforms read.
- **Multi-card scheme:** base keys + `_<cardId>` suffix. `qr_widget_active_cards` = comma list. Both natives fall back to first active card when widget unconfigured.

| Stage | Android | iOS |
|-------|---------|-----|
| Read API | `HomeWidgetPlugin.getData()` → SharedPreferences | `UserDefaults(suiteName: appGroup)` |
| Per-widget card pick | Glance state `widget_card_id` | `SelectCardIntent.card.id` |
| Image | PNG path → `BitmapFactory` downsample ≤300px (binder ~1MB limit) | PNG path → `UIImage(contentsOfFile:)` |
| BG color | Long ARGB → Compose `Color` | Int ARGB → bit-shift → SwiftUI `Color` |
| Refresh | `updateWidget` → `QrWidgetReceiver` | `updateWidget` → reload timeline (`.never` policy) |

- **Data written, not pushed:** Flutter renders PNG + writes metadata, then fires `updateWidget`. Natives pull from shared storage on next render. No live channel — storage is the handoff.
- **Names that must match:** appGroup `group.com.example.yourapp.QrWidget`, android `QrWidgetReceiver`, iOS `QrWidget`, storage key strings (duplicated across all 3 layers — change one, change all).
