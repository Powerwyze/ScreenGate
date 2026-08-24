package com.powerwyze.questime

import android.content.Context
import java.util.Calendar

object ScreenGateControlStore {
    private const val preferencesName = "questime_controls"
    private const val blockedPackagesKey = "blocked_packages"
    private const val awardedMinutesKey = "awarded_minutes"
    private const val remainingSecondsKey = "remaining_seconds"
    private const val soloDayKey = "solo_day"
    private const val soloModeKey = "solo_mode"
    private const val soloDailyLimitSeconds = 60 * 60

    fun configure(
        context: Context,
        packages: Set<String>?,
        awardedMinutes: Int,
        soloMode: Boolean = false,
    ) {
        val preferences = context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
        val today = Calendar.getInstance().let {
            "${it.get(Calendar.YEAR)}-${it.get(Calendar.DAY_OF_YEAR)}"
        }
        val dayChanged = soloMode && preferences.getString(soloDayKey, null) != today
        val previousAwardedMinutes = if (dayChanged) {
            0
        } else {
            preferences.getInt(awardedMinutesKey, 0)
        }
        val newMinutes = (awardedMinutes - previousAwardedMinutes).coerceAtLeast(0)
        val storedSeconds = if (dayChanged) {
            0L
        } else {
            preferences.getLong(remainingSecondsKey, 0L)
        }
        val remainingSeconds = if (soloMode) {
            (storedSeconds + newMinutes * 60L).coerceAtMost(soloDailyLimitSeconds.toLong())
        } else {
            storedSeconds + newMinutes * 60L
        }
        val editor = preferences.edit()
            .putInt(awardedMinutesKey, maxOf(previousAwardedMinutes, awardedMinutes))
            .putLong(remainingSecondsKey, remainingSeconds)
        if (soloMode) editor.putString(soloDayKey, today)
        editor.putBoolean(soloModeKey, soloMode)
        if (packages != null) editor.putStringSet(blockedPackagesKey, packages)
        editor.apply()
    }

    fun isSoloMode(context: Context): Boolean =
        context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
            .getBoolean(soloModeKey, false)

    fun blockedPackages(context: Context): Set<String> =
        context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
            .getStringSet(blockedPackagesKey, emptySet())
            ?.toSet()
            .orEmpty()

    fun remainingSeconds(context: Context): Long =
        context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
            .getLong(remainingSecondsKey, 0)

    fun spendSecond(context: Context): Long {
        val remaining = (remainingSeconds(context) - 1).coerceAtLeast(0)
        context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
            .edit()
            .putLong(remainingSecondsKey, remaining)
            .apply()
        return remaining
    }
}
