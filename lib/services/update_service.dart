import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';

class UpdateInfo {
  final bool isUpdateAvailable;
  final bool isForceUpdate;
  final int latestVersionCode;
  final String latestVersionName;
  final String title;
  final String releaseNotes;
  final String downloadUrl;

  UpdateInfo({
    required this.isUpdateAvailable,
    required this.isForceUpdate,
    required this.latestVersionCode,
    required this.latestVersionName,
    required this.title,
    required this.releaseNotes,
    required this.downloadUrl,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> rawJson) {
    final json = (rawJson['data'] is Map<String, dynamic>)
        ? (rawJson['data'] as Map<String, dynamic>)
        : rawJson;

    return UpdateInfo(
      isUpdateAvailable: json['is_update_available'] == true,
      isForceUpdate: json['is_force_update'] == true,
      latestVersionCode: int.tryParse('${json['latest_version_code']}') ?? 0,
      latestVersionName: json['latest_version_name']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Pembaruan Tersedia',
      releaseNotes: json['release_notes']?.toString() ?? '',
      downloadUrl: json['download_url']?.toString() ?? '',
    );
  }
}

class UpdateService {
  static const String checkVersionUrl = 'http://192.168.10.55/sto/check-version';

  /// Versi aplikasi saat ini (sesuai versionCode di build.gradle / pubspec.yaml)
  static const int currentVersionCode = 5;
  static const String currentVersionName = '1.0.4';

  /// Cek versi aplikasi ke backend server
  static Future<UpdateInfo?> checkUpdate() async {
    if (!Platform.isAndroid) {
      return null; // OTA update saat ini dikhususkan untuk Android APK
    }

    try {
      final uri = Uri.parse(
        '$checkVersionUrl?version_code=$currentVersionCode&app_name=emanifest&platform=android',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true) {
          return UpdateInfo.fromJson(data);
        }
      }
    } catch (e) {
      debugPrint('[UpdateService] Check update error: $e');
    }
    return null;
  }

  /// Cek dan munculkan dialog otomatis jika ada pembaruan
  static Future<void> checkAndPromptUpdate(BuildContext context) async {
    final updateInfo = await checkUpdate();
    if (updateInfo != null && updateInfo.isUpdateAvailable) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: !updateInfo.isForceUpdate,
        builder: (ctx) => UpdateDialog(updateInfo: updateInfo),
      );
    }
  }
}

class UpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;

  const UpdateDialog({super.key, required this.updateInfo});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  int _downloadProgress = 0;
  String _statusText = '';
  String? _errorMessage;
  StreamSubscription<OtaEvent>? _otaSubscription;

  static const MethodChannel _downloaderChannel = MethodChannel('com.example.emanifest/apk_downloader');
  static const EventChannel _progressEventChannel = EventChannel('com.example.emanifest/apk_download_progress');
  StreamSubscription? _nativeProgressSub;

  @override
  void dispose() {
    _otaSubscription?.cancel();
    _nativeProgressSub?.cancel();
    super.dispose();
  }

  Future<void> _startOtaUpdate() async {
    await _otaSubscription?.cancel();
    _otaSubscription = null;
    await _nativeProgressSub?.cancel();
    _nativeProgressSub = null;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
      _errorMessage = null;
      _statusText = 'Mempersiapkan unduhan...';
    });

    try {
      // Dengarkan streaming progress dari Android DownloadManager native
      _nativeProgressSub = _progressEventChannel.receiveBroadcastStream().listen(
        (dynamic event) {
          if (!mounted) return;
          if (event is Map) {
            final status = event['status']?.toString();
            final progress = (event['progress'] as num?)?.toInt() ?? 0;

            if (status == 'DOWNLOADING') {
              setState(() {
                _downloadProgress = progress;
                _statusText = 'Mengunduh pembaruan: $progress%';
              });
            } else if (status == 'INSTALLING' || status == 'SUCCESS') {
              setState(() {
                _downloadProgress = 100;
                _statusText = 'Membuka pemasang aplikasi (installer)...';
                _isDownloading = false;
              });
            }
          }
        },
        onError: (err) {
          debugPrint('[NativeDownloader] stream error: $err');
          _fallbackOtaUpdate();
        },
      );

      // Jalankan download menggunakan Android DownloadManager resmi OS
      await _downloaderChannel.invokeMethod('startDownloadAndInstall', {
        'url': widget.updateInfo.downloadUrl,
        'fileName': 'emanifest_update_${widget.updateInfo.latestVersionCode}.apk',
      });
    } catch (e) {
      debugPrint('[NativeDownloader] invocation failed, trying ota_update fallback: $e');
      _fallbackOtaUpdate();
    }
  }

  Future<void> _fallbackOtaUpdate() async {
    try {
      const authority = 'com.example.emanifest.v2.ota_update_provider';

      _otaSubscription = OtaUpdate()
          .execute(
            widget.updateInfo.downloadUrl,
            androidProviderAuthority: authority,
            destinationFilename: 'emanifest_update.apk',
          )
          .listen(
        (OtaEvent event) {
          if (!mounted) return;
          switch (event.status) {
            case OtaStatus.DOWNLOADING:
              final progress = int.tryParse(event.value ?? '0') ?? 0;
              setState(() {
                _downloadProgress = progress;
                _statusText = 'Mengunduh pembaruan: $progress%';
              });
              break;
            case OtaStatus.INSTALLING:
              setState(() {
                _downloadProgress = 100;
                _statusText = 'Membuka pemasang aplikasi (installer)...';
              });
              break;
            case OtaStatus.INSTALLATION_DONE:
              setState(() {
                _isDownloading = false;
                _statusText = 'Pemasangan berhasil.';
              });
              break;
            case OtaStatus.ALREADY_RUNNING_ERROR:
              setState(() {
                _isDownloading = false;
                _errorMessage = 'Proses unduhan sudah berjalan.';
              });
              break;
            case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
              setState(() {
                _isDownloading = false;
                _errorMessage = 'Izin penyimpanan atau pemasangan dari sumber tidak dikenal belum diaktifkan.';
              });
              break;
            case OtaStatus.INTERNAL_ERROR:
            case OtaStatus.DOWNLOAD_ERROR:
            case OtaStatus.CHECKSUM_ERROR:
            case OtaStatus.INSTALLATION_ERROR:
            default:
              final detail = (event.value != null && event.value!.isNotEmpty) ? ' (${event.value})' : '';
              setState(() {
                _isDownloading = false;
                _errorMessage = 'Gagal mengunduh otomatis (${event.status.name})$detail. Anda dapat mencoba lagi atau mengunduh langsung via browser.';
              });
              break;
          }
        },
        onError: (err) {
          if (!mounted) return;
          setState(() {
            _isDownloading = false;
            _errorMessage = 'Kesalahan saat unduh: $err';
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _errorMessage = 'Gagal mengunduh: $e';
      });
    }
  }

  static const MethodChannel _browserChannel = MethodChannel('com.example.emanifest/browser');

  Future<void> _openInBrowser() async {
    try {
      final success = await _browserChannel.invokeMethod<bool>('openUrl', {
        'url': widget.updateInfo.downloadUrl,
      });
      if (success != true) {
        _copyDownloadLink();
      }
    } catch (e) {
      debugPrint('[UpdateService] Error opening browser: $e');
      _copyDownloadLink();
    }
  }

  void _copyDownloadLink() {
    Clipboard.setData(ClipboardData(text: widget.updateInfo.downloadUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link unduhan disalin ke clipboard.'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.updateInfo;

    return PopScope(
      canPop: !info.isForceUpdate && !_isDownloading,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: info.isForceUpdate ? Colors.red.shade50 : Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                info.isForceUpdate ? Icons.warning_amber_rounded : Icons.system_update,
                color: info.isForceUpdate ? Colors.red.shade700 : const Color(0xFF0D47A1),
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.isForceUpdate ? 'Pembaruan Wajib' : 'Pembaruan Tersedia',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Versi ${info.latestVersionName} (Build ${info.latestVersionCode})',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (info.isForceUpdate) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber.shade900, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Anda wajib memperbarui aplikasi ini untuk melanjutkan penggunaan.',
                        style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            const Text(
              'Catatan Pembaruan:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                info.releaseNotes.isNotEmpty
                    ? info.releaseNotes
                    : 'Peningkatan performa dan perbaikan bug.',
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),
            if (_isDownloading) ...[
              LinearProgressIndicator(
                value: _downloadProgress > 0 ? _downloadProgress / 100.0 : null,
                backgroundColor: Colors.grey.shade300,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0D47A1)),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _statusText,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
            ],
          ],
        ),
        actions: [
          if (!info.isForceUpdate && !_isDownloading)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Nanti Saja'),
            ),
          if (_errorMessage != null) ...[
            TextButton.icon(
              onPressed: _openInBrowser,
              icon: const Icon(Icons.open_in_browser, size: 18),
              label: const Text('Unduh via Browser'),
            ),
            IconButton(
              onPressed: _copyDownloadLink,
              icon: const Icon(Icons.copy, size: 18),
              tooltip: 'Salin Link Unduhan',
            ),
          ],
          if (!_isDownloading)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D47A1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _startOtaUpdate,
              icon: const Icon(Icons.download, size: 18),
              label: Text(_errorMessage != null ? 'Coba Lagi' : 'Perbarui Sekarang'),
            ),
        ],
      ),
    );
  }
}
