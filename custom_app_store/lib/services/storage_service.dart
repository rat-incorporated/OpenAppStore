import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/source.dart';

/// Persists the user's sources and the apps they installed through the store.
class StorageService {
  static const _sourcesKey = 'store.sources.v1';
  static const _installedKey = 'store.installed.v1';

  Future<List<StoreSource>> loadSources() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sourcesKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => StoreSource.fromJson(Map<String, dynamic>.from(e)))
          .where((s) => s.url.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveSources(List<StoreSource> sources) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(sources.map((s) => s.toJson()).toList());
    await prefs.setString(_sourcesKey, encoded);
  }

  /// package id -> version code that was last installed through the store.
  Future<Map<String, int>> loadInstalled() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_installedKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map((key, value) => MapEntry(key.toString(), value is num ? value.toInt() : 0));
    } catch (_) {
      return {};
    }
  }

  Future<void> saveInstalled(Map<String, int> installed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_installedKey, jsonEncode(installed));
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sourcesKey);
    await prefs.remove(_installedKey);
  }
}
