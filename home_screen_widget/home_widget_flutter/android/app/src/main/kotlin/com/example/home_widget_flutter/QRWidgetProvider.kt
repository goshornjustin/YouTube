package com.example.home_widget_flutter

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.widget.RemoteViews
import java.io.File

class QRWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val SHARED_PREFS_NAME = "HomeWidgetPreferences"
        private const val QR_CODE_VALUE_KEY = "qr_code_value"
        private const val QR_CODE_LABEL_KEY = "qr_code_label"
        private const val QR_CODE_IMAGE_PATH_KEY = "qr_code_image_path"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        // Read data from SharedPreferences
        val prefs: SharedPreferences = context.getSharedPreferences(
            SHARED_PREFS_NAME,
            Context.MODE_PRIVATE
        )

        val qrValue = prefs.getString(QR_CODE_VALUE_KEY, "No Data") ?: "No Data"
        val qrLabel = prefs.getString(QR_CODE_LABEL_KEY, "QR Code") ?: "QR Code"
        val imagePath = prefs.getString(QR_CODE_IMAGE_PATH_KEY, "") ?: ""

        // Determine widget size and select appropriate layout
        val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
        val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
        val layout = when {
            minWidth < 180 -> R.layout.qr_widget_small
            minWidth < 270 -> R.layout.qr_widget_medium
            else -> R.layout.qr_widget_large
        }

        // Create RemoteViews
        val views = RemoteViews(context.packageName, layout)

        // Set label text
        views.setTextViewText(R.id.qr_label, qrLabel)

        // Load and set QR code image
        if (imagePath.isNotEmpty()) {
            val imageFile = File(imagePath)
            if (imageFile.exists()) {
                val bitmap = BitmapFactory.decodeFile(imagePath)
                if (bitmap != null) {
                    views.setImageViewBitmap(R.id.qr_image, bitmap)
                } else {
                    // Use placeholder if bitmap decoding failed
                    views.setImageViewResource(R.id.qr_image, android.R.drawable.ic_menu_gallery)
                }
            } else {
                // Use placeholder if file doesn't exist
                views.setImageViewResource(R.id.qr_image, android.R.drawable.ic_menu_gallery)
            }
        } else {
            // Use placeholder if no image path
            views.setImageViewResource(R.id.qr_image, android.R.drawable.ic_menu_gallery)
        }

        // Set up click intent to open app
        val intent = Intent(context, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)

        // Update widget
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}
