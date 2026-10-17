import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/source.dart';
import '../models/store_app.dart';
import '../util/json_utils.dart';

/// Raised when a repository index cannot be fetched or parsed.
class RepoException implements Exception {
  RepoException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Downloads and parses repository indexes.
class RepoService {
  RepoService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const Duration _timeout = Duration(seconds: 30);

  /// Fetch and parse one repository. Throws [RepoException] on any failure.
  Future<List<StoreApp>> fetch(StoreSource source, {String? displayName}) async {
    final uri = Uri.parse(source.url);
    http.Response response;
    try {
      response = await _client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(_timeout);
    } on TimeoutException {
      throw RepoException('Timed out while contacting ${uri.host}');
    } catch (error) {
      throw RepoException('Could not reach ${uri.host}: $error');
    }

    if (response.statusCode != 200) {
      throw RepoException('${uri.host} returned HTTP ${response.statusCode}');
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw RepoException('The index at ${uri.host} is not valid JSON');
    }

    final List<dynamic> rawApps;
    var repoName = displayName ?? source.name;
    if (decoded is List) {
      rawApps = decoded;
    } else if (decoded is Map) {
      rawApps = decoded['apps'] as List? ?? const [];
      final declared = asString(decoded['name']);
      if (declared.isNotEmpty && (displayName == null || displayName.isEmpty)) {
        repoName = declared;
      }
    } else {
      throw RepoException('Unrecognised index format from ${uri.host}');
    }

    final apps = <StoreApp>[];
    for (final entry in rawApps) {
      if (entry is! Map) continue;
      final app = StoreApp.fromJson(
        Map<String, dynamic>.from(entry),
        sourceId: source.id,
        sourceName: repoName,
      );
      if (app.id.isEmpty || app.name.isEmpty) continue;
      apps.add(app);
    }
    return apps;
  }

  void dispose() => _client.close();
}

/// Best-effort metadata about a repository, shown before it is added.
class RepoInfo {
  RepoInfo({required this.name, required this.appCount, required this.description});
  final String name;
  final int appCount;
  final String description;
}
