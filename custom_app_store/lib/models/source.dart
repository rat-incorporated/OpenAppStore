import '../util/json_utils.dart';

/// A repository the user has added. Mirrors F-Droid: nothing is installed by
/// default, the user adds the index URLs they trust.
class StoreSource {
  StoreSource({
    required this.id,
    required this.name,
    required this.url,
    this.enabled = true,
  });

  final String id;
  final String name;
  final String url;
  final bool enabled;

  /// Build a source from a user supplied URL. The id is derived from the URL
  /// so re-adding the same index produces the same identity.
  factory StoreSource.fromUrl(String rawUrl, {String? name}) {
    final url = normalizeIndexUrl(rawUrl);
    return StoreSource(
      id: stableHash(url),
      name: (name == null || name.trim().isEmpty) ? _guessName(url) : name.trim(),
      url: url,
    );
  }

  factory StoreSource.fromJson(Map<String, dynamic> json) => StoreSource(
        id: asString(json['id']),
        name: asString(json['name']),
        url: asString(json['url']),
        enabled: json['enabled'] is bool ? json['enabled'] as bool : true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'enabled': enabled,
      };

  StoreSource copyWith({String? name, String? url, bool? enabled}) => StoreSource(
        id: id,
        name: name ?? this.name,
        url: url ?? this.url,
        enabled: enabled ?? this.enabled,
      );

  static String _guessName(String url) {
    final host = Uri.tryParse(url)?.host ?? url;
    return host.isEmpty ? url : host;
  }
}

/// Accept a bare host, a folder, or a full index URL and return a URL that
/// points at a JSON document.
///
/// Examples:
///   example.com              -> https://example.com/repo.json
///   example.com/store/       -> https://example.com/store/repo.json
///   example.com/index.json   -> https://example.com/index.json
String normalizeIndexUrl(String raw) {
  var value = raw.trim();
  if (value.isEmpty) return value;
  if (!value.contains('://')) {
    value = 'https://$value';
  }
  final uri = Uri.parse(value);
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty) {
    return uri.replace(path: '/repo.json').toString();
  }
  final last = segments.last;
  if (last.contains('.')) {
    return uri.toString();
  }
  final path = '${uri.path.endsWith('/') ? uri.path : '${uri.path}/'}repo.json';
  return uri.replace(path: path).toString();
}
