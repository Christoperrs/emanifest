package com.example.emanifest

import android.app.DownloadManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.os.Environment
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterActivity() {
    private val BROWSER_CHANNEL = "com.example.emanifest/browser"
    private val DOWNLOAD_CHANNEL = "com.example.emanifest/apk_downloader"
    private val PROGRESS_CHANNEL = "com.example.emanifest/apk_download_progress"

    private var downloadId: Long = -1L
    private var downloadReceiver: BroadcastReceiver? = null
    private var progressSink: EventChannel.EventSink? = null
    private var progressThread: Thread? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Channel untuk membuka browser jika diperlukan
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BROWSER_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "openUrl") {
                val url = call.argument<String>("url")
                if (url != null) {
                    try {
                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("OPEN_FAILED", e.message, null)
                    }
                } else {
                    result.error("INVALID_URL", "URL is null", null)
                }
            } else {
                result.notImplemented()
            }
        }

        // Event Channel untuk streaming persentase download
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, PROGRESS_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    progressSink = events
                }

                override fun onCancel(arguments: Any?) {
                    progressSink = null
                }
            }
        )

        // Method Channel untuk download & install via Android DownloadManager resmi
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DOWNLOAD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startDownloadAndInstall" -> {
                    val url = call.argument<String>("url")
                    val fileName = call.argument<String>("fileName") ?: "emanifest_update.apk"
                    if (url != null) {
                        startSystemDownload(url, fileName, result)
                    } else {
                        result.error("INVALID_URL", "URL tidak boleh kosong", null)
                    }
                }
                "cancelDownload" -> {
                    cancelCurrentDownload()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun cancelCurrentDownload() {
        if (downloadId != -1L) {
            val dm = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
            dm.remove(downloadId)
            downloadId = -1L
        }
        progressThread?.interrupt()
        progressThread = null
    }

    private fun startSystemDownload(url: String, fileName: String, result: MethodChannel.Result) {
        try {
            cancelCurrentDownload()

            // Siapkan file tujuan di folder public Downloads
            val destinationFile = File(
                getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS),
                fileName
            )
            if (destinationFile.exists()) {
                destinationFile.delete()
            }

            val request = DownloadManager.Request(Uri.parse(url)).apply {
                setTitle("Mengunduh Update E-Manifest")
                setDescription("Mengunduh versi terbaru aplikasi...")
                setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
                setDestinationUri(Uri.fromFile(destinationFile))
                setAllowedOverMetered(true)
                setAllowedOverRoaming(true)
            }

            val dm = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
            downloadId = dm.enqueue(request)

            // Register broadcast receiver untuk mendeteksi saat download selesai
            unregisterDownloadReceiver()
            downloadReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    val id = intent?.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1L) ?: -1L
                    if (id == downloadId && id != -1L) {
                        installDownloadedApk(destinationFile)
                        progressSink?.success(mapOf("status" to "INSTALLING", "progress" to 100))
                    }
                }
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(downloadReceiver, IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE), RECEIVER_EXPORTED)
            } else {
                registerReceiver(downloadReceiver, IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE))
            }

            // Thread untuk memantau progress unduhan
            progressThread = Thread {
                var isDownloading = true
                while (isDownloading && !Thread.currentThread().isInterrupted) {
                    val query = DownloadManager.Query().setFilterById(downloadId)
                    val cursor = dm.query(query)
                    if (cursor != null && cursor.moveToFirst()) {
                        val bytesDownloaded = cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR))
                        val bytesTotal = cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES))
                        val status = cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))

                        if (status == DownloadManager.STATUS_SUCCESSFUL) {
                            isDownloading = false
                            runOnUiThread {
                                progressSink?.success(mapOf("status" to "SUCCESS", "progress" to 100))
                            }
                        } else if (status == DownloadManager.STATUS_FAILED) {
                            val reason = cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON))
                            isDownloading = false
                            runOnUiThread {
                                progressSink?.error("DOWNLOAD_FAILED", "Download gagal dengan kode alasan: $reason", null)
                            }
                        } else if (bytesTotal > 0) {
                            val progress = ((bytesDownloaded * 100L) / bytesTotal).toInt()
                            runOnUiThread {
                                progressSink?.success(mapOf("status" to "DOWNLOADING", "progress" to progress))
                            }
                        }
                        cursor.close()
                    }
                    try {
                        Thread.sleep(500)
                    } catch (e: InterruptedException) {
                        break
                    }
                }
            }
            progressThread?.start()

            result.success(true)
        } catch (e: Exception) {
            result.error("ERROR", e.message, null)
        }
    }

    private fun installDownloadedApk(file: File) {
        try {
            if (!file.exists()) return

            val authority = "${applicationContext.packageName}.fileprovider"
            val apkUri = FileProvider.getUriForFile(this, authority, file)

            val installIntent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(apkUri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(installIntent)
        } catch (e: Exception) {
            runOnUiThread {
                progressSink?.error("INSTALL_ERROR", "Gagal membuka installer: ${e.message}", null)
            }
        }
    }

    private fun unregisterDownloadReceiver() {
        if (downloadReceiver != null) {
            try {
                unregisterReceiver(downloadReceiver)
            } catch (_: Exception) {}
            downloadReceiver = null
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        unregisterDownloadReceiver()
        cancelCurrentDownload()
    }
}
