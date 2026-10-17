package com.example.custom_app_store

import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Hosts the "customstore/installer" method channel. The Dart side downloads an
 * APK into the app cache and then asks us to open the system package installer
 * for it, which is only possible from the Android layer.
 */
class MainActivity : FlutterActivity() {

    private val channelName = "customstore/installer"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "installApk" -> handleInstall(call.argument("path"), call.argument("mime"), result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun handleInstall(path: String?, mime: String?, result: MethodChannel.Result) {
        if (path.isNullOrEmpty()) {
            result.error("no_path", "No APK path was provided.", null)
            return
        }
        val file = File(path)
        if (!file.exists()) {
            result.error("missing", "The APK could not be found at $path", null)
            return
        }
        try {
            val uri: Uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, mime ?: "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            result.success(true)
        } catch (error: Exception) {
            result.error("install_failed", error.message, null)
        }
    }
}
