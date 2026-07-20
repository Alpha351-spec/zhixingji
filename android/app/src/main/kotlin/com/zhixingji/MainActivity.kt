package com.zhixingji

import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.zhixingji.zhixingji/lock_screen"
    private var lockScreenView: View? = null
    private var countdownText: TextView? = null
    private var windowManager: WindowManager? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canDrawOverlays" -> {
                        result.success(canDrawOverlays())
                    }
                    "requestOverlayPermission" -> {
                        requestOverlayPermission()
                        result.success(true)
                    }
                    "showLockScreen" -> {
                        val timeRemaining = call.argument<Int>("timeRemaining") ?: 0
                        showLockScreen(timeRemaining)
                        result.success(true)
                    }
                    "hideLockScreen" -> {
                        hideLockScreen()
                        result.success(true)
                    }
                    "updateCountdown" -> {
                        val secondsRemaining = call.argument<Int>("secondsRemaining") ?: 0
                        updateCountdown(secondsRemaining)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /// 检查是否有悬浮窗权限
    private fun canDrawOverlays(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }

    /// 请求悬浮窗权限（跳转系统设置页）
    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!Settings.canDrawOverlays(this)) {
                val intent = Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:$packageName")
                )
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
            }
        }
    }

    /// 显示锁屏覆盖层
    private fun showLockScreen(timeRemaining: Int) {
        if (lockScreenView != null) {
            // 已存在，只更新倒计时
            updateCountdown(timeRemaining)
            return
        }

        if (!canDrawOverlays()) {
            Log.w("LockScreen", "没有悬浮窗权限，无法显示锁屏")
            return
        }

        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager

        val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            layoutType,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
            PixelFormat.OPAQUE
        )
        params.gravity = Gravity.CENTER

        // 创建锁屏视图
        val inflater = LayoutInflater.from(this)
        lockScreenView = inflater.inflate(R.layout.lock_screen, null)

        countdownText = lockScreenView?.findViewById(R.id.countdown_text)
        updateCountdown(timeRemaining)

        // 放弃专注按钮
        val abandonBtn = lockScreenView?.findViewById<Button>(R.id.abandon_btn)
        abandonBtn?.setOnClickListener {
            hideLockScreen()
            // 通过 MethodChannel 通知 Flutter 端
            MethodChannel(
                flutterEngine?.dartExecutor?.binaryMessenger!!,
                CHANNEL
            ).invokeMethod("on_abandon_focus", null)
        }

        try {
            windowManager?.addView(lockScreenView, params)
            Log.d("LockScreen", "锁屏已显示")
        } catch (e: Exception) {
            Log.e("LockScreen", "显示锁屏失败: ${e.message}")
        }
    }

    /// 隐藏锁屏覆盖层
    private fun hideLockScreen() {
        if (lockScreenView != null && windowManager != null) {
            try {
                windowManager?.removeView(lockScreenView)
                Log.d("LockScreen", "锁屏已隐藏")
            } catch (e: Exception) {
                Log.e("LockScreen", "隐藏锁屏失败: ${e.message}")
            }
            lockScreenView = null
            countdownText = null
        }
    }

    /// 更新倒计时显示
    private fun updateCountdown(secondsRemaining: Int) {
        val mins = secondsRemaining / 60
        val secs = secondsRemaining % 60
        val timeStr = String.format("%02d:%02d", mins, secs)
        countdownText?.text = "专注中 $timeStr"
    }

    override fun onDestroy() {
        super.onDestroy()
        hideLockScreen()
    }
}
