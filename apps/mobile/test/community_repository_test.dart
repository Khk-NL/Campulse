import 'dart:convert';

import 'package:campus_mobile/features/community/community_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketbase/pocketbase.dart';

http.Response response(Map<String, dynamic> json, [int status = 200]) =>
    http.Response(
      jsonEncode(json),
      status,
      headers: {'content-type': 'application/json'},
    );

Map<String, dynamic> page(List<Map<String, dynamic>> items) => {
  'page': 2,
  'perPage': 20,
  'totalItems': 21,
  'totalPages': 2,
  'items': items,
};

CommunityRepository repository(
  Future<http.Response> Function(http.Request) handler,
) {
  final client = PocketBase(
    'http://127.0.0.1',
    httpClientFactory: () => MockClient(handler),
  );
  client.authStore.save('token', RecordModel.fromJson({'id': 'member'}));
  return CommunityRepository(client);
}

void main() {
  test(
    'joined feed pages registrations and preserves expanded post metadata',
    () async {
      final requests = <http.Request>[];
      final repo = repository((request) async {
        requests.add(request);
        return response(
          page([
            {
              'id': 'registration',
              'owner': 'member',
              'post': 'activity',
              'expand': {
                'post': {'id': 'activity', 'title': '羽毛球'},
              },
            },
            {'id': 'missing-expansion', 'owner': 'member', 'post': 'removed'},
          ]),
        );
      });
      final rows = await repo.posts(
        scope: 'joined',
        page: 2,
        kind: 'sport',
        campus: 'minhang',
        query: '羽毛球',
      );
      final request = requests.single;
      expect(request.url.path, endsWith('/community_interests/records'));
      expect(request.url.queryParameters['expand'], 'post');
      expect(request.url.queryParameters['page'], '2');
      expect(request.url.queryParameters['perPage'], '20');
      final filter = request.url.queryParameters['filter']!;
      for (final clause in [
        'owner = "member"',
        'post.universityId = "ecnu"',
        'post.kind = "sport"',
        'post.campus = "minhang"',
        'post.title ~ "羽毛球"',
      ]) {
        expect(filter, contains(clause));
      }
      expect(rows.items.single.id, 'activity');
      expect(rows.totalItems, 21);
      expect(rows.totalPages, 2);
    },
  );

  test(
    'profile created on another device is updated instead of duplicated',
    () async {
      final methods = <String>[];
      final repo = repository((request) async {
        methods.add(request.method);
        if (request.method == 'GET') {
          return response(
            page([
              {'id': 'existing', 'owner': 'member'},
            ]),
          );
        }
        expect(
          request.url.path,
          endsWith('/community_profiles/records/existing'),
        );
        expect(jsonDecode(request.body)['bio'], '第一行\n第二行');
        return response({'id': 'existing', 'owner': 'member'});
      });
      expect(
        (await repo.saveProfile(null, {'bio': '第一行\n第二行'})).id,
        'existing',
      );
      expect(methods, ['GET', 'PATCH']);
    },
  );

  test(
    'concurrent profile creation recovers through the owner-scoped lookup',
    () async {
      final methods = <String>[];
      var reads = 0;
      final repo = repository((request) async {
        methods.add(request.method);
        if (request.method == 'GET') {
          expect(request.url.queryParameters['filter'], 'owner = "member"');
          return response(
            page(
              ++reads == 1
                  ? []
                  : [
                      {'id': 'concurrent', 'owner': 'member'},
                    ],
            ),
          );
        }
        if (request.method == 'POST') {
          return response({'message': 'Unique owner', 'data': {}}, 400);
        }
        return response({'id': 'concurrent', 'owner': 'member'});
      });
      expect((await repo.saveProfile(null, {'bio': '编辑内容'})).id, 'concurrent');
      expect(methods, ['GET', 'POST', 'GET', 'PATCH']);
    },
  );

  test(
    'profile validation errors propagate when no concurrent record exists',
    () async {
      final repo = repository(
        (request) async => request.method == 'GET'
            ? response(page([]))
            : response({'message': 'Invalid fields', 'data': {}}, 400),
      );
      await expectLater(
        repo.saveProfile(null, {'displayName': ''}),
        throwsA(isA<ClientException>()),
      );
    },
  );
}
