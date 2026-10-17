import 'app_release.dart';
import '../util/json_utils.dart';

/// A single application listed in a repository index, enriched with the
/// repository it came from.
class StoreApp {
  StoreApp({
    required this.id,
    required this.name,
    this.summary = '',
    this.description = '',
    this.developer = '',
    this.license = '',
    this.icon = '',
    this.categories = const [],
    this.tags = const [],
    this.screenshots = const [],
    this.homepage = '',
    this.sourceCode = '',
    this.issueTracker = '',
    this.donate = '',
    this.releases = const [],
    this.sourceId = '',
    this.sourceName = '',
  });

  final String id;
  final String name;
  final String summary;
  final String description;
  final String developer;
  final String license;
  final String icon;
  final List<String> categories;
  final List<String> tags;
  final List<String> screenshots;
  final String homepage;
  final String sourceCode;
  final String issueTracker;
  final String donate;
  final List<AppRelease> releases;

  /// Id and name of the repository this app was loaded from.
  final String sourceId;
  final String sourceName;

  factory StoreApp.fromJson(
    Map<String, dynamic> json, {
    String sourceId = '',
    String sourceName = '',
  }) {
    final releases = (json['releases'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => AppRelease.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => b.versionCode.compareTo(a.versionCode));

    return StoreApp(
      id: asString(json['id']),
      name: asString(json['name']),
      summary: asString(json['summary']),
      description: asString(json['description']),
      developer: asString(json['developer']),
      license: asString(json['license']),
      icon: asString(json['icon']),
      categories: asStringList(json['categories']),
      tags: asStringList(json['tags']),
      screenshots: asStringList(json['screenshots']),
      homepage: asString(json['homepage']),
      sourceCode: asString(json['sourceCode']),
      issueTracker: asString(json['issueTracker']),
      donate: asString(json['donate']),
      releases: releases,
      sourceId: sourceId,
      sourceName: sourceName,
    );
  }

  /// The build with the highest version code, or null when the app lists none.
  AppRelease? get latest => releases.isEmpty ? null : releases.first;

  String get latestVersionName => latest?.versionName ?? '';

  String get primaryCategory => categories.isEmpty ? 'Other' : categories.first;

  /// A stable-ish key used for progress tracking across repositories.
  String get key => '$sourceId::$id';

  StoreApp copyWith({String? sourceId, String? sourceName}) => StoreApp(
        id: id,
        name: name,
        summary: summary,
        description: description,
        developer: developer,
        license: license,
        icon: icon,
        categories: categories,
        tags: tags,
        screenshots: screenshots,
        homepage: homepage,
        sourceCode: sourceCode,
        issueTracker: issueTracker,
        donate: donate,
        releases: releases,
        sourceId: sourceId ?? this.sourceId,
        sourceName: sourceName ?? this.sourceName,
      );
}
