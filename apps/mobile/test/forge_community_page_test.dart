import 'package:campus_mobile/features/apps/forge_community_page.dart';
import 'package:campus_mobile/features/apps/forge_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';

RecordModel _project(int index) => RecordModel.fromJson({
  'id': 'project$index',
  'name': '校园工具 $index',
  'summary': '一起来改善校园体验',
  'topics': 'Flutter, 校园',
  'owner': 'author$index',
});

RecordModel _thread(int index, {String kind = 'question'}) =>
    RecordModel.fromJson({
      'id': 'thread$index',
      'repository': 'project$index',
      'owner': index == 1 ? 'author1' : 'member',
      'title': '缓存问题 $index',
      'body': '分享 **缓存** 的处理经验，欢迎讨论。',
      'kind': kind,
      'status': 'open',
      'created': '2026-10-21 08:00:00.000Z',
      'expand': {'repository': _project(index).toJson()},
    });

typedef _FeedCall = ({
  int page,
  String query,
  String? kind,
  String? status,
  bool starred,
  String sort,
});

class _CommunityForge extends ForgeRepository {
  _CommunityForge({this.guest = false})
    : super(PocketBase('https://example.test'));

  final bool guest;
  bool fail = false, failProjects = false;
  final calls = <_FeedCall>[];
  final projectCalls = <({int page, String query, bool mine})>[];
  final threads = [_thread(1), _thread(2), _thread(3)];
  final projectsData = [_project(1), _project(2), _project(3)];

  @override
  String get userId => guest ? '' : 'member';

  @override
  bool get canWrite => !guest;

  ResultList<RecordModel> _paged(List<RecordModel> rows, int page) =>
      ResultList(
        items: rows.skip((page - 1) * 2).take(2).toList(),
        page: page,
        perPage: 2,
        totalItems: rows.length,
        totalPages: (rows.length / 2).ceil(),
      );

  @override
  Future<ResultList<RecordModel>> communityThreads({
    int page = 1,
    String query = '',
    String? kind,
    String? status,
    bool starred = false,
    String sort = 'created',
  }) async {
    calls.add((
      page: page,
      query: query,
      kind: kind,
      status: status,
      starred: starred,
      sort: sort,
    ));
    if (fail) throw StateError('network fixture');
    return _paged(
      threads
          .where((row) => kind == null || row.getStringValue('kind') == kind)
          .toList(),
      page,
    );
  }

  @override
  Future<ResultList<RecordModel>> projects({
    int page = 1,
    String query = '',
    bool mine = false,
    String sort = 'updated',
    bool starred = false,
  }) async {
    projectCalls.add((page: page, query: query, mine: mine));
    if (failProjects) throw StateError('project network fixture');
    return _paged(
      projectsData
          .where((row) => row.getStringValue('name').contains(query))
          .toList(),
      page,
    );
  }
}

Future<void> _show(
  WidgetTester tester,
  _CommunityForge repo, {
  VoidCallback? onOpenAccount,
  Future<void> Function(RecordModel, RecordModel)? onOpenThread,
  Future<void> Function(RecordModel)? onOpenProject,
  Future<bool> Function(RecordModel, String)? onCompose,
  GlobalKey<NavigatorState>? navigatorKey,
  Size size = const Size(900, 1400),
  double scale = 1,
  bool reduceMotion = false,
  double keyboard = 0,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: reduceMotion,
          viewInsets: EdgeInsets.only(bottom: keyboard),
        ),
        child: child!,
      ),
      home: ForgeCommunityPage(
        repository: repo,
        onOpenAccount: onOpenAccount,
        onOpenThread: onOpenThread ?? (_, _) async {},
        onOpenProject: onOpenProject ?? (_) async {},
        onCompose: onCompose ?? (_, _) async => false,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('pushed community routes show a working back button', (
    tester,
  ) async {
    final repo = _CommunityForge();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('校园首页')),
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => ForgeCommunityPage(
                    repository: repo,
                    onOpenThread: (_, _) async {},
                    onOpenProject: (_) async {},
                    onCompose: (_, _) async => false,
                  ),
                ),
              ),
              child: const Text('进入社区'),
            ),
          ),
        ),
      ),
    );
    await _tap(tester, find.text('进入社区'));
    expect(find.widgetWithText(AppBar, '社区交流'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    await _tap(tester, find.byType(BackButton));
    expect(find.text('校园首页'), findsOneWidget);
    expect(find.byType(ForgeCommunityPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'channels request their server kind and selected chips have no tick',
    (tester) async {
      final repo = _CommunityForge();
      await _show(tester, repo);
      expect(repo.calls.single.kind, isNull);
      expect(find.text('项目作者'), findsOneWidget);
      expect(find.text('社区成员'), findsOneWidget);
      expect(find.text('校园工具 1'), findsOneWidget);
      expect(find.text('分享 缓存 的处理经验，欢迎讨论。'), findsNWidgets(2));
      for (final entry in {
        '技术问答': 'question',
        '经验与建议': 'idea',
        '项目动态': 'update',
        '问题反馈': 'bug',
        '全部': null,
      }.entries) {
        await _tap(tester, find.widgetWithText(ChoiceChip, entry.key));
        expect(repo.calls.last.kind, entry.value);
        expect(repo.calls.last.page, 1);
      }
      for (final chip in tester.widgetList<ChoiceChip>(
        find.byType(ChoiceChip),
      )) {
        expect(chip.showCheckmark, isFalse);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('search, channel, favorites and ordering are sent together', (
    tester,
  ) async {
    final repo = _CommunityForge();
    await _show(tester, repo);
    await _tap(tester, find.widgetWithText(ChoiceChip, '经验与建议'));
    await tester.enterText(find.widgetWithText(TextField, '搜索交流'), ' 缓存 ');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await _tap(tester, find.widgetWithText(FilterChip, '收藏的项目'));
    await _tap(tester, find.byTooltip('交流排序'));
    await _tap(tester, find.text('最近更新').last);
    expect(repo.calls.last, (
      page: 1,
      query: '缓存',
      kind: 'idea',
      status: null,
      starred: true,
      sort: 'updated',
    ));
    await _tap(tester, find.byTooltip('清空搜索'));
    expect(repo.calls.last.query, isEmpty);
    expect(repo.calls.last.starred, isTrue);
    expect(repo.calls.last.sort, 'updated');
    expect(tester.takeException(), isNull);
  });

  testWidgets('immediate pagination and refresh apply pending feed searches', (
    tester,
  ) async {
    final repo = _CommunityForge();
    await _show(tester, repo);
    await tester.enterText(find.widgetWithText(TextField, '搜索交流'), ' 缓存 ');
    final beforePage = repo.calls.length;
    await _tap(tester, find.byTooltip('下一页'));
    expect(repo.calls.length, beforePage + 1);
    expect(repo.calls.last.query, '缓存');
    expect(repo.calls.last.page, 1);

    await _tap(tester, find.byTooltip('下一页'));
    expect(repo.calls.last.page, 2);
    await tester.enterText(find.widgetWithText(TextField, '搜索交流'), '新查询');
    final beforeRefresh = repo.calls.length;
    await _tap(tester, find.byTooltip('刷新交流'));
    expect(repo.calls.length, beforeRefresh + 1);
    expect(repo.calls.last.query, '新查询');
    expect(repo.calls.last.page, 1);
    await tester.pump(const Duration(milliseconds: 350));
    expect(repo.calls.length, beforeRefresh + 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'server pages open the expanded project and refresh after returning',
    (tester) async {
      final repo = _CommunityForge();
      final navigator = GlobalKey<NavigatorState>();
      String? openedThread, openedProject;
      await _show(
        tester,
        repo,
        navigatorKey: navigator,
        onOpenThread: (thread, project) async {
          openedThread = thread.id;
          openedProject = project.id;
          await navigator.currentState!.push<void>(
            MaterialPageRoute(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('返回社区'),
                ),
              ),
            ),
          );
        },
      );
      await _tap(tester, find.widgetWithText(ChoiceChip, '技术问答'));
      await tester.enterText(find.widgetWithText(TextField, '搜索交流'), '缓存');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await _tap(tester, find.widgetWithText(FilterChip, '收藏的项目'));
      await _tap(tester, find.byTooltip('下一页'));
      expect(repo.calls.last.page, 2);
      expect(find.text('缓存问题 1'), findsNothing);
      await _tap(tester, find.text('缓存问题 3'));
      expect(openedThread, 'thread3');
      expect(openedProject, 'project3');
      final count = repo.calls.length;
      await _tap(tester, find.text('返回社区'));
      expect(repo.calls.length, count + 1);
      expect(repo.calls.last, (
        page: 1,
        query: '缓存',
        kind: 'question',
        status: null,
        starred: true,
        sort: 'created',
      ));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'project sources use their own open callback and refresh the feed',
    (tester) async {
      final repo = _CommunityForge();
      String? projectId;
      await _show(
        tester,
        repo,
        onOpenProject: (project) async {
          projectId = project.id;
        },
      );
      final before = repo.calls.length;
      await _tap(tester, find.text('校园工具 1'));
      expect(projectId, 'project1');
      expect(repo.calls.length, before + 1);
    },
  );

  testWidgets(
    'guests get login actions and never load a personal feed or picker',
    (tester) async {
      final repo = _CommunityForge(guest: true);
      var accounts = 0;
      await _show(tester, repo, onOpenAccount: () => accounts++);
      await _tap(tester, find.widgetWithText(FilledButton, '发起交流'));
      expect(accounts, 1);
      expect(repo.projectCalls, isEmpty);
      await _tap(tester, find.widgetWithText(FilterChip, '收藏的项目'));
      expect(repo.calls.length, 1);
      expect(find.text('登录查看收藏项目的交流'), findsOneWidget);
      await _tap(tester, find.text('登录账号'));
      expect(accounts, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'guest without an account route sees a usable login explanation',
    (tester) async {
      await _show(tester, _CommunityForge(guest: true));
      await _tap(tester, find.widgetWithText(FilledButton, '发起交流'));
      expect(find.text('登录并验证邮箱后，就能发起交流、关注收藏的项目'), findsOneWidget);
    },
  );

  testWidgets(
    'project picker searches and pages before composing in the channel',
    (tester) async {
      final repo = _CommunityForge();
      String? projectId, initialKind;
      await _show(
        tester,
        repo,
        onCompose: (project, kind) async {
          projectId = project.id;
          initialKind = kind;
          return true;
        },
      );
      await _tap(tester, find.widgetWithText(ChoiceChip, '项目动态'));
      await _tap(tester, find.widgetWithText(FilledButton, '发起交流'));
      expect(find.text('选择交流的项目'), findsOneWidget);
      expect(repo.projectCalls.last.mine, isFalse);
      await tester.enterText(find.widgetWithText(TextField, '搜索项目'), '校园');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(repo.projectCalls.last.query, '校园');
      await _tap(tester, find.byTooltip('下一页'));
      expect(repo.projectCalls.last.page, 2);
      final before = repo.calls.length;
      await _tap(tester, find.text('校园工具 3'));
      expect(projectId, 'project3');
      expect(initialKind, 'update');
      expect(find.text('选择交流的项目'), findsNothing);
      expect(repo.calls.length, before + 1);
      expect(repo.calls.last.kind, 'update');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('feed failure is visible and its retry fetches fresh data', (
    tester,
  ) async {
    final repo = _CommunityForge()..fail = true;
    await _show(tester, repo);
    expect(find.text('交流加载遇到问题'), findsOneWidget);
    repo.fail = false;
    await _tap(tester, find.text('重新加载'));
    expect(repo.calls.length, 2);
    expect(find.text('缓存问题 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('picker pagination and retry apply pending project searches', (
    tester,
  ) async {
    final repo = _CommunityForge();
    await _show(tester, repo);
    await _tap(tester, find.widgetWithText(ChoiceChip, '项目动态'));
    await _tap(tester, find.widgetWithText(FilledButton, '发起交流'));
    await tester.enterText(find.widgetWithText(TextField, '搜索项目'), '校园');
    final beforePage = repo.projectCalls.length;
    await _tap(tester, find.byTooltip('下一页'));
    expect(repo.projectCalls.length, beforePage + 1);
    expect(repo.projectCalls.last, (page: 1, query: '校园', mine: false));

    await _tap(tester, find.byTooltip('下一页'));
    expect(repo.projectCalls.last.page, 2);
    await _tap(tester, find.byTooltip('关闭项目选择'));
    repo.failProjects = true;
    await _tap(tester, find.widgetWithText(FilledButton, '发起交流'));
    await tester.enterText(find.widgetWithText(TextField, '搜索项目'), '校园工具');
    repo.failProjects = false;
    final beforeRetry = repo.projectCalls.length;
    await _tap(tester, find.text('项目加载失败，点击重试'));
    expect(repo.projectCalls.length, beforeRetry + 1);
    expect(repo.projectCalls.last, (page: 1, query: '校园工具', mine: false));
    await tester.pump(const Duration(milliseconds: 350));
    expect(repo.projectCalls.length, beforeRetry + 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('small screens retain large text controls with reduced motion', (
    tester,
  ) async {
    final repo = _CommunityForge();
    await _show(
      tester,
      repo,
      size: const Size(360, 640),
      scale: 1.8,
      reduceMotion: true,
    );
    await _tap(tester, find.widgetWithText(ChoiceChip, '问题反馈'));
    await _tap(tester, find.byTooltip('交流排序'));
    await _tap(tester, find.text('最近更新').last);
    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, '发起交流'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await _tap(tester, find.widgetWithText(FilledButton, '发起交流'));
    await _tap(tester, find.text('校园工具 1'));
    expect(repo.calls.last.kind, 'bug');
    expect(repo.calls.last.sort, 'updated');
    expect(tester.takeException(), isNull);
  });
}
