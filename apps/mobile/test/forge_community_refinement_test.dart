import 'package:campus_mobile/features/apps/forge_page.dart';
import 'package:campus_mobile/features/apps/forge_markdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';

import 'forge_page_test.dart' show FakeForge;

FakeForge projectRepository() {
  final repo = FakeForge();
  repo.rows.addAll([
    RecordModel.fromJson({
      'id': 'project1',
      'owner': repo.userId,
      'name': 'Zeta 校园工具',
      'summary': '地图工具',
      'readme': '# 项目说明\n\n欢迎参与。',
      'updated': '2026-10-20 12:00:00.000Z',
      'created': '2026-10-01 12:00:00.000Z',
      'visibility': 'public',
      'reviewState': 'approved',
    }),
    RecordModel.fromJson({
      'id': 'project2',
      'owner': 'peer',
      'name': 'Alpha 课表项目',
      'summary': '课程工具',
      'updated': '2026-10-18 12:00:00.000Z',
      'created': '2026-10-19 12:00:00.000Z',
      'visibility': 'public',
      'reviewState': 'approved',
    }),
  ]);
  repo.starredRepositories.add('project2');
  return repo;
}

Future<void> largeSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(900, 1300));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

class _PagedForge extends FakeForge {
  final projectPages = <int>[];

  ResultList<RecordModel> paged(List<RecordModel> items, int page) =>
      ResultList(
        page: page,
        perPage: 20,
        totalItems: items.length,
        totalPages: (items.length / 20).ceil(),
        items: items.skip((page - 1) * 20).take(20).toList(),
      );

  @override
  Future<ResultList<RecordModel>> projects({
    int page = 1,
    String query = '',
    bool mine = false,
    String sort = 'updated',
    bool starred = false,
  }) async {
    projectPages.add(page);
    final result = await super.projects(
      page: page,
      query: query,
      mine: mine,
      sort: sort,
      starred: starred,
    );
    return paged(result.items, page);
  }

  @override
  Future<ResultList<RecordModel>> discussions(
    String repository, {
    int page = 1,
    String? status,
    String? kind,
    String query = '',
  }) async {
    final result = await super.discussions(
      repository,
      page: page,
      status: status,
      kind: kind,
      query: query,
    );
    return paged(result.items, page);
  }

  @override
  Future<RecordModel> project(String id) async =>
      rows.firstWhere((row) => row.id == id);

  @override
  Future<RecordModel?> myStar(String repository) async =>
      starredRepositories.contains(repository)
      ? RecordModel.fromJson({
          'id': 'star',
          'repository': repository,
          'owner': userId,
        })
      : null;

  @override
  Future<ResultList<RecordModel>> stars(
    String repository, {
    int page = 1,
  }) async {
    final star = await myStar(repository);
    return ResultList(
      items: star == null ? [] : [star],
      totalItems: star == null ? 0 : 1,
    );
  }

  @override
  Future<void> toggleStar(String repository) async {
    if (!starredRepositories.remove(repository)) {
      starredRepositories.add(repository);
    }
  }
}

class _GuestForge extends FakeForge {
  @override
  String get userId => '';

  @override
  bool get canWrite => false;
}

void main() {
  testWidgets(
    'guest Star scope offers an account action instead of a publishing prompt',
    (tester) async {
      await largeSurface(tester);
      final repo = _GuestForge();
      var accountOpens = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ForgePage(
            repository: repo,
            onOpenAccount: () => accountOpens++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, '我的 Star'));
      await tester.pumpAndSettle();
      expect(find.text('登录查看收藏的项目'), findsOneWidget);
      expect(find.text('登录账号'), findsOneWidget);
      expect(find.text('把你的第一个项目放到这里'), findsNothing);
      await tester.tap(find.text('登录账号'));
      await tester.pumpAndSettle();
      expect(accountOpens, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'project search, star and sort remain usable with the keyboard inset',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = projectRepository();
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(viewInsets: const EdgeInsets.only(bottom: 300)),
            child: child!,
          ),
          home: ForgePage(repository: repo, showViewSwitcher: false),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '搜索项目'), '校园');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, '我的 Star'));
      await tester.tap(find.widgetWithText(ChoiceChip, '我的 Star'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('项目排序'));
      await tester.tap(find.byTooltip('项目排序'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('名称排序').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(TextField, '搜索项目'));
      await tester.enterText(find.widgetWithText(TextField, '搜索项目'), '地图');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(repo.queries.last, '地图');
      expect(repo.projectOptions.last, (
        mine: false,
        starred: true,
        sort: 'name',
      ));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'closing the last discussion on page two returns to the first filtered page',
    (tester) async {
      await largeSurface(tester);
      final repo = _PagedForge();
      repo.rows.add(projectRepository().rows.first);
      for (var index = 1; index <= 21; index++) {
        final number = index.toString().padLeft(2, '0');
        repo.threads.add(
          RecordModel.fromJson({
            'id': 'thread-$number',
            'repository': 'project1',
            'owner': repo.userId,
            'title': '登录缺陷 $number',
            'body': '操作反馈',
            'kind': 'bug',
            'status': 'open',
          }),
        );
      }
      await tester.pumpWidget(
        MaterialApp(
          home: ForgeProjectPage(repo: repo, id: 'project1'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('讨论与问题'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '搜索讨论'), '登录');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('全部类型'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('缺陷反馈').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, '讨论中'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byTooltip('下一页'),
        500,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.byTooltip('下一页'));
      await tester.pumpAndSettle();
      expect(repo.discussionQueries.last.page, 2);
      await tester.tap(find.text('登录缺陷 21'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('标记为已解决'));
      await tester.pumpAndSettle();
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(repo.discussionQueries.last, (
        repository: 'project1',
        page: 1,
        status: 'open',
        kind: 'bug',
        query: '登录',
      ));
      expect(find.widgetWithText(TextField, '搜索讨论'), findsOneWidget);
      expect(find.text('登录缺陷 21'), findsNothing);
      expect(find.text('登录缺陷 01'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unstarring the last project on page two returns to the first starred page',
    (tester) async {
      await largeSurface(tester);
      final repo = _PagedForge();
      for (var index = 1; index <= 21; index++) {
        final number = index.toString().padLeft(2, '0');
        repo.rows.add(
          RecordModel.fromJson({
            'id': 'project-$number',
            'owner': repo.userId,
            'name': '校园项目 $number',
            'summary': '校园代码工具',
            'visibility': 'public',
            'reviewState': 'approved',
          }),
        );
        repo.starredRepositories.add('project-$number');
      }
      await tester.pumpWidget(
        MaterialApp(home: ForgePage(repository: repo, showViewSwitcher: false)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '搜索项目'), '校园');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, '我的 Star'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('项目排序'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('名称排序').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byTooltip('下一页'),
        600,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.byTooltip('下一页'));
      await tester.pumpAndSettle();
      expect(repo.projectPages.last, 2);
      await tester.tap(find.text('校园项目 21'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Star 1'));
      await tester.pumpAndSettle();
      expect(repo.starredRepositories.contains('project-21'), isFalse);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(repo.projectPages.last, 1);
      expect(repo.projectOptions.last, (
        mine: false,
        starred: true,
        sort: 'name',
      ));
      expect(repo.queries.last, '校园');
      expect(find.text('校园项目 21'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final (size, scale) in [
    (const Size(320, 640), 1.6),
    (const Size(900, 360), 1.0),
  ]) {
    testWidgets(
      'discussion filters remain usable at $size and text scale $scale',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repo = projectRepository();
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: ForgeProjectPage(repo: repo, id: 'project1'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('讨论与问题'));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(TextField, '搜索讨论'), findsOneWidget);
        expect(find.text('讨论类型'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.enterText(find.widgetWithText(TextField, '搜索讨论'), '登录');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        expect(repo.discussionQueries.last.query, '登录');
        await tester.ensureVisible(find.text('全部类型'));
        await tester.tap(find.text('全部类型'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('缺陷反馈').last);
        await tester.pumpAndSettle();
        expect(repo.discussionQueries.last.kind, 'bug');
        expect(repo.discussionQueries.last.query, '登录');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'star scope and sort update repository parameters and visible rows',
    (tester) async {
      await largeSurface(tester);
      final repo = projectRepository();
      await tester.pumpWidget(MaterialApp(home: ForgePage(repository: repo)));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('Zeta 校园工具')).dy,
        lessThan(tester.getTopLeft(find.text('Alpha 课表项目')).dy),
      );
      await tester.tap(find.widgetWithText(ChoiceChip, '我的 Star'));
      await tester.pumpAndSettle();
      expect(repo.projectOptions.last, (
        mine: false,
        starred: true,
        sort: 'updated',
      ));
      expect(find.text('Zeta 校园工具'), findsNothing);
      expect(find.text('Alpha 课表项目'), findsOneWidget);
      await tester.tap(find.byTooltip('项目排序'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('名称排序').last);
      await tester.pumpAndSettle();
      expect(repo.projectOptions.last, (
        mine: false,
        starred: true,
        sort: 'name',
      ));
      await tester.tap(find.widgetWithText(ChoiceChip, '全部项目'));
      await tester.pumpAndSettle();
      expect(repo.projectOptions.last, (
        mine: false,
        starred: false,
        sort: 'name',
      ));
      expect(
        tester.getTopLeft(find.text('Alpha 课表项目')).dy,
        lessThan(tester.getTopLeft(find.text('Zeta 校园工具')).dy),
      );
      await tester.tap(find.byTooltip('项目排序'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('最新发布').last);
      await tester.pumpAndSettle();
      expect(repo.projectOptions.last.sort, 'created');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'refresh reloads starred results while preserving the selected scope',
    (tester) async {
      await largeSurface(tester);
      final repo = projectRepository();
      Widget page(int token) => MaterialApp(
        home: ForgePage(
          key: const ValueKey('feed'),
          repository: repo,
          refreshToken: token,
        ),
      );
      await tester.pumpWidget(page(0));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, '我的 Star'));
      await tester.pumpAndSettle();
      expect(find.text('Alpha 课表项目'), findsOneWidget);
      repo.starredRepositories
        ..clear()
        ..add('project1');
      await tester.pumpWidget(page(1));
      await tester.pumpAndSettle();
      expect(repo.projectOptions.last.starred, isTrue);
      expect(find.text('Alpha 课表项目'), findsNothing);
      expect(find.text('Zeta 校园工具'), findsOneWidget);
    },
  );

  testWidgets('discussion search combines kind and status and can be cleared', (
    tester,
  ) async {
    await largeSurface(tester);
    final repo = projectRepository();
    repo.threads.addAll([
      RecordModel.fromJson({
        'id': 'bug-open',
        'title': '登录失败需要修复',
        'body': '同步 token',
        'kind': 'bug',
        'status': 'open',
      }),
      RecordModel.fromJson({
        'id': 'bug-closed',
        'title': '登录失败已处理',
        'body': '完成修复',
        'kind': 'bug',
        'status': 'closed',
      }),
      RecordModel.fromJson({
        'id': 'question',
        'title': '登录方式咨询',
        'body': '新账号入口',
        'kind': 'question',
        'status': 'open',
      }),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeProjectPage(repo: repo, id: 'project1'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('讨论与问题'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '搜索讨论'), '登录');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全部类型'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('缺陷反馈').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '已解决'));
    await tester.pumpAndSettle();
    expect(repo.discussionQueries.last, (
      repository: 'project1',
      page: 1,
      status: 'closed',
      kind: 'bug',
      query: '登录',
    ));
    expect(find.text('登录失败已处理'), findsOneWidget);
    expect(find.text('登录失败需要修复'), findsNothing);
    expect(find.text('登录方式咨询'), findsNothing);
    await tester.enterText(find.widgetWithText(TextField, '搜索讨论'), '');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '全部讨论'));
    await tester.pumpAndSettle();
    expect(find.text('登录失败需要修复'), findsOneWidget);
    expect(find.text('登录失败已处理'), findsOneWidget);
    expect(find.text('登录方式咨询'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'markdown preview preserves editor text and saves the original source',
    (tester) async {
      await largeSurface(tester);
      final repo = FakeForge();
      const source = '# 新的工具\n\n**功能亮点**\n\n```dart\nprint("campus");\n```';
      await tester.pumpWidget(MaterialApp(home: ForgePage(repository: repo)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('发布项目'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, '项目名称'),
        'Markdown 项目',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'README：目标、用法与参与方式'),
        source,
      );
      await tester.tap(find.text('预览'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ForgeMarkdown>(find.byType(ForgeMarkdown)).data,
        source,
      );
      expect(find.widgetWithText(TextField, 'README：目标、用法与参与方式'), findsNothing);
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.widgetWithText(TextField, 'README：目标、用法与参与方式'),
            )
            .controller!
            .text,
        source,
      );
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(repo.rows.single.getStringValue('readme'), source);
      expect(repo.rows.single.getStringValue('name'), 'Markdown 项目');
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
