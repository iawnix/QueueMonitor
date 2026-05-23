package io.github.iawnix.queue_monitor

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingPickResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CONFIG_FILE_PICKER_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickJsonText" -> pickJsonText(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun pickJsonText(result: MethodChannel.Result) {
        if (pendingPickResult != null) {
            result.error("BUSY", "A config file picker is already open.", null)
            return
        }

        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(
                Intent.EXTRA_MIME_TYPES,
                arrayOf("application/json", "text/json", "text/plain", "application/octet-stream"),
            )
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        pendingPickResult = result
        try {
            @Suppress("DEPRECATION")
            startActivityForResult(intent, REQUEST_CONFIG_FILE)
        } catch (error: ActivityNotFoundException) {
            pendingPickResult = null
            result.error("NO_FILE_PICKER", "No file picker is available on this device.", null)
        }
    }

    @Deprecated("Deprecated in Android framework; kept for FlutterActivity compatibility.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_CONFIG_FILE) {
            return
        }

        val result = pendingPickResult ?: return
        pendingPickResult = null

        if (resultCode != Activity.RESULT_OK) {
            result.success(null)
            return
        }

        val uri = data?.data
        if (uri == null) {
            result.success(null)
            return
        }

        try {
            result.success(readText(uri))
        } catch (error: Exception) {
            result.error("READ_FAILED", error.message ?: "Failed to read selected config file.", null)
        }
    }

    private fun readText(uri: Uri): String {
        val stream = contentResolver.openInputStream(uri)
            ?: throw IllegalArgumentException("Selected file cannot be opened.")
        return stream.bufferedReader(Charsets.UTF_8).use { it.readText() }
    }

    companion object {
        private const val CONFIG_FILE_PICKER_CHANNEL = "queue_monitor/config_file_picker"
        private const val REQUEST_CONFIG_FILE = 9210
    }
}
