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

/**
 * Widget configuration screen, launched by the launcher when the user drops a [QrWidget] on the
 * home screen (wired up via `android:configure` in the appwidget-provider XML).
 *
 * Job: let the user pick which card this one widget instance shows, then write that choice into
 * that instance's Glance state ([QrWidget.PREF_KEY_CARD_ID]). Card *content* lives in
 * home_widget SharedPreferences and is written by Flutter — this screen never touches it.
 *
 * No Compose UI here: a plain [AlertDialog] over a transparent Activity, so the picker appears
 * on top of the home screen instead of opening a full app screen.
 *
 * Configure-activity contract: the launcher only keeps the widget if this Activity finishes with
 * RESULT_OK plus the widget id echoed back. Any other exit (back press, crash) means the launcher
 * discards the placed widget.
 */
class QrWidgetConfigureActivity : Activity() {

    // Which widget instance is being configured. Supplied by the launcher's intent.
    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Default to cancelled so bailing out at any point (back press, invalid id) drops the
        // widget instead of leaving an unconfigured one on the home screen. Upgraded to
        // RESULT_OK only in confirm().
        setResult(RESULT_CANCELED)

        appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

        // No id means we weren't launched as a config activity. Nothing to configure — leaving
        // the result as CANCELED.
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }
        val prefs = HomeWidgetPlugin.getData(this)

        // Same comma-separated card list QrWidget reads. Order matters: the dialog's selected
        // index maps back into this list.
        val activeCards = (prefs.getString(QrWidget.KEY_ACTIVE_CARDS, "") ?: "")
            .split(",")
            .filter { it.isNotEmpty() }

        // User hasn't created any cards yet (fresh install). Place the widget anyway with no card
        // pinned — it renders the "Open to Configure" placeholder and picks up the first card once
        // one exists.
        if (activeCards.isEmpty()) {
            confirm(null)
            return
        }

        // Show human labels, fall back to the raw id if a card has none.
        val labels = activeCards.map { id ->
            prefs.getString("${QrWidget.KEY_CARD_LABEL_BASE}_$id", id) ?: id
        }.toTypedArray()

        AlertDialog.Builder(this)
            .setTitle("Choose a card")
            .setItems(labels) { _, which -> confirm(activeCards[which]) }
            // Dismissed without choosing: finish while still CANCELED so the widget is dropped.
            .setOnCancelListener { finish() }
            .show()
    }

    /**
     * Persists the chosen card to this widget instance's Glance state, forces a redraw, then
     * reports success to the launcher so the widget is kept.
     *
     * @param cardId card to pin, or null to place the widget with no pinned card.
     *
     * Async because [GlanceAppWidgetManager.getGlanceIdBy] and [updateAppWidgetState] are
     * suspending — [finish] therefore happens after onCreate returns, not during it.
     */
    private fun confirm(cardId: String?) {
        CoroutineScope(Dispatchers.Main).launch {
            // Translate the launcher's int widget id into the GlanceId the Glance APIs need.
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

            // The launcher does not draw a newly placed widget on its own; this triggers the
            // first provideGlance() pass.
            QrWidget().update(this@QrWidgetConfigureActivity, glanceId)

            // Echoing the widget id back with RESULT_OK is what tells the launcher to keep it.
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