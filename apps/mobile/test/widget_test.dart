/// 项目优先导航、校园辅助工具与个性化设置的组件验收。
library;

import 'package:campus_mobile/core/app_scope_repository.dart';
import 'package:campus_mobile/core/app_startup.dart';
import 'package:campus_mobile/core/app_state.dart';
import 'package:campus_mobile/core/config/app_config.dart';
import 'package:campus_mobile/core/config/preference_store.dart';
import 'package:campus_mobile/core/locale_resolution.dart';
import 'package:campus_mobile/core/theme/campus_theme.dart';

import 'fixtures/in_memory_campus_repository.dart';
import 'fixtures/project_focus_repository.dart';

import 'package:campus_mobile/features/inbox/inbox_page.dart';
import 'package:campus_mobile/features/apps/forge_page.dart';
import 'package:campus_mobile/features/study/course_hub_page.dart';
import 'package:campus_mobile/features/profile/profile_page.dart';
import 'package:campus_mobile/features/shell/app_shell.dart';
import 'package:campus_mobile/features/timetable/timetable_page.dart';
import 'package:campus_mobile/l10n/app_localizations.dart';
import 'package:campus_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  /// 用内存仓库装配一个应用状态 / assemble an app state on the in-memory repository.
  Future<AppState> buildState() async {
    // 测试环境没有 platform 实现，用 mock 初值装一个可用的内存存储。
    // The test environment has no platform implementation, so mock initial values
    // install a usable in-memory store.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final PreferenceStore preferences = PreferenceStore(
      await SharedPreferences.getInstance(),
    );
    return AppState(
      repository: InMemoryCampusRepository(),
      config: AppConfig.defaults(),
      preferences: preferences,
      initialLocale: const Locale('zh'),
      initialThemeMode: ThemeMode.system,
    );
  }

  Widget wrap(AppState state) {
    return AppScope(
      state: state,
      child: CampusRepositoryScope(
        repository: state.repository,
        child: MaterialApp(
          theme: CampusTheme.light(),
          locale: state.locale,
          localeResolutionCallback: resolveSupportedLocale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: AppShell(forgeRepository: ProjectFocusRepository()),
        ),
      ),
    );
  }

  testWidgets('校园入口保留课程列表与课表切换', (tester) async {
    final state = await buildState();
    await tester.pumpWidget(wrap(state));
    await tester.pumpAndSettle();
    await tester.tap(find.text('校园').last);
    await tester.pumpAndSettle();
    expect(find.text('课程列表'), findsOneWidget);
    expect(find.text('按智能体'), findsNothing);
    expect(find.text('我的计划'), findsNothing);
    expect(find.text('资料 · 提问 · 复习'), findsNothing);
    await tester.tap(find.text('课程表'));
    await tester.pumpAndSettle();
    expect(find.byType(TimetablePage), findsOneWidget);
    await tester.tap(find.text('课程列表'));
    await tester.pumpAndSettle();
    expect(find.byType(TimetablePage), findsNothing);
    state.dispose();
  });

  testWidgets('我的默认折叠设置与关于，昵称编辑后立即显示', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final state = await buildState();
    await tester.pumpWidget(wrap(state));
    await tester.pumpAndSettle();
    await tester.tap(find.text('我的').last);
    await tester.pumpAndSettle();
    final tiles = tester.widgetList<ExpansionTile>(find.byType(ExpansionTile));
    expect(tiles.length, 2);
    expect(tiles.every((tile) => !tile.initiallyExpanded), isTrue);
    expect(find.text('我的学习'), findsNothing);
    expect(find.text('计划与归档'), findsNothing);
    await tester.tap(find.byTooltip('个性化'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '小夏');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(state.displayName, '小夏');
    expect(find.text('小夏'), findsOneWidget);
    expect(tester.takeException(), isNull);
    state.dispose();
  });

  testWidgets('根应用响应语言与主题切换', (WidgetTester tester) async {
    final AppState state = await buildState();
    await tester.pumpWidget(
      CampusApp(
        bootstrap: AppBootstrap(state: state, config: state.config),
      ),
    );
    await tester.pumpAndSettle();

    NavigationBar navigation() =>
        tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(
      (navigation().destinations.first as NavigationDestination).label,
      '探索',
    );

    await state.setLocale(const Locale('en'));
    await tester.pumpAndSettle();
    expect(
      (navigation().destinations.first as NavigationDestination).label,
      'Explore',
    );

    await state.setThemeMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    state.dispose();
  });

  testWidgets('底部栏只有 4 个 Tab / the bottom bar holds exactly four tabs', (
    WidgetTester tester,
  ) async {
    final AppState state = await buildState();
    await tester.pumpWidget(wrap(state));
    await tester.pumpAndSettle();

    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(NavigationBar)),
    );

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      tester
          .widget<NavigationBar>(find.byType(NavigationBar))
          .destinations
          .length,
      4,
      reason: '底部栏必须有且仅有 4 个 Tab',
    );

    expect(find.text(l10n.navExplore), findsWidgets);
    expect(find.text(l10n.navRepositories), findsWidgets);
    expect(find.text(l10n.navCampus), findsWidgets);
    expect(find.text(l10n.navProfile), findsWidgets);

    // 旧的「搜索」「事务」不再占据底部栏位置。
    // The old Search and Inbox no longer occupy bottom-bar slots.
    final List<NavigationDestination> destinations = tester
        .widget<NavigationBar>(find.byType(NavigationBar))
        .destinations
        .whereType<NavigationDestination>()
        .toList();
    expect(
      destinations.where(
        (NavigationDestination destination) =>
            destination.label == l10n.navSearch ||
            destination.label == l10n.navInbox,
      ),
      isEmpty,
      reason: '搜索与事务应从底部栏移除',
    );

    // 切到「我的」，应能看到语言切换入口（§0.8）。
    // Switch to Profile and expect the language switcher (§0.8).
    await tester.tap(find.text(l10n.navProfile).last);
    await tester.pumpAndSettle();
    expect(find.text(l10n.profileLanguage), findsNothing);
    await tester.scrollUntilVisible(
      find.text(l10n.profileSettings),
      250,
      scrollable: find
          .descendant(
            of: find.byType(ProfilePage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text(l10n.profileSettings));
    await tester.pumpAndSettle();
    expect(find.text(l10n.profileLanguage), findsWidgets);

    state.dispose();
  });

  testWidgets('顶部栏聚焦项目搜索并可打开通知', (WidgetTester tester) async {
    final AppState state = await buildState();
    await tester.pumpWidget(wrap(state));
    await tester.pumpAndSettle();

    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(NavigationBar)),
    );

    // 顶部栏的图标入口以 tooltip 标识，因此用 tooltip 找按钮。
    // The top-bar entries are identified by tooltip, so look the buttons up that way.
    expect(find.byTooltip(l10n.navNotification), findsOneWidget);
    expect(find.byTooltip(l10n.navSearch), findsOneWidget);

    await tester.tap(find.byTooltip(l10n.navSearch));
    await tester.pumpAndSettle();
    expect(find.byType(ForgePage), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, '搜索项目'))
          .focusNode!
          .hasFocus,
      isTrue,
    );

    await tester.tap(find.byTooltip(l10n.navNotification));
    await tester.pumpAndSettle();
    expect(find.byType(InboxPage), findsOneWidget);
    expect(find.text(l10n.navNotification), findsWidgets);

    state.dispose();
  });

  testWidgets('课程表页面能渲染 / the timetable screen renders', (
    WidgetTester tester,
  ) async {
    final AppState state = await buildState();
    await tester.pumpWidget(wrap(state));
    await tester.pumpAndSettle();

    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(NavigationBar)),
    );

    await tester.tap(find.text(l10n.navCampus).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('打开课程表'));
    await tester.pumpAndSettle();

    expect(find.byType(TimetablePage), findsOneWidget);
    // 顶部栏标题随 Tab 变化。
    // The top-bar title follows the active tab.
    expect(find.text(l10n.timetableTitle), findsWidgets);
    // 学期起止未核实，界面必须标注出来（演示锚点不能被当成真实学期）。
    // The term's boundaries are unverified and the UI must say so: a demo anchor must never be
    // presented as a real term.
    expect(find.text(l10n.timetableTermUnverified), findsOneWidget);

    // 演示锚点把"今天"放在第 4 教学周（双周），于是：
    //   * 双周课「大学英语」在网格上；
    //   * 单周课「移动应用开发」不在。
    // 这两条一起才证明**单双周真的在起作用**——只断言"有一门课出现了"的话，
    // parity 完全失效时它照样通过（这正是本仓库踩过的"断言碰巧成立"）。
    //
    // The demo anchor places today in teaching week 4 (even), so the even-week course is on the
    // grid and the odd-week one is not. Both assertions together are what proves parity works; a
    // single "some course is there" check would also pass with parity disabled.
    expect(find.text('大学英语'), findsWidgets);
    expect(find.text('移动应用开发'), findsNothing);

    // 退到第 3 周（单周）：两门课互换。
    // Back to week 3 (odd): the two courses swap.
    await tester.tap(find.byTooltip(l10n.timetablePreviousWeek));
    await tester.pumpAndSettle();
    expect(find.text('移动应用开发'), findsWidgets);
    expect(find.text('大学英语'), findsNothing);

    // 自定义周同样生效：「现代软件工程」在第 1-6 周上课，第 3 周在，第 7 周不在。
    // Custom weeks work too: 现代软件工程 meets in weeks 1-6, so it is present in week 3 and
    // absent in week 7.
    expect(find.text('现代软件工程'), findsWidgets);
    for (int i = 0; i < 4; i++) {
      await tester.tap(find.byTooltip(l10n.timetableNextWeek));
      await tester.pumpAndSettle();
    }
    expect(find.text('现代软件工程'), findsNothing);

    state.dispose();
  });
  testWidgets('课程列表与课表统一显示基础详情', (WidgetTester tester) async {
    final AppState state = await buildState();
    await tester.pumpWidget(wrap(state));
    await tester.pumpAndSettle();

    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(NavigationBar)),
    );
    await tester.tap(find.text(l10n.navCampus).last);
    await tester.pumpAndSettle();
    expect(find.text('我的课程'), findsOneWidget);
    final Finder courseInHub = find.descendant(
      of: find.byType(CourseHubPage),
      matching: find.text('现代软件工程'),
    );
    await tester.scrollUntilVisible(
      courseInHub,
      250,
      scrollable: find
          .descendant(
            of: find.byType(CourseHubPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('演示课程'), findsWidgets);
    await tester.tap(courseInHub);
    await tester.pumpAndSettle();
    expect(find.text('现代软件工程'), findsWidgets);
    expect(find.text(l10n.courseTeacherLabel), findsOneWidget);
    expect(find.text(l10n.courseWeeksLabel), findsOneWidget);
    expect(find.text('进入课程空间'), findsNothing);
    expect(find.text('引用范围 · 已选 0 份资料'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('打开课程表'),
      -250,
      scrollable: find
          .descendant(
            of: find.byType(CourseHubPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('打开课程表'));
    await tester.pumpAndSettle();
    expect(find.byType(TimetablePage), findsOneWidget);
    final Finder courseInTimetable = find.descendant(
      of: find.byType(TimetablePage),
      matching: find.text('现代软件工程'),
    );
    await tester.ensureVisible(courseInTimetable);
    await tester.pumpAndSettle();
    await tester.tap(courseInTimetable);
    await tester.pumpAndSettle();
    expect(find.text('现代软件工程'), findsWidgets);
    expect(find.text(l10n.courseTeacherLabel), findsOneWidget);
    expect(find.text(l10n.courseWeeksLabel), findsOneWidget);
    expect(find.text('进入课程空间'), findsNothing);
    state.dispose();
  });
}
