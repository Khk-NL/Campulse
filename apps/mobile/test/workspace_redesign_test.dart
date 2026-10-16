import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:campus_mobile/core/app_state.dart';
import 'package:campus_mobile/core/app_scope_repository.dart';
import 'package:campus_mobile/core/config/app_config.dart';
import 'package:campus_mobile/core/config/preference_store.dart';
import 'package:campus_mobile/core/theme/campus_theme.dart';
import 'package:campus_mobile/features/shell/app_shell.dart';
import 'package:campus_mobile/features/community/community_page.dart';
import 'package:campus_mobile/features/community/community_repository.dart';
import 'package:campus_mobile/features/study/course_notebook_view.dart';
import 'package:campus_mobile/features/study/study_repository.dart';
import 'package:campus_mobile/data/models/course.dart';
import 'package:campus_mobile/l10n/app_localizations.dart';

import 'fixtures/in_memory_campus_repository.dart';

ResultList<RecordModel> result(List<RecordModel> rows) => ResultList(
  page: 1,
  perPage: 20,
  totalItems: rows.length,
  totalPages: 1,
  items: rows,
);
RecordModel record(String id, Map<String, dynamic> body) =>
    RecordModel.fromJson({'id': id, ...body});

class FakeCommunity extends CommunityRepository {
  FakeCommunity() : super(PocketBase('http://127.0.0.1'));
  @override
  String userId = 'member';
  @override
  bool get canParticipate => true;
  final entries = <RecordModel>[
    record('activity', {
      'owner': 'host',
      'title': '周末羽毛球',
      'body': '一起练球',
      'displayName': '小夏',
      'kind': 'sport',
      'campus': 'minhang',
      'location': '体育馆',
      'tags': '羽毛球',
      'status': 'open',
    }),
  ];
  final registrations = <RecordModel>[];
  final messages = <RecordModel>[];
  RecordModel? profile;
  String? lastKind;
  @override
  Future<ResultList<RecordModel>> posts({
    int page = 1,
    String? kind,
    String? campus,
    String query = '',
    String scope = 'all',
  }) async {
    lastKind = kind;
    return result(
      entries
          .where(
            (p) =>
                (kind == null || p.getStringValue('kind') == kind) &&
                (campus == null || p.getStringValue('campus') == campus) &&
                p.getStringValue('title').contains(query) &&
                (scope != 'mine' || p.getStringValue('owner') == userId) &&
                (scope != 'joined' ||
                    registrations.any((r) => r.getStringValue('post') == p.id)),
          )
          .toList(),
    );
  }

  @override
  Future<RecordModel> publish(Map<String, dynamic> fields) async {
    final p = record('new-activity', {
      ...fields,
      'owner': userId,
      'status': 'open',
    });
    entries.insert(0, p);
    return p;
  }

  @override
  Future<RecordModel> post(String id) async =>
      entries.firstWhere((r) => r.id == id);
  @override
  Future<RecordModel> updatePost(String id, Map<String, dynamic> fields) async {
    final index = entries.indexWhere((r) => r.id == id);
    return entries[index] = record(id, {...entries[index].data, ...fields});
  }

  @override
  Future<void> setStatus(String id, String status) async {
    await updatePost(id, {'status': status});
  }

  @override
  Future<List<RecordModel>> interests(String post) async =>
      List.of(registrations);
  @override
  Future<ResultList<RecordModel>> replies(String post, {int page = 1}) async =>
      result(List.of(messages));
  @override
  Future<RecordModel> join(String post, String name, String message) async {
    final row = record('registration', {
      'post': post,
      'owner': userId,
      'displayName': name,
      'message': message,
    });
    registrations.add(row);
    return row;
  }

  @override
  Future<void> leave(String id) async =>
      registrations.removeWhere((r) => r.id == id);
  @override
  Future<RecordModel> reply(String post, String name, String body) async {
    final row = record('reply', {
      'post': post,
      'owner': userId,
      'displayName': name,
      'body': body,
    });
    messages.add(row);
    return row;
  }

  @override
  Future<ResultList<RecordModel>> profiles({
    int page = 1,
    String query = '',
  }) async =>
      result(profile?.getBoolValue('published') == true ? [profile!] : []);
  @override
  Future<RecordModel?> myProfile() async => profile;
  @override
  Future<RecordModel> saveProfile(
    String? id,
    Map<String, dynamic> fields,
  ) async => profile = record('card', {...fields, 'owner': userId});
}

Future<AppState> state() async {
  SharedPreferences.setMockInitialValues({});
  final state = AppState(
    repository: InMemoryCampusRepository(),
    config: AppConfig.defaults(),
    preferences: PreferenceStore(await SharedPreferences.getInstance()),
    initialLocale: const Locale('zh'),
    initialThemeMode: ThemeMode.light,
  );
  await state.loadIdentity();
  return state;
}

Widget wrap(AppState state, Widget child) => AppScope(
  state: state,
  child: CampusRepositoryScope(
    repository: state.repository,
    child: MaterialApp(
      locale: const Locale('zh'),
      theme: CampusTheme.light(),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: child,
    ),
  ),
);

void main() {
  testWidgets(
    'desktop notebook presents sources, questions and studio together',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        wrap(
          await state(),
          Scaffold(
            body: CourseNotebookView(
              course: const Course(
                id: 'test',
                universityId: 'ecnu',
                name: '课程验收',
                teacher: '',
                location: '',
                startWeek: 1,
                endWeek: 16,
              ),
              workspace: StudyWorkspace.empty(),
              notes: const [],
              remote: false,
              onAddSource: () {},
              onAddKnowledgeBase: () {},
              onOpenNotes: () {},
              onOpenCards: () {},
              onSubmitQuestion: (_, _) async => true,
              onOpenSession: (_) {},
              onAddActivity: () {},
              onOpenActivity: (_) {},
              onAddAgent: () {},
              onSaveActivity: (_) async => true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('我的资料'), findsOneWidget);
      expect(find.text('围绕这门课继续探究'), findsOneWidget);
      expect(find.text('学习工作台'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('课程计划'));
      await tester.pumpAndSettle();
      expect(find.text('我的资料'), findsNothing);
      await tester.tap(find.text('学习空间'));
      await tester.pumpAndSettle();
      expect(find.text('我的资料'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'desktop rail, keyboard navigation, course pins and narrow-window state',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1400, 1000);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final app = await state();
      await tester.pumpWidget(wrap(app, const AppShell()));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<NavigationRail>(find.byType(NavigationRail))
            .selectedIndex,
        2,
      );
      await tester.enterText(
        find.widgetWithText(TextField, '搜索课程、教师或教室'),
        '现代软件',
      );
      await tester.pumpAndSettle();
      expect(find.text('现代软件工程'), findsOneWidget);
      expect(find.text('大学英语'), findsNothing);
      await tester.tap(find.byTooltip('置顶课程').last);
      await tester.pumpAndSettle();
      expect(app.favorites.keysOf('courses'), isNotEmpty);
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsNothing);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        2,
      );
      expect(find.text('现代软件工程'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('campus square filters types and publishes an actual row', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(500, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeCommunity();
    await tester.pumpWidget(
      wrap(await state(), Scaffold(body: CommunityPage(repository: repo))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('竞赛组队'));
    await tester.pumpAndSettle();
    expect(repo.lastKind, 'competition');
    expect(find.text('周末羽毛球'), findsNothing);
    await tester.tap(find.text('发布召集'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, '标题'), '数学建模招募');
    await tester.enterText(
      find.widgetWithText(TextFormField, '介绍、分工与参加方式'),
      '寻找建模与编程搭档',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(repo.entries.first.getStringValue('title'), '数学建模招募');
    expect(find.text('数学建模招募'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('join, discussion and withdrawal refresh the detail page', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeCommunity();
    await tester.pumpWidget(
      wrap(await state(), CommunityPostPage(repository: repo, id: 'activity')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('我想参加'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, '给发起人的留言'),
      '周六下午可以',
    );
    await tester.tap(find.text('提交'));
    await tester.pumpAndSettle();
    expect(repo.registrations.single.getStringValue('message'), '周六下午可以');
    expect(find.text('退出报名'), findsOneWidget);
    await tester.tap(find.text('参与讨论'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, '讨论内容'),
      '我会带羽毛球',
    );
    await tester.tap(find.text('提交'));
    await tester.pumpAndSettle();
    expect(find.text('我会带羽毛球'), findsOneWidget);
    await tester.tap(find.text('退出报名'));
    await tester.pumpAndSettle();
    expect(repo.registrations, isEmpty);
    expect(find.text('我想参加'), findsOneWidget);
  });

  testWidgets('host can edit, close and reopen a gathering', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 1200);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repo = FakeCommunity()..userId = 'host';
    await tester.pumpWidget(
      wrap(await state(), CommunityPostPage(repository: repo, id: 'activity')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑召集'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, '标题'), '周日羽毛球');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('周日羽毛球'), findsOneWidget);
    await tester.tap(find.text('结束召集'));
    await tester.pumpAndSettle();
    expect(find.text('参与讨论'), findsNothing);
    expect(find.text('重新开放'), findsOneWidget);
    await tester.tap(find.text('重新开放'));
    await tester.pumpAndSettle();
    expect(find.text('参与讨论'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('interest cards are opt-in and can be withdrawn', (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FakeCommunity();
    await tester.pumpWidget(
      wrap(await state(), Scaffold(body: CommunityPage(repository: repo))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('兴趣名片'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑我的名片'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, '关于自己'),
      '喜欢羽毛球和读书',
    );
    await tester.tap(find.text('在兴趣名片中展示'));
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(repo.profile!.getBoolValue('published'), isTrue);
    expect(find.text('喜欢羽毛球和读书'), findsOneWidget);
    await tester.tap(find.text('编辑我的名片'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('在兴趣名片中展示'));
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(repo.profile!.getBoolValue('published'), isFalse);
    expect(find.text('喜欢羽毛球和读书'), findsNothing);
  });

  test(
    'SDK queries preserve school, type, campus and pagination scope',
    () async {
      final uris = <Uri>[];
      final repo = CommunityRepository(
        PocketBase(
          'http://127.0.0.1',
          httpClientFactory: () => MockClient((r) async {
            uris.add(r.url);
            return http.Response(
              jsonEncode({
                'page': 2,
                'perPage': 20,
                'totalItems': 0,
                'totalPages': 0,
                'items': [],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );
      await repo.posts(
        page: 2,
        kind: 'sport',
        campus: 'minhang',
        query: '羽毛球" || owner = ""',
      );
      final filter = uris.single.queryParameters['filter']!;
      expect(filter, contains('universityId = "ecnu"'));
      expect(filter, contains('kind = "sport"'));
      expect(filter, contains('campus = "minhang"'));
      expect(filter, contains(r'羽毛球\" || owner = \"\"'));
      expect(uris.single.queryParameters['page'], '2');
    },
  );
}
