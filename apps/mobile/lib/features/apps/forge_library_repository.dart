import 'package:pocketbase/pocketbase.dart';

import 'forge_repository.dart';

/// A star is public interest; bookmarks and categories are personal organization.
class ForgeLibraryEntry {
  const ForgeLibraryEntry({
    required this.star,
    required this.project,
    this.bookmark,
  });

  final RecordModel star;
  final RecordModel project;
  final RecordModel? bookmark;
  String get id => project.id;
  String get name => project.getStringValue('name');
  String get categoryId => bookmark?.getStringValue('category') ?? '';
  String get note => bookmark?.getStringValue('note') ?? '';
  List<String> get tags => libraryStrings(bookmark?.data['tags']);
  Map<String, dynamic> get analysis => libraryMap(bookmark?.data['analysis']);
  Map<String, dynamic> get metadata =>
      libraryMap(bookmark?.data['githubMetadata']);
}

class ForgeLibrarySnapshot {
  const ForgeLibrarySnapshot({
    this.categories = const [],
    this.entries = const [],
    this.subscriptions = const [],
    this.releases = const [],
  });

  final List<RecordModel> categories;
  final List<ForgeLibraryEntry> entries;
  final List<RecordModel> subscriptions;
  final List<RecordModel> releases;

  Map<String, int> get categoryCounts {
    final counts = <String, int>{'': 0};
    for (final category in categories) {
      counts[category.id] = 0;
    }
    for (final entry in entries) {
      counts.update(entry.categoryId, (n) => n + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  List<ForgeLibraryEntry> filtered({
    String? category,
    String query = '',
    String sort = 'starred',
  }) {
    final words = query
        .toLowerCase()
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty);
    final result = entries.where((entry) {
      if (category != null && entry.categoryId != category) return false;
      final text = [
        entry.name,
        entry.project.getStringValue('summary'),
        entry.project.getStringValue('topics'),
        entry.note,
        ...entry.tags,
      ].join(' ').toLowerCase();
      return words.every(text.contains);
    }).toList();
    result.sort((a, b) {
      final int order;
      if (sort == 'name') {
        order = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      } else {
        order = b.star
            .getStringValue('created')
            .compareTo(a.star.getStringValue('created'));
      }
      return order == 0 ? a.id.compareTo(b.id) : order;
    });
    return result;
  }
}

Map<String, dynamic> libraryMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<String> libraryStrings(dynamic value) => value is List
    ? value
          .whereType<String>()
          .where((value) => value.trim().isNotEmpty)
          .toList()
    : value is String && value.trim().isNotEmpty
    ? [value.trim()]
    : <String>[];

class ForgeLibraryRepository {
  ForgeLibraryRepository(this.forge);

  final ForgeRepository forge;
  PocketBase get client => forge.client;
  String get owner => forge.userId;
  String get _ownerFilter =>
      client.filter('owner = {:owner}', {'owner': owner});

  String _requireMember() {
    if (!forge.canWrite || owner.isEmpty) {
      throw StateError('请登录已验证的 Campulse 账号');
    }
    return owner;
  }

  void _checkOwner(String expectedOwner) {
    if (owner != expectedOwner) {
      throw StateError('登录账号已切换，请重新操作');
    }
    _requireMember();
  }

  bool _visible(RecordModel project) =>
      project.getStringValue('owner') == owner ||
      (project.getStringValue('visibility') == 'public' &&
          project.getStringValue('reviewState') == 'approved' &&
          project.getBoolValue('schoolVerified') &&
          project.getStringValue('universityId') == forge.universityId);

  Future<ForgeLibrarySnapshot> load() async {
    if (owner.isEmpty || !client.authStore.isValid) {
      return const ForgeLibrarySnapshot();
    }
    final records = await Future.wait([
      client
          .collection('forge_categories')
          .getFullList(filter: _ownerFilter, sort: 'position,created,id'),
      client.collection('forge_bookmarks').getFullList(filter: _ownerFilter),
      client
          .collection('forge_stars')
          .getFullList(
            filter: _ownerFilter,
            expand: 'repository',
            sort: '-created,id',
          ),
      client
          .collection('forge_subscriptions')
          .getFullList(filter: _ownerFilter),
      client
          .collection('forge_release_events')
          .getFullList(filter: _ownerFilter, sort: '-publishedAt,id'),
    ]);
    final bookmarks = {
      for (final row in records[1]) row.getStringValue('repository'): row,
    };
    final entries = <ForgeLibraryEntry>[];
    final seen = <String>{};
    for (final star in records[2]) {
      final project = star.get<RecordModel?>('expand.repository');
      if (project == null) continue;
      if (!_visible(project) || !seen.add(project.id)) continue;
      entries.add(
        ForgeLibraryEntry(
          star: star,
          project: project,
          bookmark: bookmarks[project.id],
        ),
      );
    }
    return ForgeLibrarySnapshot(
      categories: records[0],
      entries: entries,
      subscriptions: records[3]
          .where((row) => seen.contains(row.getStringValue('repository')))
          .toList(),
      releases: records[4]
          .where((row) => seen.contains(row.getStringValue('repository')))
          .toList(),
    );
  }

  Future<RecordModel?> _personalRecord(
    String collection,
    String repository,
  ) async {
    final rows = await client
        .collection(collection)
        .getList(
          perPage: 1,
          filter: client.filter(
            'owner = {:owner} && repository = {:repository}',
            {'owner': owner, 'repository': repository},
          ),
        );
    return rows.items.isEmpty ? null : rows.items.first;
  }

  Future<RecordModel> saveCategory({
    RecordModel? category,
    required String name,
    required String color,
    required bool locked,
    int position = 0,
  }) {
    _requireMember();
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 60) {
      throw ArgumentError('分类名称请填写 1–60 个字');
    }
    if (!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(color)) {
      throw ArgumentError('请选择分类颜色');
    }
    final body = <String, dynamic>{
      'name': trimmed,
      'color': color,
      'locked': locked,
      'position': category?.data['position'] ?? position,
    };
    if (category != null) {
      if (category.getStringValue('owner') != owner) {
        throw StateError('请编辑本人的分类');
      }
      return client
          .collection('forge_categories')
          .update(category.id, body: body);
    }
    return client
        .collection('forge_categories')
        .create(body: {...body, 'owner': owner});
  }

  Future<void> deleteCategory(RecordModel category) async {
    final operationOwner = _requireMember();
    if (category.getStringValue('owner') != operationOwner) {
      throw StateError('请管理本人的分类');
    }
    final rows = await client
        .collection('forge_bookmarks')
        .getFullList(
          filter: client.filter('owner = {:owner} && category = {:category}', {
            'owner': operationOwner,
            'category': category.id,
          }),
        );
    for (final bookmark in rows) {
      _checkOwner(operationOwner);
      await client
          .collection('forge_bookmarks')
          .update(bookmark.id, body: {'category': ''});
    }
    _checkOwner(operationOwner);
    await client.collection('forge_categories').delete(category.id);
  }

  Future<RecordModel> saveBookmark(
    String repository, {
    String? category,
    List<String>? tags,
    String? note,
  }) async {
    final operationOwner = _requireMember();
    final current = await _personalRecord('forge_bookmarks', repository);
    _checkOwner(operationOwner);
    final uniqueTags = <String>[];
    if (tags != null) {
      final seen = <String>{};
      for (final tag in tags) {
        final text = tag.trim();
        if (text.isNotEmpty && seen.add(text.toLowerCase())) {
          uniqueTags.add(text);
        }
      }
    }
    final body = <String, dynamic>{
      'category': ?category,
      if (tags != null) 'tags': uniqueTags,
      if (note != null) 'note': note.trim(),
    };
    if (current != null) {
      return client
          .collection('forge_bookmarks')
          .update(current.id, body: body);
    }
    return client
        .collection('forge_bookmarks')
        .create(
          body: {...body, 'owner': operationOwner, 'repository': repository},
        );
  }

  Future<void> moveToCategory(
    Iterable<String> repositories,
    String category,
  ) async {
    final operationOwner = _requireMember();
    for (final id in repositories.toSet()) {
      await saveBookmark(id, category: category);
      _checkOwner(operationOwner);
    }
  }

  Future<void> applySuggestions(
    ForgeLibraryEntry entry,
    List<RecordModel> categories,
  ) async {
    final operationOwner = _requireMember();
    final current = await _personalRecord('forge_bookmarks', entry.id);
    _checkOwner(operationOwner);
    final analysis = libraryMap(current?.data['analysis'] ?? entry.analysis);
    final currentCategory =
        current?.getStringValue('category') ?? entry.categoryId;
    RecordModel? category;
    for (final row in categories) {
      if (row.id == currentCategory) category = row;
    }
    String? nextCategory;
    final suggestedName = '${analysis['suggestedCategory'] ?? ''}'.trim();
    if (category?.getBoolValue('locked') != true && suggestedName.isNotEmpty) {
      RecordModel? suggested;
      for (final row in categories) {
        if (row.getStringValue('name').toLowerCase() ==
            suggestedName.toLowerCase()) {
          suggested = row;
          break;
        }
      }
      suggested ??= await saveCategory(
        name: suggestedName,
        color: '#A41F35',
        locked: false,
        position: categories.length,
      );
      _checkOwner(operationOwner);
      nextCategory = suggested.id;
    }
    final existingTags = libraryStrings(current?.data['tags'] ?? entry.tags);
    await saveBookmark(
      entry.id,
      category: nextCategory,
      tags: [...existingTags, ...libraryStrings(analysis['suggestedTags'])],
    );
  }

  Future<RecordModel> subscribe(
    String repository, {
    bool includePrereleases = false,
  }) async {
    final operationOwner = _requireMember();
    final current = await _personalRecord('forge_subscriptions', repository);
    _checkOwner(operationOwner);
    final body = {'includePrereleases': includePrereleases};
    if (current != null) {
      return client
          .collection('forge_subscriptions')
          .update(current.id, body: body);
    }
    return client
        .collection('forge_subscriptions')
        .create(
          body: {...body, 'owner': operationOwner, 'repository': repository},
        );
  }

  Future<void> unsubscribe(RecordModel subscription) async {
    _requireMember();
    if (subscription.getStringValue('owner') != owner) {
      throw StateError('请管理本人的订阅');
    }
    await client.collection('forge_subscriptions').delete(subscription.id);
  }

  Future<void> markRead(RecordModel event, bool read) async {
    _requireMember();
    if (event.getStringValue('owner') != owner) {
      throw StateError('请管理本人的版本记录');
    }
    await client
        .collection('forge_release_events')
        .update(event.id, body: {'read': read});
  }
}
