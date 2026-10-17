import 'package:flutter_test/flutter_test.dart';

import 'package:custom_app_store/models/source.dart';
import 'package:custom_app_store/models/store_app.dart';

void main() {
  group('normalizeIndexUrl', () {
    test('bare host gets /repo.json', () {
      expect(normalizeIndexUrl('example.com'), 'https://example.com/repo.json');
    });

    test('folder gets /repo.json appended', () {
      expect(normalizeIndexUrl('example.com/store/'),
          'https://example.com/store/repo.json');
    });

    test('explicit json file is kept as-is', () {
      expect(normalizeIndexUrl('https://example.com/index.json'),
          'https://example.com/index.json');
    });

    test('keeps an explicit scheme', () {
      expect(normalizeIndexUrl('http://192.168.1.10:8000'),
          'http://192.168.1.10:8000/repo.json');
    });
  });

  group('StoreApp.fromJson', () {
    test('parses fields and sorts releases by version code', () {
      final app = StoreApp.fromJson({
        'id': 'com.example.app',
        'name': 'Example',
        'summary': 'Hello',
        'categories': ['Tools'],
        'releases': [
          {'versionName': '1.0.0', 'versionCode': 1, 'url': 'https://x/1.apk'},
          {'versionName': '1.2.0', 'versionCode': 12, 'url': 'https://x/12.apk'},
        ],
      }, sourceId: 'abc', sourceName: 'Test Repo');

      expect(app.id, 'com.example.app');
      expect(app.name, 'Example');
      expect(app.categories, ['Tools']);
      expect(app.latestVersionName, '1.2.0');
      expect(app.releases.first.versionCode, 12);
    });

    test('tolerates missing optional fields', () {
      final app = StoreApp.fromJson({'id': 'x', 'name': 'X'});
      expect(app.latest, isNull);
      expect(app.summary, '');
      expect(app.primaryCategory, 'Other');
    });
  });

  test('StoreSource ids are stable for the same URL', () {
    final a = StoreSource.fromUrl('example.com');
    final b = StoreSource.fromUrl('example.com');
    expect(a.id, b.id);
    expect(a.name, 'example.com');
  });
}
