package app.local.lan_transfer_clipboard

import android.content.Context
import android.content.ContentValues
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.webkit.MimeTypeMap
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val filesChannelName = "app.local.lan_transfer_clipboard/files"
    private val platformChannelName = "app.local.lan_transfer_clipboard/platform"
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, filesChannelName)
            .setMethodCallHandler { call, result ->
                if (call.method != "saveToDownloads") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val sourcePath = call.argument<String>("sourcePath")
                val fileName = call.argument<String>("fileName")
                val relativePath = call.argument<String>("relativePath") ?: "Download/LAN Transfer"
                if (sourcePath.isNullOrBlank() || fileName.isNullOrBlank()) {
                    result.error("invalid_args", "sourcePath and fileName are required", null)
                    return@setMethodCallHandler
                }

                try {
                    result.success(saveToDownloads(sourcePath, fileName, relativePath))
                } catch (error: Exception) {
                    result.error("save_failed", error.message, null)
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, platformChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getDeviceName" -> result.success(deviceName())
                    "getWifiIpv4Address" -> result.success(wifiIpv4Address())
                    else -> result.notImplemented()
                }
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
        multicastLock = wifiManager?.createMulticastLock("lan_transfer_discovery")?.apply {
            setReferenceCounted(false)
            acquire()
        }
    }

    override fun onDestroy() {
        multicastLock?.let {
            if (it.isHeld) {
                it.release()
            }
        }
        multicastLock = null
        super.onDestroy()
    }

    private fun saveToDownloads(
        sourcePath: String,
        fileName: String,
        relativePath: String,
    ): Map<String, String> {
        val sourceFile = File(sourcePath)
        if (!sourceFile.exists()) {
            throw IllegalArgumentException("Source file does not exist")
        }

        val downloadsFolder = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
            "LAN Transfer",
        )
        val displayName = uniqueFileName(downloadsFolder, fileName)
        val publicPath = File(downloadsFolder, displayName).absolutePath

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
                put(MediaStore.MediaColumns.MIME_TYPE, mimeTypeFor(displayName))
                put(MediaStore.MediaColumns.RELATIVE_PATH, normalizedRelativePath(relativePath))
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }

            val resolver = applicationContext.contentResolver
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("Unable to create download entry")

            try {
                resolver.openOutputStream(uri)?.use { output ->
                    FileInputStream(sourceFile).use { input ->
                        input.copyTo(output)
                    }
                } ?: throw IllegalStateException("Unable to open download output stream")

                values.clear()
                values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
                return mapOf(
                    "path" to publicPath,
                    "uri" to uri.toString(),
                    "name" to displayName,
                )
            } catch (error: Exception) {
                resolver.delete(uri, null, null)
                throw error
            }
        }

        downloadsFolder.mkdirs()
        val destination = File(downloadsFolder, displayName)
        FileInputStream(sourceFile).use { input ->
            FileOutputStream(destination).use { output ->
                input.copyTo(output)
            }
        }
        return mapOf(
            "path" to destination.absolutePath,
            "uri" to destination.toURI().toString(),
            "name" to displayName,
        )
    }

    private fun normalizedRelativePath(relativePath: String): String {
        return relativePath.trim('/').ifBlank { "Download/LAN Transfer" } + "/"
    }

    private fun uniqueFileName(folder: File, fileName: String): String {
        val cleanName = fileName.ifBlank { "received-file" }
        val dotIndex = cleanName.lastIndexOf('.')
        val base = if (dotIndex > 0) cleanName.substring(0, dotIndex) else cleanName
        val extension = if (dotIndex > 0) cleanName.substring(dotIndex) else ""
        var candidate = cleanName
        var index = 1
        while (File(folder, candidate).exists()) {
            candidate = "$base ($index)$extension"
            index += 1
        }
        return candidate
    }

    private fun mimeTypeFor(fileName: String): String {
        val extension = fileName.substringAfterLast('.', "").lowercase()
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension)
            ?: "application/octet-stream"
    }

    private fun deviceName(): String {
        val manufacturer = Build.MANUFACTURER?.trim().orEmpty()
        val model = Build.MODEL?.trim().orEmpty()
        val name = when {
            manufacturer.isBlank() && model.isBlank() -> "Android device"
            manufacturer.isBlank() -> model
            model.startsWith(manufacturer, ignoreCase = true) -> model
            else -> "$manufacturer $model"
        }
        return name.replaceFirstChar {
            if (it.isLowerCase()) it.titlecase(Locale.getDefault()) else it.toString()
        }
    }

    private fun wifiIpv4Address(): String? {
        val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
        val rawAddress = wifiManager?.connectionInfo?.ipAddress ?: return null
        if (rawAddress == 0) {
            return null
        }

        return listOf(
            rawAddress and 0xff,
            rawAddress shr 8 and 0xff,
            rawAddress shr 16 and 0xff,
            rawAddress shr 24 and 0xff,
        ).joinToString(".")
    }
}
