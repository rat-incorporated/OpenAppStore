import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/source.dart';
import '../models/store_app.dart';
import '../services/installer_service.dart';
import '../services/repo_service.dart';
import '../services/storage_service.dart';

/// Central application state: the list of sources, the apps aggregated from
/// them, and the install/update bookkeeping.
class StoreState extends ChangeNotifier {
  StoreState({
    StorageService? storage,
    RepoService? repos,
    InstallerService? installer,
  })  : _storage = storage ?? StorageService(),
        _repos = repos ?? RepoService(),
        _installer = installer ?? InstallerService();

  final StorageService _storage;
  final RepoService _repos;
  final InstallerService _installer;

  List<StoreSource> _sources = [];
  final Map<String, List<StoreApp>> _appsBySource = {};
  final Map<String, String> _sourceErrors = {};
  Map<String, int> _installed = {};
  final Map<String, double> _progress = {};
  final Map<String, String> _installErrors = {};

  bool _refreshing = false;
  bool _ready = false;

  // -- getters ----------------------------------------------------------- //

  List<StoreSource> get sources => List.unmodifiable(_sources);
  bool get refreshing => _refreshing;
  bool get ready => _ready;
  bool get hasSources => _sources.any((s) => s.enabled);
  Map<String, int> get installed => Map.unmodifiable(_installed);

  String? errorFor(StoreSource source) => _sourceErrors[source.id];
  int appCountFor(StoreSource source) => _appsBySource[source.id]?.length ?? 0;

  double? progressFor(StoreApp app) => _progress[app.key];
  String? installErrorFor(StoreApp app) => _installErrors[app.key];

  /// Every app from every enabled source, sorted by name.
  List<StoreApp> get apps {
    final out = <StoreApp>[];
    for (final source in _sources) {
      if (!source.enabled) continue;
      out.addAll(_appsBySource[source.id] ?? const []);
    }
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  /// Apps we installed through the store, newest first.
  List<StoreApp> get installedApps {
    final byId = {for (final app in apps) app.id: app};
    final out = <StoreApp>[];
    for (final entry in _installed.entries) {
      final match = byId[entry.key];
      if (match != null) out.add(match);
    }
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  List<String> get categories {
    final set = <String>{};
    for (final app in apps) {
      set.addAll(app.categories.isEmpty ? ['Other'] : app.categories);
    }
    final list = set.toList()..sort();
    return list;
  }

  int? installedVersionCode(StoreApp app) => _installed[app.id];
  bool isInstalled(StoreApp app) => _installed.containsKey(app.id);

  bool updateAvailable(StoreApp app) {
    final current = _installed[app.id];
    final latest = app.latest;
    if (current == null || latest == null) return false;
    return latest.versionCode > current;
  }

  bool isInstalling(StoreApp app) => _progress.containsKey(app.key);

  /// Unique apps, deduplicated by package id (first repository wins).
  List<StoreApp> search(String query, {String? category}) {
    final q = query.trim().toLowerCase();
    final seen = <String>{};
    final out = <StoreApp>[];
    for (final app in apps) {
      if (!seen.add(app.id)) continue;
      if (category != null && category.isNotEmpty) {
        final cats = app.categories.isEmpty ? ['Other'] : app.categories;
        if (!cats.contains(category)) continue;
      }
      if (q.isNotEmpty) {
        final haystack = [
          app.name,
          app.id,
          app.summary,
          app.developer,
          ...app.tags,
          ...app.categories,
        ].join(' ').toLowerCase();
        if (!haystack.contains(q)) continue;
      }
      out.add(app);
    }
    return out;
  }

  // -- lifecycle --------------------------------------------------------- //

  Future<void> init() async {
    _sources = await _storage.loadSources();
    _installed = await _storage.loadInstalled();
    _ready = true;
    notifyListeners();
    await refresh();
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    final enabled = _sources.where((s) => s.enabled).toList();
    if (enabled.isEmpty) {
      _appsBySource.clear();
      _sourceErrors.clear();
      notifyListeners();
      return;
    }
    _refreshing = true;
    notifyListeners();

    await Future.wait(enabled.map((source) async {
      try {
        final name = source.name;
        final apps = await _repos.fetch(source, displayName: name);
        _appsBySource[source.id] = apps;
        _sourceErrors.remove(source.id);
      } catch (error) {
        _sourceErrors[source.id] = error.toString();
        _appsBySource.remove(source.id);
      }
    }));

    _refreshing = false;
    notifyListeners();
  }

  // -- source management ------------------------------------------------- //

  /// Verify a repository URL and return the number of apps it lists.
  /// Throws [RepoException] when the index cannot be read.
  Future<int> preview(String url) async {
    final source = StoreSource.fromUrl(url);
    final apps = await _repos.fetch(source);
    return apps.length;
  }

  Future<StoreSource> addSource(String url, {String? name}) async {    final source = StoreSource.fromUrl(url, name: name);
    if (source.url.isEmpty) {
      throw RepoException('Enter a repository URL.');
    }
    if (_sources.any((s) => s.url == source.url)) {
      throw RepoException('That repository is already added.');
    }
    _sources = [..._sources, source];
    await _storage.saveSources(_sources);
    notifyListeners();
    await _refreshSource(source);
    return source;
  }

  Future<void> _refreshSource(StoreSource source) async {
    if (!source.enabled) return;
    try {
      _appsBySource[source.id] = await _repos.fetch(source, displayName: source.name);
      _sourceErrors.remove(source.id);
    } catch (error) {
      _sourceErrors[source.id] = error.toString();
    }
    notifyListeners();
  }

  Future<void> removeSource(StoreSource source) async {
    _sources = _sources.where((s) => s.id != source.id).toList();
    _appsBySource.remove(source.id);
    _sourceErrors.remove(source.id);
    await _storage.saveSources(_sources);
    notifyListeners();
  }

  Future<void> setSourceEnabled(StoreSource source, bool enabled) async {
    final updated = source.copyWith(enabled: enabled);
    _sources = [
      for (final s in _sources) if (s.id == source.id) updated else s,
    ];
    await _storage.saveSources(_sources);
    notifyListeners();
    if (enabled) {
      await _refreshSource(updated);
    } else {
      _appsBySource.remove(source.id);
      _sourceErrors.remove(source.id);
      notifyListeners();
    }
  }

  Future<void> renameSource(StoreSource source, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _sources = [
      for (final s in _sources)
        if (s.id == source.id) s.copyWith(name: trimmed) else s,
    ];
    await _storage.saveSources(_sources);
    await refresh();
  }

  // -- installing -------------------------------------------------------- //

  Future<void> install(StoreApp app) async {
    final release = app.latest;
    if (release == null) {
      _installErrors[app.key] = 'This app has no downloadable release.';
      notifyListeners();
      return;
    }
    _installErrors.remove(app.key);
    _progress[app.key] = 0;
    notifyListeners();
    try {
      final file = await _installer.download(release, onProgress: (value) {
        if (value != null) _progress[app.key] = value;
        notifyListeners();
      });

      if (release.sha256.isNotEmpty) {
        final digest = await _sha256(file);
        if (digest.toLowerCase() != release.sha256.toLowerCase()) {
          await file.delete();
          throw Exception('Checksum mismatch — the download may be corrupt.');
        }
      }

      await _installer.installApk(file);
      _installed[app.id] = release.versionCode;
      await _storage.saveInstalled(_installed);
    } catch (error) {
      _installErrors[app.key] = _friendly(error);
    } finally {
      _progress.remove(app.key);
      notifyListeners();
    }
  }

  Future<void> forgetInstalled(StoreApp app) async {
    _installed.remove(app.id);
    await _storage.saveInstalled(_installed);
    notifyListeners();
  }

  Future<void> clearEverything() async {
    _sources = [];
    _appsBySource.clear();
    _sourceErrors.clear();
    _installed = {};
    await _storage.clearAll();
    notifyListeners();
  }

  String _friendly(Object error) {
    if (error is RepoException) return error.message;
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<String> _sha256(File file) async {
    // Implemented without an extra dependency using the platform's hashing via
    // dart:io is not available, so use a small pure-Dart implementation.
    final bytes = await file.readAsBytes();
    return _sha256Hex(bytes);
  }

  @override
  void dispose() {
    _repos.dispose();
    super.dispose();
  }
}

// -- minimal SHA-256 ------------------------------------------------------- //

const _k = <int>[
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1,
  0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
  0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
  0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
  0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
  0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
  0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
  0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
  0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
];

String _sha256Hex(List<int> input) {
  final message = List<int>.from(input)..add(0x80);
  while (message.length % 64 != 56) {
    message.add(0);
  }
  final bitLength = input.length * 8;
  for (var i = 7; i >= 0; i--) {
    message.add((bitLength >> (i * 8)) & 0xff);
  }

  var h0 = 0x6a09e667, h1 = 0xbb67ae85, h2 = 0x3c6ef372, h3 = 0xa54ff53a;
  var h4 = 0x510e527f, h5 = 0x9b05688c, h6 = 0x1f83d9ab, h7 = 0x5be0cd19;

  final w = List<int>.filled(64, 0);
  for (var offset = 0; offset < message.length; offset += 64) {
    for (var i = 0; i < 16; i++) {
      final j = offset + i * 4;
      w[i] = (message[j] << 24) |
          (message[j + 1] << 16) |
          (message[j + 2] << 8) |
          message[j + 3];
    }
    for (var i = 16; i < 64; i++) {
      final s0 = _rotr(w[i - 15], 7) ^ _rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
      final s1 = _rotr(w[i - 2], 17) ^ _rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xffffffff;
    }
    var a = h0, b = h1, c = h2, d = h3, e = h4, f = h5, g = h6, h = h7;
    for (var i = 0; i < 64; i++) {
      final s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
      final ch = (e & f) ^ (~e & g);
      final temp1 = (h + s1 + ch + _k[i] + w[i]) & 0xffffffff;
      final s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final temp2 = (s0 + maj) & 0xffffffff;
      h = g;
      g = f;
      f = e;
      e = (d + temp1) & 0xffffffff;
      d = c;
      c = b;
      b = a;
      a = (temp1 + temp2) & 0xffffffff;
    }
    h0 = (h0 + a) & 0xffffffff;
    h1 = (h1 + b) & 0xffffffff;
    h2 = (h2 + c) & 0xffffffff;
    h3 = (h3 + d) & 0xffffffff;
    h4 = (h4 + e) & 0xffffffff;
    h5 = (h5 + f) & 0xffffffff;
    h6 = (h6 + g) & 0xffffffff;
    h7 = (h7 + h) & 0xffffffff;
  }

  final parts = [h0, h1, h2, h3, h4, h5, h6, h7];
  final buffer = StringBuffer();
  for (final part in parts) {
    buffer.write(part.toRadixString(16).padLeft(8, '0'));
  }
  return buffer.toString();
}

int _rotr(int x, int n) => ((x >> n) | (x << (32 - n))) & 0xffffffff;
