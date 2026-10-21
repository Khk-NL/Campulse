import 'dart:convert';

import 'package:campus_mobile/features/apps/forge_integrations.dart';
import 'package:campus_mobile/features/apps/forge_library_page.dart';
import 'package:campus_mobile/features/apps/forge_library_repository.dart';
import 'package:campus_mobile/features/apps/forge_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';

RecordModel row(String id, Map<String, dynamic> data) =>
    RecordModel.fromJson({'id': id, ...data});

ForgeRepository forge({bool verified = true}) {
  final client = PocketBase('https://example.test');
  final payload = base64Url
      .encode(utf8.encode(jsonEncode({'exp': 4102444800})))
      .replaceAll('=', '');
  client.authStore.save(
    'e30.$payload.test',
    row('member', {'verified': verified}),
  );
  return ForgeRepository(client);
}

class Library extends ForgeLibraryRepository {
  Library(super.forge);
  int loads = 0;
  bool failLoad = false;
  bool failSave = false;
  String? savedNote;
  List<String>? moved;
  String? movedCategory;
  bool? savedRead;
  List<RecordModel> categories = [
    row('tools', {
      'owner': 'member',
      'name': '工具',
      'color': '#A41F35',
      'locked': true,
    }),
  ];
  List<ForgeLibraryEntry> entries = [
    ForgeLibraryEntry(
      star: row('sa', {'created': '2026-10-21'}),
      project: row('a', {'name': '图书助手', 'summary': '整理借阅信息'}),
      bookmark: row('ba', {
        'category': 'tools',
        'tags': ['Flutter'],
        'note': '借书工具',
      }),
    ),
    ForgeLibraryEntry(
      star: row('sb', {'created': '2026-10-20'}),
      project: row('b', {'name': '校园地图', 'summary': '查找校区地点'}),
    ),
  ];
  List<RecordModel> events = [
    row('release', {
      'owner': 'member',
      'repository': 'a',
      'read': false,
      'publishedAt': '2026-10-21',
      'payload': {'tag': 'v1.2', 'name': '图书助手 1.2', 'body': '# 更新\n改善查询'},
    }),
  ];
  @override
  Future<ForgeLibrarySnapshot> load() async {
    loads++;
    if (failLoad) throw StateError('temporary test failure');
    return ForgeLibrarySnapshot(
      categories: categories,
      entries: entries,
      releases: events,
    );
  }

  @override
  Future<void> moveToCategory(
    Iterable<String> repositories,
    String category,
  ) async {
    moved = repositories.toList();
    movedCategory = category;
  }

  @override
  Future<void> markRead(RecordModel event, bool read) async {
    savedRead = read;
    events = [
      row(event.id, {...event.data, 'read': read}),
    ];
  }

  @override
  Future<RecordModel> saveBookmark(
    String repository, {
    String? category,
    List<String>? tags,
    String? note,
  }) async {
    if (failSave) throw StateError('保存服务暂时繁忙，请重试');
    final index = entries.indexWhere((entry) => entry.id == repository);
    final original = entries[index];
    final bookmark = row('bookmark-$repository', {
      ...?original.bookmark?.data,
      'category': ?category,
      'tags': ?tags,
      'note': ?note,
    });
    savedNote = note;
    entries[index] = ForgeLibraryEntry(
      star: original.star,
      project: original.project,
      bookmark: bookmark,
    );
    return bookmark;
  }
}

class Gateway extends ForgeGateway {
  Gateway()
    : super(baseUrl: 'https://example.test/ai', token: 'fixture-session');
  final pages = <int>[];
  final refreshPages = <int>[];
  String? imported;
  @override
  Future<Map<String, dynamic>> githubStars(
    ForgeIntegrationSettings settings, {
    int page = 1,
  }) async {
    pages.add(page);
    return {
      'items': [
        {
          'fullName': 'student/repo$page',
          'name': 'repo$page',
          'description': 'A shared tool',
          'language': 'Dart',
        },
      ],
      'page': page,
      'nextPage': page == 1 ? 2 : null,
    };
  }

  @override
  Future<Map<String, dynamic>> importGithub(
    String fullName,
    ForgeIntegrationSettings settings,
  ) async {
    imported = fullName;
    return {
      'imported': true,
      'project': {'id': 'imported-project'},
    };
  }

  @override
  Future<Map<String, dynamic>> refreshReleases(
    ForgeIntegrationSettings settings, {
    String? repositoryId,
    int page = 1,
  }) async {
    refreshPages.add(page);
    return {
      'checked': 1,
      'created': 1,
      'nextPage': page == 1 ? 2 : null,
      'errors': page == 1
          ? [
              {'repositoryId': 'a', 'error': '请检查仓库来源后重试'},
            ]
          : [],
    };
  }
}

ForgeIntegrationStore store({String token = ''}) => ForgeIntegrationStore(
  namespace: 'test-library',
  read: (_) async =>
      jsonEncode(ForgeIntegrationSettings(githubToken: token).toJson()),
);

void main() {
  Future<void> show(
    WidgetTester tester,
    Library library, {
    Gateway? gateway,
    bool token = false,
    String? initialRepositoryId,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeLibraryPage(
          repository: library.forge,
          libraryRepository: library,
          gateway: gateway,
          settingsStore: store(token: token ? 'fixture-token' : ''),
          initialRepositoryId: initialRepositoryId,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'mobile categories collapse, retain real counts and combine personal search',
    (tester) async {
      tester.view.resetPhysicalSize();
      tester.view.physicalSize = const Size(380, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final library = Library(forge());
      await show(tester, library);
      expect(find.text('图书助手'), findsOneWidget);
      expect(find.text('校园地图'), findsOneWidget);
      expect(find.text('工具'), findsNothing);
      await tester.tap(find.text('分类 · 1'));
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1 个收藏'), findsOneWidget);
      await tester.tap(find.text('工具'));
      await tester.pumpAndSettle();
      expect(find.text('校园地图'), findsNothing);
      await tester.enterText(find.byType(TextField), 'flutter 借书');
      await tester.pumpAndSettle();
      expect(find.text('图书助手'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('bulk movement delegates only the selected personal entries', (
    tester,
  ) async {
    final library = Library(forge());
    await show(tester, library);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('移动分类'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('工具').last);
    await tester.pumpAndSettle();
    expect(library.moved, ['a']);
    expect(library.movedCategory, 'tools');
    expect(find.text('已选 1 项'), findsNothing);
  });

  testWidgets(
    'release timeline changes persisted read state and filters unread results',
    (tester) async {
      final library = Library(forge());
      await show(tester, library);
      await tester.tap(find.text('版本订阅'));
      await tester.pumpAndSettle();
      expect(find.text('图书助手 · 图书助手 1.2'), findsOneWidget);
      await tester.tap(find.byTooltip('标为已读'));
      await tester.pumpAndSettle();
      expect(library.savedRead, true);
      await tester.tap(find.text('待读 0'));
      await tester.pumpAndSettle();
      expect(find.text('图书助手 · 图书助手 1.2'), findsNothing);
    },
  );

  testWidgets(
    'GitHub stars stay paginated and import only the chosen repository',
    (tester) async {
      final library = Library(forge());
      final gateway = Gateway();
      await show(tester, library, gateway: gateway, token: true);
      await tester.tap(find.text('GitHub Star'));
      await tester.pumpAndSettle();
      expect(find.text('student/repo1'), findsOneWidget);
      await tester.tap(find.text('存入个人仓库'));
      await tester.pumpAndSettle();
      expect(gateway.imported, 'student/repo1');
      expect(find.text('已存入个人仓库'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('下一页'));
      await tester.tap(find.byTooltip('下一页'));
      await tester.pumpAndSettle();
      expect(find.text('student/repo2'), findsOneWidget);
      expect(gateway.pages, [1, 2]);
    },
  );

  testWidgets(
    'missing GitHub token offers configuration before any GitHub query',
    (tester) async {
      final gateway = Gateway();
      await show(tester, Library(forge()), gateway: gateway);
      await tester.tap(find.text('GitHub Star'));
      await tester.pumpAndSettle();
      expect(find.text('配置 GitHub Token'), findsOneWidget);
      expect(gateway.pages, isEmpty);
    },
  );

  testWidgets(
    'failed library read can be retried without showing local demo data',
    (tester) async {
      final library = Library(forge())..failLoad = true;
      await show(tester, library);
      expect(find.text('加载失败，点击重试'), findsOneWidget);
      expect(find.text('图书助手'), findsNothing);
      library.failLoad = false;
      await tester.tap(find.text('加载失败，点击重试'));
      await tester.pumpAndSettle();
      expect(find.text('图书助手'), findsOneWidget);
      expect(library.loads, 2);
    },
  );

  testWidgets(
    'desktop sidebar folds and expands without changing the library scope',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await show(tester, Library(forge()));
      expect(find.text('收藏分类'), findsOneWidget);
      await tester.tap(find.byTooltip('收起分类'));
      await tester.pumpAndSettle();
      expect(find.text('收藏分类'), findsNothing);
      expect(find.text('图书助手'), findsOneWidget);
      await tester.tap(find.byTooltip('展开分类'));
      await tester.pumpAndSettle();
      expect(find.text('收藏分类'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'initial repository opens once and failed bookmark editing retains input for retry',
    (tester) async {
      final library = Library(forge())..failSave = true;
      await show(tester, library, initialRepositoryId: 'a');
      expect(find.byTooltip('关闭项目面板'), findsOneWidget);
      await tester.tap(find.text('分类、标签与备注'));
      await tester.pumpAndSettle();
      final noteField = find.widgetWithText(TextField, '个人备注');
      await tester.enterText(noteField, '跨设备整理的一条备注');
      await tester.ensureVisible(find.text('保存').last);
      await tester.tap(find.text('保存').last);
      await tester.pumpAndSettle();
      expect(find.text('保存服务暂时繁忙，请重试'), findsOneWidget);
      expect(
        tester.widget<TextField>(noteField).controller!.text,
        '跨设备整理的一条备注',
      );
      library.failSave = false;
      await tester.tap(find.text('保存').last);
      await tester.pumpAndSettle();
      expect(library.savedNote, '跨设备整理的一条备注');
      await tester.tap(find.byTooltip('关闭项目面板'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('关闭项目面板'), findsNothing);
      expect(find.text('图书助手'), findsOneWidget);
      expect(library.loads, greaterThanOrEqualTo(3));
    },
  );

  testWidgets(
    'version refresh walks all pages and exposes per-project retry details',
    (tester) async {
      final gateway = Gateway();
      await show(tester, Library(forge()), gateway: gateway);
      await tester.tap(find.text('版本订阅'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('刷新版本'));
      await tester.pumpAndSettle();
      expect(gateway.refreshPages, [1, 2]);
      expect(find.text('已检查 2 项订阅，新增 2 个版本；1 项待重试'), findsOneWidget);
      await tester.tap(find.text('待处理订阅 · 1'));
      await tester.pumpAndSettle();
      expect(find.text('请检查仓库来源后重试'), findsOneWidget);
    },
  );
}
