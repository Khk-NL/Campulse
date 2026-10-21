import 'package:pocketbase/pocketbase.dart';
import 'package:campus_mobile/core/config/university_config.dart';

/// Community content belongs to Campulse; external code hosting is optional.
class ForgeRepository {
  static const int _pageSize = 20;

  ForgeRepository(this.client, {String? universityId})
    : universityId =
          universityId ?? UniversityConfigs.defaultConfig.universityId;
  final PocketBase client;
  final String universityId;
  String get userId => client.authStore.record?.id ?? '';
  bool get canWrite =>
      client.authStore.isValid &&
      client.authStore.record?.getBoolValue('verified') == true;

  Future<ResultList<RecordModel>> projects({
    int page = 1,
    String query = '',
    bool mine = false,
    String sort = 'updated',
    bool starred = false,
  }) async {
    final sortField = switch (sort) {
      'updated' => '-updated,id',
      'created' => '-created,id',
      'name' => 'name,id',
      _ => throw ArgumentError.value(sort, 'sort', 'Select a project sort'),
    };
    if (starred && userId.isEmpty) {
      return ResultList(page: page, perPage: _pageSize);
    }
    return client
        .collection('forge_repositories')
        .getList(
          page: page,
          perPage: _pageSize,
          sort: sortField,
          filter: client.filter(
            [
              if (starred) 'forge_stars_via_repository.owner ?= {:owner}',
              if (mine) 'owner = {:owner}',
              if (!mine) 'visibility = "public" && reviewState = "approved" && schoolVerified = true && universityId = {:university}',
              if (query.trim().isNotEmpty)
                '(name ~ {:query} || summary ~ {:query} || topics ~ {:query})',
            ].join(' && '),
            {
              'owner': userId,
              'query': query.trim(),
              'university': universityId,
            },
          ),
        );
  }

  Future<RecordModel> project(String id) =>
      client.collection('forge_repositories').getOne(id);
  Future<RecordModel> saveProject({
    String? id,
    required String name,
    required String summary,
    required String readme,
    required String topics,
    required bool isPublic,
    String schoolProof = '',
    String repositoryUrl = '',
  }) {
    final body = <String, dynamic>{
      'name': name.trim(),
      'summary': summary.trim(),
      'readme': readme,
      'topics': topics.trim(),
      'visibility': isPublic ? 'public' : 'private',
      'reviewState': 'draft',
      'schoolProof': schoolProof.trim(),
      'repositoryUrl': repositoryUrl.trim(),
    };
    if (id != null) {
      return client.collection('forge_repositories').update(id, body: body);
    }
    body['owner'] = userId;
    body['universityId'] = universityId;
    body['schoolVerified'] = false;
    body['reviewNote'] = '';
    return client.collection('forge_repositories').create(body: body);
  }

  Future<RecordModel> submitProject(String id) async {
    final row = await project(id);
    if (row.getStringValue('owner') != userId || !canWrite) {
      throw StateError('请使用项目所有者的已验证账号提交');
    }
    if (row.getStringValue('schoolProof').trim().isEmpty) {
      throw StateError('请在编辑项目中填写华师大归属材料');
    }
    return client
        .collection('forge_repositories')
        .update(id, body: {'reviewState': 'pending', 'visibility': 'public'});
  }

  Future<ResultList<RecordModel>> communityThreads({
    int page = 1,
    String query = '',
    String? kind,
    String? status,
    bool starred = false,
    String sort = 'created',
  }) async {
    if (kind != null &&
        !const ['question', 'idea', 'bug', 'update'].contains(kind)) {
      throw ArgumentError.value(kind, 'kind', 'Select a community thread kind');
    }
    if (status != null && !const ['open', 'closed'].contains(status)) {
      throw ArgumentError.value(
        status,
        'status',
        'Select a community thread status',
      );
    }
    final sortField = switch (sort) {
      'created' => '-created,id',
      'updated' => '-updated,id',
      _ => throw ArgumentError.value(
        sort,
        'sort',
        'Select a community thread sort',
      ),
    };
    if (starred && (!client.authStore.isValid || userId.isEmpty)) {
      return ResultList(page: page, perPage: _pageSize);
    }
    return client
        .collection('forge_discussions')
        .getList(
          page: page,
          perPage: _pageSize,
          sort: sortField,
          expand: 'repository',
          filter: client.filter(
            [
              'repository.visibility = "public" && repository.reviewState = "approved" && repository.schoolVerified = true && repository.universityId = {:university}',
              if (kind != null) 'kind = {:kind}',
              if (status != null) 'status = {:status}',
              if (starred)
                'repository.forge_stars_via_repository.owner ?= {:owner}',
              if (query.trim().isNotEmpty) '(title ~ {:query} || body ~ {:query} || repository.name ~ {:query} || repository.topics ~ {:query})',
            ].join(' && '),
            {
              'university': universityId,
              'kind': kind,
              'status': status,
              'owner': userId,
              'query': query.trim(),
            },
          ),
        );
  }

  Future<ResultList<RecordModel>> discussions(
    String repository, {
    int page = 1,
    String? status,
    String? kind,
    String query = '',
  }) => client
      .collection('forge_discussions')
      .getList(
        page: page,
        perPage: _pageSize,
        sort: '-created',
        filter: client.filter(
          [
            'repository = {:id}',
            if (status != null) 'status = {:status}',
            if (kind != null) 'kind = {:kind}',
            if (query.trim().isNotEmpty)
              '(title ~ {:query} || body ~ {:query})',
          ].join(' && '),
          {
            'id': repository,
            'status': status,
            'kind': kind,
            'query': query.trim(),
          },
        ),
      );
  Future<RecordModel> discuss(
    String repository,
    String title,
    String body,
    String kind,
  ) => client
      .collection('forge_discussions')
      .create(
        body: {
          'owner': userId,
          'repository': repository,
          'title': title.trim(),
          'body': body.trim(),
          'kind': kind,
          'status': 'open',
        },
      );
  Future<RecordModel> discussion(String id) =>
      client.collection('forge_discussions').getOne(id);
  Future<void> setStatus(String id, String status) async => client
      .collection('forge_discussions')
      .update(id, body: {'status': status});
  Future<ResultList<RecordModel>> replies(String discussion, {int page = 1}) =>
      client
          .collection('forge_replies')
          .getList(
            page: page,
            perPage: _pageSize,
            sort: 'created',
            filter: client.filter('discussion = {:id}', {'id': discussion}),
          );
  Future<RecordModel> reply(String discussion, String body) => client
      .collection('forge_replies')
      .create(
        body: {'owner': userId, 'discussion': discussion, 'body': body.trim()},
      );
  Future<ResultList<RecordModel>> stars(String repository, {int page = 1}) =>
      client
          .collection('forge_stars')
          .getList(
            page: page,
            perPage: 100,
            filter: client.filter('repository = {:id}', {'id': repository}),
          );
  Future<RecordModel?> myStar(String repository) async {
    if (userId.isEmpty) return null;
    final rows = await client
        .collection('forge_stars')
        .getList(
          perPage: 1,
          filter: client.filter('repository = {:id} && owner = {:owner}', {
            'id': repository,
            'owner': userId,
          }),
        );
    return rows.items.isEmpty ? null : rows.items.first;
  }

  Future<void> toggleStar(String repository) async {
    if (!canWrite) throw StateError('请使用已验证账号参与社区');
    final current = await myStar(repository);
    if (current != null) {
      await client.collection('forge_stars').delete(current.id);
    } else {
      await client
          .collection('forge_stars')
          .create(body: {'owner': userId, 'repository': repository});
    }
  }
}
