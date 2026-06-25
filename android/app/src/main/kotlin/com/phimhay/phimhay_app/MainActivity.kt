package com.phimhay.phimhay_app

import android.app.PictureInPictureParams
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import android.util.Rational
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL_PIP = "phimhay/pip"
    private val CHANNEL_INSTALL = "phimhay/install_apk"
    private var pipChannel: MethodChannel? = null
    private var installChannel: MethodChannel? = null
    private var pipPosition: Double = 0.0

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        pipChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_PIP)
        pipChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isPipAvailable" -> {
                    result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                }
                "setupPip" -> {
                    result.success(true)
                }
                "startPip" -> {
                    pipPosition = (call.argument<Number>("position") ?: 0).toDouble()
                    try {
                        val params = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            PictureInPictureParams.Builder()
                                .setAspectRatio(Rational(16, 9))
                                .build()
                        } else {
                            null
                        }
                        if (params != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            if (isInPictureInPictureMode) {
                                result.success(true)
                            } else {
                                enterPictureInPictureMode(params)
                                result.success(true)
                            }
                        } else {
                            result.error("UNSUPPORTED", "PiP not supported", null)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "isPipActive" -> {
                    result.success(isInPictureInPictureMode)
                }
                "stopPip" -> {
                    result.success(true)
                }
                "getPipPosition" -> {
                    result.success(pipPosition)
                }
                else -> result.notImplemented()
            }
        }

        // Install APK channel
        installChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_INSTALL)
        installChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrEmpty()) {
                        result.error("INVALID_PATH", "APK path is empty", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val file = File(path)
                        if (!file.exists()) {
                            result.error("FILE_NOT_FOUND", "APK file not found: $path", null)
                            return@setMethodCallHandler
                        }
                        installApk(file)
                        result.success("ok")
                    } catch (e: SecurityException) {
                        result.error("NEED_PERMISSION", e.message, null)
                    } catch (e: Exception) {
                        result.error("INSTALL_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun installApk(file: File) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            if (!packageManager.canRequestPackageInstalls()) {
                // Mở settings để user cấp quyền
                val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                    data = Uri.parse("package:$packageName")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                throw SecurityException("NEED_PERMISSION")
            }
        }

        val uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            FileProvider.getUriForFile(this, "${packageName}.fileprovider", file)
        } else {
            Uri.fromFile(file)
        }

        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(intent)
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode)
        if (isInPictureInPictureMode) {
            pipChannel?.invokeMethod("onPipStarted", null)
        }
    }
}
