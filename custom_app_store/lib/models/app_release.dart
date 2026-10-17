import '../util/json_utils.dart';

/// A single downloadable build of an app.
class AppRelease {
  const AppRelease({
    this.versionName = '',
    this.versionCode = 0,
    this.channel = 'stable',
    this.url = '',
    this.size = 0,
    this.sha256 = '',
    this.minSdkVersion = 0,
    this.targetSdkVersion = 0,
    this.added = '',
    this.changelog = '',
  });

  final String versionName;
  final int versionCode;
  final String channel;
  final String url;
  final int size;
  final String sha256;
  final int minSdkVersion;
  final int targetSdkVersion;
  final String added;
  final String changelog;

  factory AppRelease.fromJson(Map<String, dynamic> json) {
    return AppRelease(
      versionName: asString(json['versionName']),
      versionCode: asInt(json['versionCode']),
      channel: asString(json['channel'], 'stable'),
      url: asString(json['url']),
      size: asInt(json['size']),
      sha256: asString(json['sha256']),
      minSdkVersion: asInt(json['minSdkVersion']),
      targetSdkVersion: asInt(json['targetSdkVersion']),
      added: asString(json['added']),
      changelog: asString(json['changelog']),
    );
  }

  Map<String, dynamic> toJson() => {
        'versionName': versionName,
        'versionCode': versionCode,
        'channel': channel,
        'url': url,
        'size': size,
        'sha256': sha256,
        'minSdkVersion': minSdkVersion,
        'targetSdkVersion': targetSdkVersion,
        'added': added,
        'changelog': changelog,
      };
}
