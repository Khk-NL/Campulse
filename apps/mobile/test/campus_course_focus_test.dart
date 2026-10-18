import 'package:campus_mobile/core/app_scope_repository.dart';
import 'package:campus_mobile/core/app_state.dart';
import 'package:campus_mobile/core/config/app_config.dart';
import 'package:campus_mobile/core/config/preference_store.dart';
import 'package:campus_mobile/core/theme/campus_theme.dart';
import 'package:campus_mobile/data/models/course.dart';
import 'package:campus_mobile/data/models/transaction.dart';
import 'package:campus_mobile/features/inbox/inbox_page.dart';
import 'package:campus_mobile/features/study/course_hub_page.dart';
import 'package:campus_mobile/features/timetable/timetable_page.dart';
import 'package:campus_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures/in_memory_campus_repository.dart';

class _CampusCourseRepository extends InMemoryCampusRepository {
  int noticeReads = 0;

  @override
  Future<List<Course>> fetchCourses() async => const [
    Course(
      id: 'campus-course',
      name: '软件工程',
      universityId: 'ecnu',
      teacher: '课程教师',
      location: '教学楼 203',
      startWeek: 1,
      endWeek: 18,
    ),
  ];

  @override
  Future<List<Announcement>> fetchAnnouncements() async {
    noticeReads++;
    return [
      Announcement(
        id: 'remote-notice',
        title: '课程安排更新',
        body: '本周课程地点调整到教学楼 203。',
        priority: AnnouncementPriority.high,
        publishedAt: DateTime(2026, 10, 19),
      ),
    ];
  }

  @override
  Future<List<CampusEvent>> fetchEvents() async => [];

  @override
  Future<List<CampusTask>> fetchTasks() async => [];
}

class _RefreshingCampusCourses extends _CampusCourseRepository {
  int revision = 0;
  int courseReads = 0;
  int taskReads = 0;
  int eventReads = 0;

  @override
  Future<List<Course>> fetchCourses() {
    courseReads++;
    return super.fetchCourses();
  }

  @override
  Future<List<Announcement>> fetchAnnouncements() async {
    noticeReads++;
    return [
      Announcement(
        id: 'refresh-notice',
        title: '软件工程课表通知 $revision',
        body: '软件工程的课程地点已更新。',
        priority: AnnouncementPriority.high,
        publishedAt: DateTime(2026, 10, 19),
      ),
    ];
  }

  @override
  Future<List<CampusTask>> fetchTasks() async {
    taskReads++;
    return [];
  }

  @override
  Future<List<CampusEvent>> fetchEvents() async {
    eventReads++;
    return [];
  }
}

void main() {
  Future<AppState> buildState({_CampusCourseRepository? repository}) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(
      repository: repository ?? _CampusCourseRepository(),
      config: AppConfig.defaults(),
      preferences: PreferenceStore(await SharedPreferences.getInstance()),
      initialLocale: const Locale('zh'),
      initialThemeMode: ThemeMode.light,
    );
    addTearDown(state.dispose);
    return state;
  }

  Widget wrap(AppState state, {int refreshToken = 0}) => AppScope(
    state: state,
    child: CampusRepositoryScope(
      repository: state.repository,
      child: MaterialApp(
        theme: CampusTheme.light(),
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(body: CourseHubPage(refreshToken: refreshToken)),
      ),
    ),
  );

  testWidgets('course entry presents campus essentials and basic details', (
    tester,
  ) async {
    final state = await buildState();
    await tester.pumpWidget(wrap(state));
    await tester.pumpAndSettle();
    expect(find.text('课程列表'), findsOneWidget);
    expect(find.text('导入课程'), findsOneWidget);
    expect(find.text('查看通知'), findsOneWidget);
    expect(find.text('我的计划'), findsNothing);
    expect(find.text('资料 · 提问 · 复习'), findsNothing);
    await tester.ensureVisible(find.text('软件工程'));
    await tester.tap(find.text('软件工程'));
    await tester.pumpAndSettle();
    expect(find.text('教学楼 203'), findsWidgets);
    expect(find.text('课程教师'), findsWidgets);
    expect(find.text('第 1–18 周'), findsOneWidget);
    expect(find.text('进入课程空间'), findsNothing);
    expect(find.text('我的资料'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('notices continue to load through the campus repository', (
    tester,
  ) async {
    final state = await buildState();
    await tester.pumpWidget(wrap(state));
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看通知'));
    await tester.pumpAndSettle();
    expect(find.byType(InboxPage), findsOneWidget);
    expect(find.text('课程安排更新'), findsOneWidget);
    expect((state.repository as _CampusCourseRepository).noticeReads, 1);
    await tester.tap(find.text('课程安排更新'));
    await tester.pumpAndSettle();
    expect(find.text('本周课程地点调整到教学楼 203。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('timetable and course pin interactions remain available', (
    tester,
  ) async {
    final state = await buildState();
    await tester.pumpWidget(wrap(state));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('置顶课程'));
    await tester.tap(find.byTooltip('置顶课程'));
    await tester.pumpAndSettle();
    expect(state.favorites.contains('courses', 'campus-course'), isTrue);
    await tester.scrollUntilVisible(
      find.text('课程表'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('课程表'));
    await tester.pumpAndSettle();
    expect(find.byType(TimetablePage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cloud refresh reloads the active timetable and retains its week',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(900, 2200);
      addTearDown(tester.view.reset);
      final repository = _RefreshingCampusCourses();
      final state = await buildState(repository: repository);
      await tester.pumpWidget(wrap(state));
      await tester.pumpAndSettle();
      await tester.tap(find.text('课程表'));
      await tester.pumpAndSettle();
      final timetable = tester.state(find.byType(TimetablePage));
      final l10n = AppLocalizations.of(
        tester.element(find.byType(TimetablePage)),
      );
      final nextWeek = find.byWidgetPredicate(
        (widget) =>
            widget is IconButton && widget.tooltip == l10n.timetableNextWeek,
      );
      final nextEnabled = tester.widget<IconButton>(nextWeek).onPressed != null;
      await tester.tap(
        nextEnabled ? nextWeek : find.byTooltip(l10n.timetablePreviousWeek),
      );
      await tester.pumpAndSettle();
      final week = tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data)
          .whereType<String>()
          .singleWhere((text) => RegExp(r'^第 \d+ 周$').hasMatch(text));
      expect(find.text('软件工程课表通知 0'), findsOneWidget);
      final courseReads = repository.courseReads;

      repository.revision = 1;
      await tester.pumpWidget(wrap(state));
      await tester.pumpAndSettle();
      expect(repository.courseReads, courseReads);
      expect(repository.noticeReads, 1);
      expect(find.text('软件工程课表通知 0'), findsOneWidget);

      await tester.pumpWidget(wrap(state, refreshToken: 1));
      await tester.pumpAndSettle();
      expect(repository.courseReads, courseReads + 2);
      expect(repository.noticeReads, 2);
      expect(repository.taskReads, 2);
      expect(repository.eventReads, 2);
      expect(find.text('软件工程课表通知 0'), findsNothing);
      expect(find.text('软件工程课表通知 1'), findsOneWidget);
      expect(find.text(week), findsOneWidget);
      expect(tester.state(find.byType(TimetablePage)), same(timetable));
      expect(tester.takeException(), isNull);
    },
  );
}
