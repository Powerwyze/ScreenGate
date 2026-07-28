package com.powerwyze.questime

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.view.accessibility.AccessibilityEvent

class QuestimeAccessibilityService : AccessibilityService() {
    private val handler = Handler(Looper.getMainLooper())
    private var foregroundPackage: String? = null
    private var blockerOpen = false

    private val ticker = object : Runnable {
        override fun run() {
            val current = foregroundPackage
            if (current != null && QuestimeControlStore.blockedPackages(this@QuestimeAccessibilityService).contains(current)) {
                if (QuestimeControlStore.remainingSeconds(this@QuestimeAccessibilityService) <= 0) {
                    showBlocker()
                } else {
                    QuestimeControlStore.spendSecond(this@QuestimeAccessibilityService)
                }
            }
            handler.postDelayed(this, 1000)
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        handler.post(ticker)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        val observedPackage = event.packageName?.toString() ?: return
        foregroundPackage = observedPackage
        if (QuestimeControlStore.blockedPackages(this).contains(observedPackage) &&
            QuestimeControlStore.remainingSeconds(this) <= 0
        ) {
            blockerOpen = false
            showBlocker()
        } else if (observedPackage != packageName) {
            blockerOpen = false
        }
    }

    override fun onInterrupt() = Unit

    override fun onDestroy() {
        handler.removeCallbacks(ticker)
        super.onDestroy()
    }

    private fun showBlocker() {
        if (blockerOpen) return
        blockerOpen = true
        performGlobalAction(GLOBAL_ACTION_HOME)
        startActivity(
            Intent(this, BlockedActivity::class.java)
                .addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS,
                ),
        )
    }
}
