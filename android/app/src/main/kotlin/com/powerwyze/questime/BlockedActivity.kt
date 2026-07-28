package com.powerwyze.questime

import android.app.Activity
import android.graphics.Color
import android.os.Bundle
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

class BlockedActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val padding = (28 * resources.displayMetrics.density).toInt()
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(padding, padding, padding, padding)
            setBackgroundColor(Color.rgb(247, 250, 249))
        }
        layout.addView(TextView(this).apply {
            text = "Quest first!"
            textSize = 34f
            gravity = Gravity.CENTER
            setTextColor(Color.rgb(23, 50, 77))
        }, ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
        layout.addView(TextView(this).apply {
            text = "You are out of play time. Finish a quest and ask your parent to approve it."
            textSize = 19f
            gravity = Gravity.CENTER
            setTextColor(Color.rgb(102, 118, 132))
            setPadding(0, padding, 0, padding)
        }, ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
        layout.addView(Button(this).apply {
            text = "GO TO QUESTIME"
            setOnClickListener {
                packageManager.getLaunchIntentForPackage(packageName)?.let(::startActivity)
                finish()
            }
        }, ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
        setContentView(layout)
    }

    override fun onBackPressed() {
        packageManager.getLaunchIntentForPackage(packageName)?.let(::startActivity)
        finish()
    }
}
