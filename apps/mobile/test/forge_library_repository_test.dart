import 'dart:convert';

import 'package:campus_mobile/features/apps/forge_library_repository.dart';
import 'package:campus_mobile/features/apps/forge_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketbase/pocketbase.dart';

Map<String, dynamic> project(
  String id, {
  String owner = 'author',
  bool approved = true,
  String university = 'ecnu',
}) => {
  'id': id,
  'owner': owner,
  'name': 'Project $id',
  'summary': 'A campus tool',
  'visibility': approved ? 'public' : 'private',
  'reviewState': approved ? 'approved' : 'draft',
  'schoolVerified': approved,
  'universityId': university,
};

class LibraryBackend {
  final requests = <http.Request>[];
  final rows = <String, List<Map<String, dynamic>>>{
    'forge_categories': [],
    'forge_bookmarks': [],
    'forge_stars': [],
    'forge_subscriptions': [],
    'forge_release_events': [],
  };
  int _nextId = 0;
  late final client = PocketBase(
    'https://library.example',
    httpClientFactory: () => MockClient((request) async {
      requests.add(request);
      final path = request.url.pathSegments;
      final collection = path[2];
      final items = rows[collection]!;
      Object body;
      if (request.method == 'GET') {
        final filter = request.url.queryParameters['filter'] ?? '';
        final repo = RegExp(r'repository = "([^"]*)"')
            .firstMatch(filter)
            ?.group(1);
        final category = RegExp(r'category = "([^"]*)"')
            .firstMatch(filter)
            ?.group(1);
        final selected = items
            .where(
              (row) =>
                  (repo == null || row['repository'] == repo) &&
                  (category == null || row['category'] == category),
            )
            .toList();
        body = {
          'page': 1,
          'perPage': 1000,
          'totalItems': selected.length,
          'totalPages': 1,
          'items': selected,
        };
      } else if (request.method == 'POST') {
        final row = {
          'id': 'new${_nextId++}',
          ...jsonDecode(request.body) as Map<String, dynamic>,
        };
        items.add(row);
        body = row;
      } else if (request.method == 'PATCH') {
        final row = items.firstWhere((row) => row['id'] == path.last);
        row.addAll(jsonDecode(request.body) as Map<String, dynamic>);
        body = row;
      } else {
        items.removeWhere((row) => row['id'] == path.last);
        return http.Response('', 204);
      }
      return http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json'},
      );
    }),
  );

  ForgeLibraryRepository repository({bool signedIn = true}) {
    if (signedIn) {
      final payload = base64Url
          .encode(utf8.encode(jsonEncode({'exp': 4102444800})))
          .replaceAll('=', '');
      client.authStore.save(
        'e30.$payload.test',
        RecordModel.fromJson({'id': 'member', 'verified': true}),
      );
    }
    return ForgeLibraryRepository(ForgeRepository(client));
  }

  void star(
    Map<String, dynamic> repository, {
    String created = '2026-10-21 10:00:00.000Z',
  }) {
    rows['forge_stars']!.add({
      'id': 'star${rows['forge_stars']!.length}',
      'owner': 'member',
      'repository': repository['id'],
      'created': created,
      'expand': {'repository': repository},
    });
  }
}

RecordModel record(String id, Map<String, dynamic> data) =>
    RecordModel.fromJson({'id': id, ...data});

void main() {
  test('library binds all reads to owner and omits inaccessible or duplicate stars', () async {
    final backend = LibraryBackend();
    backend.rows['forge_categories']!.add({
      'id': 'tools',
      'owner': 'member',
      'name': '工具',
      'color': '#A41F35',
    });
    backend.rows['forge_bookmarks']!.add({
      'id': 'bookmark',
      'owner': 'member',
      'repository': 'public',
      'category': 'tools',
      'tags': ['Flutter'],
      'note': '课程助手',
    });
    backend.star(project('public'));
    backend.star(project('public'));
    backend.star(project('private', owner: 'member', approved: false));
    backend.star(project('hidden', approved: false));
    backend.star(project('other-school', university: 'another'));
    backend.rows['forge_stars']!.add({
      'id': 'unexpanded',
      'owner': 'member',
      'repository': 'removed',
    });
    backend.rows['forge_subscriptions']!.addAll([
      {'id': 'visible-sub', 'owner': 'member', 'repository': 'public'},
      {'id': 'hidden-sub', 'owner': 'member', 'repository': 'hidden'},
    ]);
    backend.rows['forge_release_events']!.addAll([
      {'id': 'visible-event', 'owner': 'member', 'repository': 'public'},
      {'id': 'hidden-event', 'owner': 'member', 'repository': 'hidden'},
    ]);
    final snapshot = await backend.repository().load();
    expect(snapshot.entries.map((entry) => entry.id), ['public', 'private']);
    expect(snapshot.categoryCounts, {'': 1, 'tools': 1});
    expect(snapshot.subscriptions.single.id, 'visible-sub');
    expect(snapshot.releases.single.id, 'visible-event');
    expect(backend.requests, hasLength(5));
    for (final request in backend.requests) {
      expect(request.url.queryParameters['filter'], 'owner = "member"');
    }
    expect(
      backend.requests
          .firstWhere((r) => r.url.path.contains('forge_stars'))
          .url
          .queryParameters['expand'],
      'repository',
    );
  });

  test('guest loads an empty personal library without remote reads', () async {
    final backend = LibraryBackend();
    expect((await backend.repository(signedIn: false).load()).entries, isEmpty);
    expect(backend.requests, isEmpty);
  });

  test(
    'personal keyword matching includes tags and notes, with stable sorting',
    () {
      ForgeLibraryEntry entry(String id, String date, {String category = ''}) =>
          ForgeLibraryEntry(
            star: record('s$id', {'created': date}),
            project: record(id, {'name': 'Same'}),
            bookmark: record('b$id', {
              'category': category,
              'tags': ['Flutter'],
              'note': '课程助手',
            }),
          );
      final snapshot = ForgeLibrarySnapshot(
        entries: [
          entry('b', '2026-10-20'),
          entry('a', '2026-10-21', category: 'tools'),
        ],
      );
      expect(snapshot.filtered(query: 'flutter 课程').map((e) => e.id), [
        'a',
        'b',
      ]);
      expect(
        snapshot.filtered(category: 'tools', query: 'flutter').single.id,
        'a',
      );
      expect(snapshot.filtered(sort: 'name').map((e) => e.id), ['a', 'b']);
      expect(snapshot.filtered(query: 'flutter unknown'), isEmpty);
    },
  );

  test('bookmark patch deduplicates tags and preserves AI, metadata and public stars', () async {
    final backend = LibraryBackend();
    backend.rows['forge_bookmarks']!.add({
      'id': 'bookmark',
      'owner': 'member',
      'repository': 'public',
      'category': 'tools',
      'analysis': {'summary': 'original'},
      'githubMetadata': {
        'repo': {'stars': 12},
      },
    });
    final repository = backend.repository();
    await repository.saveBookmark(
      'public',
      tags: [' Flutter ', 'flutter', 'Dart', ''],
      note: ' my note ',
    );
    final row = backend.rows['forge_bookmarks']!.single;
    expect(row['tags'], ['Flutter', 'Dart']);
    expect(row['note'], 'my note');
    expect(row['category'], 'tools');
    expect(row['analysis'], {'summary': 'original'});
    expect(row['githubMetadata'], {
      'repo': {'stars': 12},
    });
    expect(
      backend.requests.any((r) => r.url.path.contains('forge_stars')),
      isFalse,
    );
  });

  test('category deletion moves owned bookmarks to unfiled and retains personal content', () async {
    final backend = LibraryBackend();
    backend.rows['forge_categories']!.add({'id': 'tools', 'owner': 'member'});
    backend.rows['forge_bookmarks']!.add({
      'id': 'bookmark',
      'owner': 'member',
      'repository': 'public',
      'category': 'tools',
      'tags': ['Flutter'],
      'note': 'keep',
    });
    await backend.repository().deleteCategory(
      record('tools', {'owner': 'member'}),
    );
    expect(backend.rows['forge_categories'], isEmpty);
    expect(backend.rows['forge_bookmarks']!.single['category'], '');
    expect(backend.rows['forge_bookmarks']!.single['note'], 'keep');
    expect(
      backend.requests.first.url.queryParameters['filter'],
      'owner = "member" && category = "tools"',
    );
  });

  test('bulk category movement creates only private bookmarks', () async {
    final backend = LibraryBackend();
    await backend.repository().moveToCategory(['a', 'b', 'a'], 'tools');
    expect(backend.rows['forge_bookmarks']!.map((row) => row['repository']), [
      'a',
      'b',
    ]);
    expect(
      backend.rows['forge_bookmarks']!.every(
        (row) => row['owner'] == 'member' && row['category'] == 'tools',
      ),
      isTrue,
    );
    expect(
      backend.requests.any((r) => r.url.path.contains('forge_stars')),
      isFalse,
    );
  });

  test('applying AI suggestions preserves locked category and merges personal tags', () async {
    final backend = LibraryBackend();
    backend.rows['forge_bookmarks']!.add({
      'id': 'bookmark',
      'owner': 'member',
      'repository': 'public',
      'category': 'locked',
      'tags': ['Personal'],
      'note': 'keep',
      'analysis': {
        'suggestedCategory': 'AI tools',
        'suggestedTags': ['personal', 'Flutter'],
      },
    });
    final repository = backend.repository();
    final entry = ForgeLibraryEntry(
      star: record('star', {}),
      project: record('public', {}),
    );
    await repository.applySuggestions(entry, [
      record('locked', {'name': 'My category', 'locked': true}),
    ]);
    final row = backend.rows['forge_bookmarks']!.single;
    expect(row['category'], 'locked');
    expect(row['tags'], ['Personal', 'Flutter']);
    expect(row['note'], 'keep');
    expect(backend.rows['forge_categories'], isEmpty);
  });

  test('applying AI category reuses a matching personal category', () async {
    final backend = LibraryBackend();
    backend.rows['forge_bookmarks']!.add({
      'id': 'bookmark',
      'owner': 'member',
      'repository': 'public',
      'analysis': {
        'suggestedCategory': 'tools',
        'suggestedTags': ['Dart'],
      },
    });
    await backend.repository().applySuggestions(
      ForgeLibraryEntry(
        star: record('star', {}),
        project: record('public', {}),
      ),
      [
        record('tools-category', {'name': 'Tools', 'owner': 'member'}),
      ],
    );
    expect(
      backend.rows['forge_bookmarks']!.single['category'],
      'tools-category',
    );
    expect(
      backend.requests.where((r) => r.url.path.contains('forge_categories')),
      isEmpty,
    );
  });

  test('subscription preferences, release read state and unsubscribe are owner scoped', () async {
    final backend = LibraryBackend();
    final repository = backend.repository();
    final subscription = await repository.subscribe('public');
    await repository.subscribe('public', includePrereleases: true);
    expect(backend.rows['forge_subscriptions'], hasLength(1));
    expect(
      backend.rows['forge_subscriptions']!.single['includePrereleases'],
      true,
    );
    backend.rows['forge_release_events']!.add({
      'id': 'event',
      'owner': 'member',
      'read': false,
    });
    await repository.markRead(record('event', {'owner': 'member'}), true);
    expect(backend.rows['forge_release_events']!.single['read'], true);
    await repository.unsubscribe(subscription);
    expect(backend.rows['forge_subscriptions'], isEmpty);
    await expectLater(
      repository.markRead(record('other', {'owner': 'another'}), false),
      throwsStateError,
    );
  });

  test(
    'category validation rejects malformed input before sending a request',
    () {
      final backend = LibraryBackend();
      final repository = backend.repository();
      expect(
        () =>
            repository.saveCategory(name: '', color: '#A41F35', locked: false),
        throwsArgumentError,
      );
      expect(
        () =>
            repository.saveCategory(name: 'tools', color: 'red', locked: false),
        throwsArgumentError,
      );
      expect(backend.requests, isEmpty);
    },
  );
}
