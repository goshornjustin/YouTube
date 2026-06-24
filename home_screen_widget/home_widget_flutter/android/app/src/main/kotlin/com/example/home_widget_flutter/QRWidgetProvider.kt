package com.example.home_widget_flutter

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.os.Bundle
import android.widget.RemoteViews
import java.io.File

class QRWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val SHARED_PREFS_NAME = "HomeWidgetPreferences"
        private const val QR_CODE_VALUE_KEY = "qr_code_value"
        private const val QR_CODE_LABEL_KEY = "qr_code_label"
        private const val QR_CODE_IMAGE_PATH_KEY = "qr_code_image_path"

        // Max dimension (px) to decode the QR bitmap at. The source image is 1024×1024 but widget
        // views are small — loading the full bitmap wastes memory and risks OOM on low-RAM devices.
        // 512px is more than enough detail for any scannable widget size.
        private const val BITMAP_MAX_PX = 512
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

    // Called whenever the user resizes the widget on the home screen.
    // Without this override the layout never switches between small/medium/large
    // until the next scheduled onUpdate — which may never fire (updatePeriodMillis=0).
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        updateAppWidget(context, appWidgetManager, appWidgetId)
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val prefs: SharedPreferences = context.getSharedPreferences(
            SHARED_PREFS_NAME,
            Context.MODE_PRIVATE
        )

        val qrLabel = prefs.getString(QR_CODE_LABEL_KEY, "QR Code") ?: "QR Code"
        val imagePath = prefs.getString(QR_CODE_IMAGE_PATH_KEY, "") ?: ""
        val qrValue = prefs.getString(QR_CODE_VALUE_KEY, "") ?: ""


        // Pick layout based on current widget width so the layout switches immediately
        // when the user resizes, not just on the next periodic update.
        val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
        val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
        val layout = when {
            minWidth < 180 -> R.layout.qr_widget_small
            minWidth < 270 -> R.layout.qr_widget_medium
            else -> R.layout.qr_widget_large
        }

        val views = RemoteViews(context.packageName, layout)
        views.setTextViewText(R.id.qr_label, qrLabel)
        views.setTextViewText(R.id.qr_value, qrValue)

        if (imagePath.isNotEmpty() && File(imagePath).exists()) {
            // Two-pass decode: first read only the image dimensions (inJustDecodeBounds),
            // then calculate an inSampleSize so we never load more pixels than needed.
            // Loading the raw 1024×1024 PNG every update would spike RAM and could OOM.
            val opts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(imagePath, opts)
            opts.inSampleSize = calculateInSampleSize(opts, BITMAP_MAX_PX, BITMAP_MAX_PX)
            opts.inJustDecodeBounds = false

            val bitmap = BitmapFactory.decodeFile(imagePath, opts)
            if (bitmap != null) {
                views.setImageViewBitmap(R.id.qr_image, bitmap)
            } else {
                views.setImageViewResource(R.id.qr_image, android.R.drawable.ic_menu_gallery)
            }
        } else {
            views.setImageViewResource(R.id.qr_image, android.R.drawable.ic_menu_gallery)
        }

        // Use a unique requestCode per widget ID so PendingIntents for different widget
        // instances are not collapsed into the same cached Intent by the OS.
        val intent = Intent(context, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            context,
            appWidgetId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    // Standard power-of-two subsampling: keep halving until the sampled size fits within
    // the requested bounds. Returns 1 (no subsampling) if the image is already small enough.
    private fun calculateInSampleSize(
        options: BitmapFactory.Options,
        reqWidth: Int,
        reqHeight: Int
    ): Int {
        var inSampleSize = 1
        if (options.outHeight > reqHeight || options.outWidth > reqWidth) {
            val halfHeight = options.outHeight / 2
            val halfWidth = options.outWidth / 2
            while (halfHeight / inSampleSize >= reqHeight && halfWidth / inSampleSize >= reqWidth) {
                inSampleSize *= 2
            }
        }
        return inSampleSize
    }
}
