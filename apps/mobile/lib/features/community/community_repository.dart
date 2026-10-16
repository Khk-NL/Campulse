import 'package:pocketbase/pocketbase.dart';
import 'package:campus_mobile/core/config/university_config.dart';

/// Each platform uses the same owner-scoped PocketBase records.
class CommunityRepository {
  CommunityRepository(this.client, {String? universityId})
    : universityId =
          universityId ?? UniversityConfigs.defaultConfig.universityId;
  final PocketBase client;
  final String universityId;
  String get userId => client.authStore.record?.id ?? '';
  bool get canParticipate =>
      client.authStore.isValid &&
      client.authStore.record?.getBoolValue('verified') == true;

  Future<ResultList<RecordModel>> posts({
    int page = 1,
    String? kind,
    String? campus,
    String query = '',
    String scope = 'all',
  }) async {
    final joined = scope == 'joined';
    final prefix = joined ? 'post.' : '';
    final rows = await client
        .collection(joined ? 'community_interests' : 'community_posts')
        .getList(
          page: page,
          perPage: 20,
          expand: joined ? 'post' : null,
          sort: '-created',
          filter: client.filter(
            [
              '${prefix}universityId = {:university}',
              if (scope == 'mine' || joined) 'owner = {:owner}',
              if (kind != null) '${prefix}kind = {:kind}',
              if (campus != null) '${prefix}campus = {:campus}',
              if (query.trim().isNotEmpty)
                '(${prefix}title ~ {:query} || ${prefix}body ~ {:query} || ${prefix}tags ~ {:query})',
            ].join(' && '),
            {
              'owner': userId,
              'university': universityId,
              'kind': kind,
              'campus': campus,
              'query': query.trim(),
            },
          ),
        );
    if (!joined) return rows;
    return ResultList<RecordModel>(
      page: rows.page,
      perPage: rows.perPage,
      totalItems: rows.totalItems,
      totalPages: rows.totalPages,
      items: [
        for (final row in rows.items) ?row.get<RecordModel?>('expand.post'),
      ],
    );
  }

  Future<RecordModel> post(String id) =>
      client.collection('community_posts').getOne(id);
  Future<RecordModel> publish(Map<String, dynamic> fields) => client
      .collection('community_posts')
      .create(
        body: {
          ...fields,
          'owner': userId,
          'universityId': universityId,
          'status': 'open',
        },
      );
  Future<RecordModel> updatePost(String id, Map<String, dynamic> fields) =>
      client.collection('community_posts').update(id, body: fields);
  Future<void> setStatus(String id, String status) async {
    await client
        .collection('community_posts')
        .update(id, body: {'status': status});
  }

  Future<List<RecordModel>> interests(String post) => client
      .collection('community_interests')
      .getFullList(
        filter: client.filter('post = {:post}', {'post': post}),
        sort: 'created',
      );
  Future<RecordModel> join(String post, String name, String message) => client
      .collection('community_interests')
      .create(
        body: {
          'owner': userId,
          'post': post,
          'displayName': name.trim(),
          'message': message.trim(),
        },
      );
  Future<void> leave(String id) =>
      client.collection('community_interests').delete(id);
  Future<ResultList<RecordModel>> replies(String post, {int page = 1}) => client
      .collection('community_replies')
      .getList(
        page: page,
        perPage: 20,
        sort: 'created',
        filter: client.filter('post = {:post}', {'post': post}),
      );
  Future<RecordModel> reply(String post, String name, String body) => client
      .collection('community_replies')
      .create(
        body: {
          'owner': userId,
          'post': post,
          'displayName': name.trim(),
          'body': body.trim(),
        },
      );
  Future<ResultList<RecordModel>> profiles({
    int page = 1,
    String query = '',
  }) => client
      .collection('community_profiles')
      .getList(
        page: page,
        perPage: 20,
        sort: '-updated',
        filter: client.filter(
          'published = true${query.trim().isEmpty ? '' : ' && (interests ~ {:q} || bio ~ {:q} || displayName ~ {:q})'}',
          {'q': query.trim()},
        ),
      );
  Future<RecordModel?> myProfile() async {
    final rows = await client
        .collection('community_profiles')
        .getList(
          perPage: 1,
          filter: client.filter('owner = {:owner}', {'owner': userId}),
        );
    return rows.items.firstOrNull;
  }

  Future<RecordModel> saveProfile(
    String? id,
    Map<String, dynamic> fields,
  ) async {
    final profiles = client.collection('community_profiles');
    final existingId = id ?? (await myProfile())?.id;
    if (existingId != null) return profiles.update(existingId, body: fields);
    try {
      return await profiles.create(body: {...fields, 'owner': userId});
    } on ClientException catch (error) {
      if (error.statusCode != 400) rethrow;
      // Another device may have created the unique owner profile meanwhile.
      final concurrent = await myProfile();
      if (concurrent == null) rethrow;
      return profiles.update(concurrent.id, body: fields);
    }
  }
}
