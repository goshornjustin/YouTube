package com.example.home_widget

import android.app.Activity
import android.app.AlertDialog
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.state.updateAppWidgetState
import androidx.glance.state.PreferencesGlanceStateDefinition
import es.antonborri.home_widget.HomeWidgetPlugin
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class QrWidgetConfigureActivity : Activity() {

    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        setResult(RESULT_CANCELED)

        appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }
        val prefs = HomeWidgetPlugin.getData(this)

        val activeCards = (prefs.getString(QrWidget.KEY_ACTIVE_CARDS, "") ?: "")
            .split(",")
            .filter { it.isNotEmpty() }

        if (activeCards.isEmpty()) {
            confirm(null)
            return
        }

        val labels = activeCards.map { id ->
            prefs.getString("${QrWidget.KEY_CARD_LABEL_BASE}_$id", id) ?: id
        }.toTypedArray()

        AlertDialog.Builder(this)
            .setTitle("Choose a card")
            .setItems(labels) { _, which -> confirm(activeCards[which]) }
            .setOnCancelListener { finish() }
            .show()
    }

    private fun confirm(cardId: String?) {
        CoroutineScope(Dispatchers.Main).launch {
            val glanceId =
                GlanceAppWidgetManager(this@QrWidgetConfigureActivity)
                    .getGlanceIdBy(appWidgetId)

            if (cardId != null) {
                updateAppWidgetState(
                    this@QrWidgetConfigureActivity,
                    PreferencesGlanceStateDefinition,
                    glanceId
                ) { prefs ->
                    prefs.toMutablePreferences()
                        .apply { this[QrWidget.PREF_KEY_CARD_ID] = cardId }
                }
            }

            QrWidget().update(this@QrWidgetConfigureActivity, glanceId)

            setResult(
                RESULT_OK,
                Intent().putExtra(
                    AppWidgetManager.EXTRA_APPWIDGET_ID,
                    appWidgetId
                )
            )
            finish()
        }
    }
}
