# YouTube Script — QR Code Home Screen Widgets in Flutter (iOS + Android)

**Channel:** yaboyiscoding
**Status:** DRAFT for voiceover — ordered to match the recorded footage.
**Footage order (confirmed):** hook → finished product → Android → iOS → Flutter → running code.
**Working titles:**
- "Flutter Home Screen Widgets, the Production Way (iOS + Android)"
- "I Put a Live QR Code on the Home Screen — Flutter, WidgetKit & Glance"
- "Home Screen Widgets in Flutter That Actually Sync (Multi-Card, Both Platforms)"

**Repo shown:** `home_widget_app` — deps: `qr_flutter ^4.1.0`, `home_widget ^0.9.0`.

> **How to use this:** Each section is a VO block that maps to a segment of your footage, in your recording order. Bracketed `[…]` notes are direction, not spoken. Timings are targets — see the Editing / pacing note below, because at 80 min the whole thing needs tightening and the VO should be recorded against the *tightened* cut.

---

## ✂️ Editing / pacing note (read before recording)
At 80 minutes this won't retain unless it's framed as a full build-along. Priority order for the cut:
1. **Cut the live typing** — biggest lever by far. This script narrates *finished* code, not keystrokes, so it fits a "show the completed block, explain it" edit. Do that and you'll shed most of the runtime.
2. **Speed-ramp what's left** — boilerplate, imports, repetitive edits at 3–8x, no VO or light music.
3. **Keep real-time only for the 4 "aha" moments:** render-to-PNG, the native shared-storage read, the Android downsample, the ARGB color rebuild.
4. **Consider a tighter main cut (~15–20 min) for growth**, with the full build as an optional Part 2. If you ship only one, ship the tight one.

Record VO *after* you lock the cut so blocks match clip lengths.

---

## 1. Cold open / hook  (~0:00–0:15)

*[Footage: your hook.]*

**VO:**
"Real quick — go search 'Flutter home screen widget,' and almost every tutorial shows you the same thing: a little box with some text in it. And that's fine, but it's not what you actually ship in a real app. Real apps put *live, rendered* content on the home screen and keep it in sync on both iOS and Android. So that's what we're building today. A Flutter app that generates a styled QR code and drops it right onto your home screen — as a real native widget, on both platforms — and you can have more than one. And if you've tried this before and hit a wall, stick around, because I hit basically every wall so you don't have to."

---

## 2. Finished product  (~0:15–0:45)

*[Footage: the finished result — the QR widget live on the home screen, both devices if you have them.]*

**VO:**
"But before we write a single line, let me show you the end result — because I want you to see it actually works. So here it is, sitting on my home screen. That's a real, styled QR code — custom colors, custom shapes — not some gray placeholder box. I type a value into the app, hit save, and boom, it's up here. And watch — I can add a second one, completely independent of the first. So that's the goal. Now let's take it apart. And we're gonna start on the native side, because honestly that's the part nobody explains properly."

---

## 3. The mental model  (~0:45–1:30)

*[Footage: architecture diagram or a quick three-box overlay — Flutter → Shared Storage → Native Widgets. Slot this over the transition into the native code.]*

**VO:**
"Okay, one idea, and if you get this, the whole video clicks. A home screen widget is *native*. On iOS that's WidgetKit, on Android that's Glance. And here's the catch — that native widget can't just call your Dart code. There's no live wire between them. So how do they talk? Through shared storage. Picture a dropbox that both sides can reach into. Flutter draws the QR code, saves it as an image into that shared spot along with a little info — the background color, a label — and then it basically taps the OS on the shoulder and goes, 'hey, refresh.' The widget wakes up, reads from that same spot, and draws whatever it finds. That's the whole thing. Flutter *writes*, native *reads* — nothing gets pushed across. Data written, not pushed. Seriously, tattoo that on your brain, because almost every bug you'll hit comes straight back to it. Oh, and one more thing to keep an eye on: three different layers all share these same key names — Dart, Android, and iOS. If those names don't line up *exactly*, the whole thing just quietly stops working. Watch for it as we go."

---

## 4. Android native — Glance  (~1:30–3:30)

*[Footage: `QrWidgetReceiver` / `QrWidget.kt`, `provideGlance`, the `HomeWidgetPlugin.getData()` read, the bitmap downsample, `QrWidgetContent`.]*

**VO:**
"Alright, Android first, since that's what's on screen. If you haven't touched widgets in a while, the modern way is Glance — and Glance is basically Compose, just for the home screen. Which is great, because it's Kotlin you already recognize. So our entry point is this `QrWidgetReceiver`, and it hands off to `provideGlance`. And right here — this is the line that matters — we reach into that shared storage with `HomeWidgetPlugin.getData`, grabbing the exact same keys the Flutter side is gonna write. We pull the image path, load the PNG.

Now — here's the one that'll cost you an afternoon, because it got me. Android has this roughly one-megabyte limit on data crossing into the widget's process. And a full-size QR image? It blows right past that. And the worst part is your widget just dies — no crash log, no error, nothing, just a blank square. So the fix is: before we hand that image over, we shrink it — downsample it down to around 300 pixels. And boom, problem gone. After that it's easy: `QrWidgetContent` just draws the image, or a placeholder if nothing's saved yet, and we make a tap open the app. And that's Android, done."

---

## 5. iOS native — WidgetKit  (~3:30–5:30)

*[Footage: `QrWidget.swift`, `QrProvider`, `UserDefaults(suiteName:)`, `loadEntry`, ARGB→Color, `containerBackground`. If you show `AppIntent.swift` / `SelectCardIntent`, the multi-card line lands here.]*

**VO:**
"iOS is the exact same story, just with WidgetKit words. This `QrProvider` is our timeline provider, and the part to watch is `loadEntry` — that's where we go read the shared data. But look closely, because it's subtle: we're reading `UserDefaults`, but with a *suite name* — and that suite name is the App Group. That right there is the whole trick on iOS. A normal `UserDefaults` is private to your app. Point it at the App Group instead, and suddenly your app and your widget are reading and writing the same box. And heads up — you have to turn that App Group capability on in Xcode for *both* targets, the app and the widget. Miss it on one, and nothing works.

Okay, so we read the image path, build a `UIImage`, and then we rebuild the background color. And you'll notice the color's stored as just a plain number — an ARGB integer — and we bit-shift it back into a SwiftUI Color. And real quick, the 'why' on that: we store color as a number because Dart, Kotlin, and Swift all speak numbers. They just each rebuild the color their own way. Then the view draws the image and sets the background. And one thing I really want to point out — our refresh policy is `.never`. We are literally telling iOS, 'do not refresh this on a timer.' And why would we? Nothing here changes on a clock. It only changes when the user saves a new card — and that's the exact moment Flutter tells it to reload. And that little card-picker you get when you long-press the widget? That's this `SelectCardIntent` right here."

---

## 6. Flutter — the UI and the bridge  (~5:30–8:30)  ⭐ core section

*[Footage: `pubspec.yaml`, the constants + `updateWidgetForCard` in `home_widget_config.dart`, then `save_qr_widget.dart` running.]*

**VO:**
"Okay, now the Flutter side — the part that writes everything those two widgets were just reading. Two packages doing the work: `qr_flutter` to actually draw the QR code, and `home_widget` to talk to the native side.

Now look at these constants up top — the App Group ID, the Android name, the iOS name, all the storage keys. *These* are the exact strings we kept bumping into over in the native code. This is where they live. And I keep every one of them in this one spot, and I don't mess with them casually, because one typo right here and you're back to staring at a blank widget wondering what you broke. First thing we actually do is `initialize`, which sets that App Group ID — and that's gotta happen before you read or write anything.

The UI itself is almost nothing, on purpose — a text field and a save button. Because the UI isn't the lesson here, the pipeline is. So you hit save, and that calls `updateWidgetForCard`. Let me walk the steps, because this is the heart of the whole thing. Step one: we build a `QrImageView` — that's qr_flutter — with our colors and our shapes. Step two, and this is the slick part — we do *not* take a screenshot. We call `renderFlutterWidget`, and that renders the QR widget off-screen, straight to a PNG, and saves it. And notice the key it saves under has the card's ID tacked onto the end — hang onto that, it's how we get multiple cards. Step three: we save what native needs — the background color as that ARGB number, and the label. Step four: we add this card to our list of active cards. And step five: `updateWidget` — that's the tap on the shoulder telling both platforms to reload. Render it, save it, tag it, ping it. That's the entire handoff, right there in one method.

And multi-card kind of just falls out of it. Every key ends in the card's ID, and we keep one list of which cards are live. Add a card, it goes on the list; remove one, we wipe its keys. And in case you're wondering why we render a whole Flutter widget to an image instead of drawing the QR natively on each platform — this way we build it *once*, in Flutter, get all that styling for free, and both sides just display the picture. Less code, and it always matches."

---

## 7. Gotchas recap  (~8:30–9:00)

*[Footage: bullets on screen, or back to the diagram.]*

**VO:**
"Let me leave you with the four things that actually break this, so you can skip the pain I went through. One: those names and keys have to match across all three layers — Dart, Android, iOS. One typo, blank widget. Two: remember, storage is the handoff. So if your widget's showing old data, nine times out of ten you just forgot to call `updateWidget`. Three: downsample your image on Android, or you smack right into that size limit. And four: color's just a number, an ARGB int, rebuilt on each side. Get those four right, and honestly? The rest is just UI."

---

## 8. Running code — proof + CTA  (~9:00–end)

*[Footage: the live run — type a value, save, both home screens update; add a second card.]*

**VO:**
"Alright, moment of truth — let's run it. I'll type in a value... hit save... and there it is, live on the home screen. And let me add a second card real quick — different data — and now I've got two totally separate widgets pulling from the same app. That's a genuine, production-shaped feature. Not a text box.

So if this saved you a weekend of fighting App Groups and Glance — and trust me, it's a fight — do me a solid and hit subscribe. This whole channel is real-world Flutter and React Native — the stuff you actually run into on the job, not toy examples. Full code's linked in the description. And I'll catch you in the next one."

---

## 📋 Talking-point coverage checklist

Audit your footage against this. **★ = major point, don't ship without it. ○ = depth/nice-to-have.** If a ★ is missing, cover it in VO over B-roll or add a pickup.

### 1. Hook
- ★ Name the problem out loud: typical widget tutorials = a static text box.
- ★ The contrast: real apps push *dynamic, rendered* content, synced across both platforms.
- ★ Promise the payoff: styled QR on the home screen, iOS + Android, multiple cards.
- ○ One line on *why it matters on the job* (this is yaboyiscoding's angle).

### 2. Finished product
- ★ Show the real result on an actual home screen — styled QR, not a placeholder.
- ★ Show (or explicitly say) it works on both iOS and Android.
- ○ Flash the multi-card payoff (two widgets) so it's promised early.
- ○ Set the expectation: "by the end you'll understand each piece."

### 3. Mental model / architecture
- ★ Widgets are **native** (WidgetKit / Glance) — they don't talk to Dart directly.
- ★ They communicate through **shared storage, not a live channel** — "data written, not pushed."
- ★ The three layers: Flutter writes → shared container → native reads.
- ★ The handoff loop: render → store PNG + metadata → `updateWidget` ping → native pulls.
- ★ Introduce the name/key-matching rule early (it explains the native code that follows).
- ○ Show the architecture diagram on screen.

### 4. Android — Glance
- ★ Glance = Compose for the home screen (the modern approach).
- ★ `QrWidgetReceiver` is the entry point; `provideGlance()` reads via `HomeWidgetPlugin.getData()` — same keys Flutter writes.
- ★ Load the PNG from the stored image path.
- ★ **Gotcha:** ~1MB process-boundary limit → **downsample the bitmap to ≤300px** or the widget crashes.
- ★ `QrWidgetContent`: draw the image, with a placeholder fallback when there's no data.
- ○ Tap action opens `MainActivity`.
- ○ Per-widget card pick via Glance state (`widget_card_id`) if you show `QrWidgetConfigureActivity`.
- ○ Manifest registration + `qr_widget_info.xml` (sizing/preview) if shown.

### 5. iOS — WidgetKit
- ★ `QrProvider` is a timeline provider.
- ★ **App Group** is the shared container; `UserDefaults(suiteName: appGroup)` — the suite name is what makes it shared.
- ★ `loadEntry()`: image path → `UIImage`.
- ★ Background color: **ARGB int → bit-shift → SwiftUI `Color`** (explain *why* color is stored as a raw int — it's cross-language).
- ★ Entry view draws image/placeholder + `containerBackground`.
- ★ Timeline policy `.never` — no scheduled refresh; reloads are driven by Flutter's `updateWidget`.
- ○ Multi-card: `SelectCardIntent` (`AppIntent.swift`) lets each placed widget pick a card.
- ○ Xcode setup gotchas: add the widget target, enable the App Group capability + entitlement on *both* app and widget.

### 6. Flutter — UI + bridge  (core)
- ★ Deps: `qr_flutter` + `home_widget`.
- ★ The constants block (`appGroupId`, `QrWidgetReceiver`, `QrWidget`, key bases) — these are the strings that had to match the native code. Payoff on the matching rule.
- ★ `initialize()` → `HomeWidget.setAppGroupId` must run before any read/write.
- ★ The UI is deliberately minimal (text field + Save) — the pipeline is the point.
- ★ `updateWidgetForCard` — walk the 5 steps:
  1. Build `QrImageView` with styling (eye shape/color, data-module shape/color, size, `QrVersions.auto`).
  2. `renderFlutterWidget` renders **off-screen to a PNG** under a per-card key — emphasize it's *not* a screenshot.
  3. `saveWidgetData`: bg color via `toARGB32()`, plus the label.
  4. `_addToActiveList`: register the card ID.
  5. `updateWidget(androidName, iOSName)` — the ping.
- ★ Multi-card scheme: per-card key suffix `_<cardId>` + `qr_widget_active_cards` comma list; `removeWidget` nulls the keys.
- ○ Fallback to the first active card when a widget isn't configured (ties back to native).
- ○ *Why render a Flutter widget to PNG at all* — you get qr_flutter's styling for free instead of drawing QR natively twice.

### 7. Gotchas recap
- ★ Names/keys match across all three layers.
- ★ Storage is the handoff — stale data usually means a missing `updateWidget`.
- ★ Downsample on Android for the size limit.
- ★ Color is a raw ARGB int, rebuilt per platform.
- ○ App Group enabled in Xcode; Android receiver registered in the manifest.

### 8. Running code — proof + CTA
- ★ Live end-to-end: type → Save → widget appears on the home screen.
- ★ Add a second card → two independent widgets (multi-card payoff).
- ○ Remove/edit a card to demonstrate `removeWidget`.
- ★ CTA: subscribe + repo link in description.
- ○ Tease the next video; add chapters/timestamps.

---

## Post-record checklist
- [ ] Lock the tightened cut first, then record VO against it.
- [ ] Trim any VO block that runs long against its clip.
- [ ] Repo link + chapters in the description.
- [ ] Thumbnail: the QR widget on a real home screen.
