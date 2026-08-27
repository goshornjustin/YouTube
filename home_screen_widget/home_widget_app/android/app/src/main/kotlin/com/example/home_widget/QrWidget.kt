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

class QrWidget : GlanceAppWidget() {
    override val stateDefinition: GlanceStateDefinition<*> = PreferencesGlanceStateDefinition

    companion object {
        const val KEY_IMAGE_PATH_BASE = "qr_widget_image_path"
        const val KEY_BG_COLOR_BASE = "qr_widget_bg_color"
        const val KEY_CARD_LABEL_BASE = "qr_widget_card_label"

        const val KEY_ACTIVE_CARDS = "qr_widget_active_cards"

        val PREF_KEY_CARD_ID = stringPreferencesKey("widget_card_id")

        private const val MAX_BITMAP_PX = 300

    }

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            GlanceTheme {
                val glanceState = currentState<Preferences>()
                val prefs = HomeWidgetPlugin.getData(context)
                val activeCards = getActiveCards(prefs)

                val cardId = glanceState[PREF_KEY_CARD_ID]?.takeIf { activeCards.contains(it) }
                    ?: activeCards.firstOrNull()
                    ?: ""

                val imagePath = prefs.getString("${KEY_IMAGE_PATH_BASE}_$cardId", null)

                val cardLabel =
                    prefs.getString("${KEY_CARD_LABEL_BASE}_$cardId", "Qr Card")
                        ?: "Qr Card"

                val bgColorArgb = readColorArgb(prefs, "${KEY_BG_COLOR_BASE}_$cardId")

                val stamp = imagePath?.let { File(it).lastModified() } ?: 0L

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

    private fun getActiveCards(prefs: SharedPreferences): List<String> {
        val activeCards = prefs.getString(KEY_ACTIVE_CARDS, "") ?: ""
        return activeCards.split(",").filter { it.isNotEmpty() }
    }

    private fun readColorArgb(prefs: SharedPreferences, key: String): Int =
        when (val value = prefs.all[key]) {
            is Long -> value.toInt()
            is Int -> value
            else -> 0xFFFFFFFFL.toInt()
        }

    private fun decodeSampledBitmap(path: String, reqWidth: Int, reqHeight: Int): Bitmap? {
        val opts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, opts)
        opts.inSampleSize =
            calculatedInSampleSize(opts.outWidth, opts.outHeight, reqWidth, reqHeight)
        opts.inJustDecodeBounds = false
        return BitmapFactory.decodeFile(path, opts)
    }


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


@Composable
private fun QrWidgetContent(
    context: Context,
    bitmap: Bitmap?,
    bgColorArgb: Int,
    cardLabel: String
) {
    val bgColor = androidx.compose.ui.graphics.Color(bgColorArgb)

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

class QrWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = QrWidget()
}
