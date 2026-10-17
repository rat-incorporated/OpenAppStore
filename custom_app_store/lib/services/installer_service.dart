import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/app_release.dart';

/// Downloads APK files and asks the Android side to launch the package
/// installer. The native side lives in MainActivity.kt.
class InstallerService {
  static const _channel = MethodChannel('customstore/installer');

  /// Download [release] into the app cache directory.
  ///
  /// [onProgress] receives a value between 0 and 1 (or null when the server
  /// does not report a content length).
  Future<File> download(
    AppRelease release, {
    void Function(double? progress)? onProgress,
  }) async {
    final uri = Uri.parse(release.url);
    final fileName = _fileNameFor(release);
    final dir = await getTemporaryDirectory();
    final target = File('${dir.path}${Platform.pathSeparator}$fileName');
    if (await target.exists()) {
      await target.delete();
    }

    final client = http.Client();
    try {
      final request = http.Request('GET', uri);
      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw Exception('Download failed (HTTP ${response.statusCode})');
      }
      final total = response.contentLength ?? (release.size > 0 ? release.size : null);
      var received = 0;
      final sink = target.openWrite();
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (onProgress != null) {
            onProgress(total == null ? null : (received / total).clamp(0.0, 1.0));
          }
        }
      } finally {
        await sink.flush();
        await sink.close();
      }
      onProgress?.call(1);
      return target;
    } finally {
      client.close();
    }
  }

  /// Hand a downloaded APK to the system installer.
  Future<bool> installApk(File apk) async {
    final result = await _channel.invokeMethod<bool>('installApk', {
      'path': apk.path,
      'mime': 'application/vnd.android.package-archive',
    });
    return result ?? false;
  }

  String _fileNameFor(AppRelease release) {
    final safeVersion = release.versionName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final fromUrl = Uri.tryParse(release.url)?.pathSegments.isNotEmpty == true
        ? Uri.parse(release.url).pathSegments.last
        : '';
    if (fromUrl.toLowerCase().endsWith('.apk')) return fromUrl;
    return 'download-${safeVersion.isEmpty ? 'latest' : safeVersion}.apk';
  }
}
