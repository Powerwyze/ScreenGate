package com.powerwyze.questime

import android.content.Context

object QuestimeControlStore {
    private const val preferencesName = "questime_controls"
    private const val blockedPackagesKey = "blocked_packages"
    private const val awardedMinutesKey = "awarded_minutes"
    private const val remainingSecondsKey = "remaining_seconds"

    fun configure(context: Context, packages: Set<String>?, awardedMinutes: Int) {
        val preferences = context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
        val previousAwardedMinutes = preferences.getInt(awardedMinutesKey, 0)
        val newMinutes = (awardedMinutes - previousAwardedMinutes).coerceAtLeast(0)
        val remainingSeconds = preferences.getLong(remainingSecondsKey, 0)
        val editor = preferences.edit()
            .putInt(awardedMinutesKey, maxOf(previousAwardedMinutes, awardedMinutes))
            .putLong(remainingSecondsKey, remainingSeconds + newMinutes * 60L)
        if (packages != null) editor.putStringSet(blockedPackagesKey, packages)
        editor.apply()
    }

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
