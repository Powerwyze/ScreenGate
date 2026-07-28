package com.powerwyze.questime

import android.content.ComponentName
import android.content.Intent
import android.provider.Settings
import android.text.TextUtils
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.powerwyze.questime/screen_time"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> result.success(
                    mapOf(
                        "deviceName" to "${android.os.Build.MANUFACTURER} ${android.os.Build.MODEL}",
                        "osVersion" to android.os.Build.VERSION.RELEASE,
                        "supported" to true,
                        "authorized" to isAccessibilityEnabled(),
                    ),
                )
                "requestAuthorization" -> {
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(null)
                }
                "getInstalledApps" -> result.success(installedApps())
                "getConfiguration" -> result.success(
                    mapOf(
                        "packages" to QuestimeControlStore.blockedPackages(this).toList(),
                        "remainingSeconds" to QuestimeControlStore.remainingSeconds(this),
                    ),
                )
                "configure" -> {
                    val packages = call.argument<List<String>>("packages")?.toSet()
                    val awardedMinutes = call.argument<Int>("awardedMinutes") ?: 0
                    QuestimeControlStore.configure(this, packages, awardedMinutes)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun installedApps(): List<Map<String, String>> {
        val launcherIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return packageManager.queryIntentActivities(launcherIntent, 0)
            .filter { it.activityInfo.packageName != packageName }
            .map {
                mapOf(
                    "packageName" to it.activityInfo.packageName,
                    "name" to it.loadLabel(packageManager).toString(),
                )
            }
            .distinctBy { it["packageName"] }
            .sortedBy { it["name"]?.lowercase() }
    }

    private fun isAccessibilityEnabled(): Boolean {
        val expected = ComponentName(this, QuestimeAccessibilityService::class.java)
        val enabled = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: return false
        val splitter = TextUtils.SimpleStringSplitter(':')
        splitter.setString(enabled)
        return splitter.any { ComponentName.unflattenFromString(it) == expected }
    }
}
