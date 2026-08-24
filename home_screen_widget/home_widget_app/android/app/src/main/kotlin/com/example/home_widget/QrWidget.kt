package com.example.home_widget

import android.content.Context
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.ui.unit.dp
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.color.ColorProvider
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.ContentScale
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.padding
import androidx.glance.state.GlanceStateDefinition
import androidx.glance.state.PreferencesGlanceStateDefinition
import androidx.glance.text.Text
import androidx.glance.text.TextAlign
import androidx.glance.text.TextStyle
import es.antonborri.home_widget.HomeWidgetPlugin
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File

/**
 * Home screen QR widget, built with Jetpack Glance (Compose for App Widgets).
 *
 * Two separate stores are in play, and mixing them up is the usual source of bugs:
 *  - Glance state (per widget instance, [PreferencesGlanceStateDefinition]): holds only which
 *    card this particular widget instance is pinned to. Written by [QrWidgetConfigureActivity].
 *  - home_widget SharedPreferences ([HomeWidgetPlugin.getData]): shared app-wide, written by the
 *    Flutter side. Holds the card list and every card's image path, label, and background color.
 *
 * Card data is stored as flat keys suffixed with the card id (e.g. `qr_widget_image_path_<id>`)
 * because SharedPreferences has no nested structure.
 *
 * Redraws happen when Flutter calls `HomeWidget.updateWidget()`; this class never polls.
 */
class QrWidget : GlanceAppWidget() {
    // Per-instance state store. Required so two widgets on the home screen can show different cards.
    override val stateDefinition: GlanceStateDefinition<*> = PreferencesGlanceStateDefinition

    companion object {
        // Key prefixes in home_widget SharedPreferences. Real key = "<base>_<cardId>".
        // These strings must stay in sync with the Flutter side that writes them.
        const val KEY_IMAGE_PATH_BASE = "qr_widget_image_path"
        const val KEY_BG_COLOR_BASE = "qr_widget_bg_color"
        const val KEY_CARD_LABEL_BASE = "qr_widget_card_label"

        // Comma-separated list of card ids that currently exist. Source of truth for validity.
        const val KEY_ACTIVE_CARDS = "qr_widget_active_cards"

        // Glance-state key: the card id this widget instance is pinned to.
        val PREF_KEY_CARD_ID = stringPreferencesKey("widget_card_id")

        // App widgets get ~1.5MB for their RemoteViews payload; a full-res QR PNG blows past it
        // and the widget silently fails to render. Downsample to this max edge first.
        private const val MAX_BITMAP_PX = 300

    }

    /**
     * Builds the widget UI. Called by Glance on every update (add, resize, config change,
     * `updateWidget()` from Flutter). Runs on a background thread, but must not block for long.
     */
    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            GlanceTheme {
                val glanceState = currentState<Preferences>()
                val prefs = HomeWidgetPlugin.getData(context)
                val activeCards = getActiveCards(prefs)

                // Pinned card wins, but only if it still exists (the user may have deleted it in
                // the app). Otherwise, fall back to the first card, then to "" which renders the
                // placeholder instead of a stale/blank widget.
                val cardId = glanceState[PREF_KEY_CARD_ID]?.takeIf { activeCards.contains(it) }
                    ?: activeCards.firstOrNull()
                    ?: ""

                val imagePath = prefs.getString("${KEY_IMAGE_PATH_BASE}_$cardId", null)

                val cardLabel =
                    prefs.getString("${KEY_CARD_LABEL_BASE}_$cardId", "Qr Card")
                        ?: "Qr Card"

                val bgColorArgb = readColorArgb(prefs, "${KEY_BG_COLOR_BASE}_$cardId")

                // Regenerating a QR reuses the same file path, so path alone can't detect a change.
                // Mixing lastModified() into the produceState keys forces a re-decode on edit.
                val stamp = imagePath?.let { File(it).lastModified() } ?: 0L

                // Decode off the main thread. Emits null first, so the placeholder shows briefly
                // on cold load before the bitmap arrives.
                val bitmap by produceState<Bitmap?>(null, imagePath, stamp) {
                    value = withContext(Dispatchers.IO) {
                        imagePath?.takeIf { File(it).exists() }
                            ?.let { decodeSampledBitmap(it, MAX_BITMAP_PX, MAX_BITMAP_PX) }
                    }
                }
                QrWidgetContent(
                    context = context,
                    bitmap = bitmap,
                    bgColorArgb = bgColorArgb,
                    cardLabel = cardLabel
                )
            }
        }
    }

    /** Reads the comma-separated card id list written by Flutter. Empty list if unset. */
    private fun getActiveCards(prefs: SharedPreferences): List<String> {
        val activeCards = prefs.getString(KEY_ACTIVE_CARDS, "") ?: ""
        return activeCards.split(",").filter { it.isNotEmpty() }
    }

    /**
     * Reads an ARGB color, tolerating both types the value can arrive as: Flutter writes ints
     * that home_widget may store as Long. Reading with the wrong getter throws
     * ClassCastException, hence `prefs.all` plus a type check. Defaults to opaque white.
     */
    private fun readColorArgb(prefs: SharedPreferences, key: String): Int =
        when (val value = prefs.all[key]) {
            is Long -> value.toInt()
            is Int -> value
            else -> 0xFFFFFFFFL.toInt()
        }

    /**
     * Two-pass decode: measure the file's dimensions without allocating pixels
     * (`inJustDecodeBounds`), pick a sample size, then decode for real at that reduction.
     * Keeps the bitmap under the app widget memory limit. Null if the file can't be decoded.
     */
    private fun decodeSampledBitmap(path: String, reqWidth: Int, reqHeight: Int): Bitmap? {
        val opts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, opts)
        opts.inSampleSize =
            calculatedInSampleSize(opts.outWidth, opts.outHeight, reqWidth, reqHeight)
        opts.inJustDecodeBounds = false
        return BitmapFactory.decodeFile(path, opts)
    }


    /**
     * Largest power-of-two downscale that still leaves the image at or above the requested size.
     * BitmapFactory rounds inSampleSize down to a power of two anyway, so only those are tried.
     */
    private fun calculatedInSampleSize(
        width: Int,
        height: Int,
        reqWidth: Int,
        reqHeight: Int
    ): Int {
        var sampleSize = 1
        if (height > reqHeight || width > reqWidth) {
            val halfHeight = height / 2
            val halfWidth = width / 2
            while (halfHeight / sampleSize >= reqHeight && halfWidth / sampleSize >= reqWidth) {
                sampleSize *= 2
            }
        }
        return sampleSize
    }
}


/**
 * The widget's visible surface: card background, QR image, tap target.
 * Tapping anywhere opens [MainActivity] — widgets can only launch declared components, so the
 * activity must be exported/registered in the manifest for this to work.
 * Falls back to [PlaceHolderContent] when there's no bitmap yet or no card configured.
 */
@Composable
private fun QrWidgetContent(
    context: Context,
    bitmap: Bitmap?,
    bgColorArgb: Int,
    // Not drawn — used only for the image's accessibility description.
    cardLabel: String
) {
    val bgColor = androidx.compose.ui.graphics.Color(bgColorArgb)

    // Same color passed twice to ColorProvider: day and night. The card color is user-chosen,
    // so it must not flip with the system theme.

    Box(
        modifier = GlanceModifier.fillMaxSize().background(ColorProvider(bgColor, bgColor))
            .padding(8.dp)
            .clickable(actionStartActivity<MainActivity>()), contentAlignment = Alignment.Center
    ) {
        if (bitmap != null) {
            Image(
                provider = ImageProvider(bitmap), contentDescription = "Qr Code for $cardLabel",
                modifier = GlanceModifier.fillMaxSize(),
                contentScale = ContentScale.Fit
            )

        } else {
            PlaceHolderContent()
        }
    }
}

/** Shown before the bitmap loads, or when no card is configured / its image file is missing. */
@Composable
private fun PlaceHolderContent() {
    Column(
        modifier = GlanceModifier.fillMaxSize().padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = "Open to Configure QR Widget",
            style = TextStyle(textAlign = TextAlign.Center)
        )
    }
}

/**
 * BroadcastReceiver Android actually talks to. This — not [QrWidget] — is what the manifest
 * `<receiver>` entry and `appwidget-provider` XML must point at.
 */
class QrWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = QrWidget()
}