import 'dart:convert';

import 'package:campus_mobile/features/apps/forge_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketbase/pocketbase.dart';

ForgeRepository repository(
  List<http.Request> requests, {
  bool signedIn = true,
}) {
  final client = PocketBase(
    'https://example.test',
    httpClientFactory: () => MockClient((request) async {
      requests.add(request);
      return http.Response(
        jsonEncode({
          'page': int.parse(request.url.queryParameters['page'] ?? '1'),
          'perPage': 20,
          'totalItems': 41,
          'totalPages': 3,
          'items': [
            {'id': 'result'},
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }),
  );
  if (signedIn) {
    final payload = base64Url
        .encode(utf8.encode(jsonEncode({'exp': 4102444800})))
        .replaceAll('=', '');
    client.authStore.save(
      'e30.$payload.signature',
      RecordModel.fromJson({'id': 'member', 'verified': true}),
    );
  }
  return ForgeRepository(client);
}

void main() {
  test(
    'public projects retain reviewed school scope and default order',
    () async {
      final requests = <http.Request>[];
      final rows = await repository(requests).projects();
      final params = requests.single.url.queryParameters;
      expect(
        requests.single.url.path,
        '/api/collections/forge_repositories/records',
      );
      expect(params['sort'], '-updated,id');
      expect(params['page'], '1');
      expect(params['perPage'], '20');
      expect(
        params['filter'],
        'visibility = "public" && reviewState = "approved" && schoolVerified = true && universityId = "ecnu"',
      );
      expect(rows.totalItems, 41);
      expect(rows.totalPages, 3);
    },
  );

  test(
    'project sort is allowlisted and pagination stays server-side',
    () async {
      final requests = <http.Request>[];
      final repo = repository(requests);
      final rows = await repo.projects(page: 3, sort: 'created');
      expect(requests.single.url.queryParameters['sort'], '-created,id');
      expect(requests.single.url.queryParameters['page'], '3');
      expect(rows.page, 3);
      expect(rows.totalItems, 41);
      await repo.projects(sort: 'name');
      expect(requests.last.url.queryParameters['sort'], 'name,id');
      await expectLater(
        repo.projects(sort: 'name,-owner'),
        throwsArgumentError,
      );
      expect(requests.length, 2);
    },
  );

  test(
    'starred projects filter the owner relation before public scope',
    () async {
      final requests = <http.Request>[];
      await repository(requests).projects(starred: true, page: 2);
      final filter = requests.single.url.queryParameters['filter']!;
      expect(
        filter,
        startsWith('forge_stars_via_repository.owner ?= "member" && '),
      );
      expect(filter, contains('reviewState = "approved"'));
      expect(filter, contains('schoolVerified = true'));
      expect(filter, contains('universityId = "ecnu"'));
      expect(requests.single.url.queryParameters['page'], '2');
      expect(requests.length, 1);
    },
  );

  test('personal starred scope keeps drafts and binds both owners', () async {
    final requests = <http.Request>[];
    await repository(requests).projects(mine: true, starred: true);
    expect(
      requests.single.url.queryParameters['filter'],
      'forge_stars_via_repository.owner ?= "member" && owner = "member"',
    );
  });

  test(
    'guest starred selection returns an empty page without a request',
    () async {
      final requests = <http.Request>[];
      final rows = await repository(
        requests,
        signedIn: false,
      ).projects(starred: true, page: 4);
      expect(requests, isEmpty);
      expect(rows.items, isEmpty);
      expect(rows.page, 4);
      expect(rows.perPage, 20);
      expect(rows.totalItems, 0);
      expect(rows.totalPages, 0);
    },
  );

  test('project query is one escaped parameter within the approval filter', () async {
    final requests = <http.Request>[];
    const query = '图书" || reviewState != "approved';
    await repository(requests).projects(query: '  $query  ');
    final encoded = jsonEncode(query);
    expect(
      requests.single.url.queryParameters['filter'],
      'visibility = "public" && reviewState = "approved" && schoolVerified = true && universityId = "ecnu" && (name ~ $encoded || summary ~ $encoded || topics ~ $encoded)',
    );
  });

  test('starred query composes owner, public approval and escaped keyword', () async {
    final requests = <http.Request>[];
    const query = '校园" || owner != ""';
    await repository(requests).projects(starred: true, query: query, page: 2);
    final encoded = jsonEncode(query);
    expect(
      requests.single.url.queryParameters['filter'],
      'forge_stars_via_repository.owner ?= "member" && visibility = "public" && reviewState = "approved" && schoolVerified = true && universityId = "ecnu" && (name ~ $encoded || summary ~ $encoded || topics ~ $encoded)',
    );
    expect(requests.single.url.queryParameters['page'], '2');
  });

  test(
    'personal query keeps owner scope and includes draft projects',
    () async {
      final requests = <http.Request>[];
      await repository(requests).projects(mine: true, query: '课程');
      expect(
        requests.single.url.queryParameters['filter'],
        'owner = "member" && (name ~ "课程" || summary ~ "课程" || topics ~ "课程")',
      );
    },
  );

  test(
    'guest starred scope still rejects invalid sorting before returning',
    () async {
      final requests = <http.Request>[];
      await expectLater(
        repository(
          requests,
          signedIn: false,
        ).projects(starred: true, sort: 'updated,id'),
        throwsArgumentError,
      );
      expect(requests, isEmpty);
    },
  );

  test('discussion kind, status, query and page preserve repository scope', () async {
    final requests = <http.Request>[];
    const query = '崩溃" || repository != "target';
    await repository(requests).discussions(
      'target',
      page: 3,
      status: 'open',
      kind: 'bug',
      query: ' $query ',
    );
    final params = requests.single.url.queryParameters;
    final encoded = jsonEncode(query);
    expect(
      requests.single.url.path,
      '/api/collections/forge_discussions/records',
    );
    expect(params['sort'], '-created');
    expect(params['page'], '3');
    expect(
      params['filter'],
      'repository = "target" && status = "open" && kind = "bug" && (title ~ $encoded || body ~ $encoded)',
    );
  });

  test('discussion default filters preserve existing calls', () async {
    final requests = <http.Request>[];
    await repository(requests).discussions('target');
    expect(
      requests.single.url.queryParameters['filter'],
      'repository = "target"',
    );
  });
}
