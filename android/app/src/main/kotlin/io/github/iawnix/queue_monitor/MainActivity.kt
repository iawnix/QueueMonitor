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
    private var pendingSaveResult: MethodChannel.Result? = null
    private var pendingSaveText: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CONFIG_FILE_PICKER_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickJsonText" -> pickJsonText(result)
                "saveJsonText" -> {
                    val fileName = call.argument<String>("file_name") ?: "queue_monitor_config.json"
                    val text = call.argument<String>("text")
                    if (text == null) {
                        result.error("INVALID_ARGUMENT", "Missing JSON text to export.", null)
                    } else {
                        saveJsonText(fileName, text, result)
                    }
                }
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

    private fun saveJsonText(fileName: String, text: String, result: MethodChannel.Result) {
        if (pendingSaveResult != null || pendingPickResult != null) {
            result.error("BUSY", "A config file operation is already open.", null)
            return
        }

        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/json"
            putExtra(Intent.EXTRA_TITLE, fileName)
            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        }

        pendingSaveResult = result
        pendingSaveText = text
        try {
            @Suppress("DEPRECATION")
            startActivityForResult(intent, REQUEST_CONFIG_SAVE)
        } catch (error: ActivityNotFoundException) {
            pendingSaveResult = null
            pendingSaveText = null
            result.error("NO_FILE_PICKER", "No file export target is available on this device.", null)
        }
    }

    @Deprecated("Deprecated in Android framework; kept for FlutterActivity compatibility.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            REQUEST_CONFIG_FILE -> finishPickJsonText(resultCode, data)
            REQUEST_CONFIG_SAVE -> finishSaveJsonText(resultCode, data)
        }
    }

    private fun finishPickJsonText(resultCode: Int, data: Intent?) {
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

    private fun finishSaveJsonText(resultCode: Int, data: Intent?) {
        val result = pendingSaveResult ?: return
        val text = pendingSaveText
        pendingSaveResult = null
        pendingSaveText = null

        if (resultCode != Activity.RESULT_OK) {
            result.success(false)
            return
        }

        val uri = data?.data
        if (uri == null || text == null) {
            result.success(false)
            return
        }

        try {
            writeText(uri, text)
            result.success(true)
        } catch (error: Exception) {
            result.error("WRITE_FAILED", error.message ?: "Failed to write config file.", null)
        }
    }

    private fun readText(uri: Uri): String {
        val stream = contentResolver.openInputStream(uri)
            ?: throw IllegalArgumentException("Selected file cannot be opened.")
        return stream.bufferedReader(Charsets.UTF_8).use { it.readText() }
    }

    private fun writeText(uri: Uri, text: String) {
        val stream = contentResolver.openOutputStream(uri)
            ?: throw IllegalArgumentException("Selected file cannot be opened for writing.")
        stream.bufferedWriter(Charsets.UTF_8).use { it.write(text) }
    }

    companion object {
        private const val CONFIG_FILE_PICKER_CHANNEL = "queue_monitor/config_file_picker"
        private const val REQUEST_CONFIG_FILE = 9210
        private const val REQUEST_CONFIG_SAVE = 9211
    }
}
