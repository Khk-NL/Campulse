/// Widget 冒烟测试 / a widget smoke test.
///
/// 本轮界面结构改成了 **4 Tab**：首页 / 应用 / 课程 / 我的，`搜索` 与 `通知` 从底部栏
/// 移到顶部栏（AppBar actions）并成为**推入的路由页**。这个测试就是新结构的验收：
///
///   1. 底部栏**只有**4 个 Tab，旧的 `搜索` / `事务` 不再出现在导航里；
///   2. 顶部栏的两个入口真的能打开搜索页与通知页（并且能返回）；
///   3. 课程表页面能渲染出教学周与课程；
///   4. 「我的」仍能看到语言切换（§0.8）。
///
/// The interface is now **four tabs** (Home / Apps / Courses / Profile), with `Search` and
/// `Notifications` moved into the AppBar as **pushed routes**. This test is the acceptance
/// for that: the bottom bar holds exactly four tabs and no longer offers Search or Inbox;
/// both top-bar entries really open their screens and come back; the timetable renders a
/// teaching week and courses; Profile still exposes the language switcher (§0.8).
///
/// 全部使用内存仓库，因此测试不需要后端，也不会碰网络。
/// Everything uses the in-memory repository, so no backend and no network are involved.
library;

import 'package:campus_mobile/core/app_scope_repository.dart';
import 'package:campus_mobile/core/app_startup.dart';
import 'package:campus_mobile/core/app_state.dart';
import 'package:campus_mobile/core/config/app_config.dart';
import 'package:campus_mobile/core/config/preference_store.dart';
import 'package:campus_mobile/core/locale_resolution.dart';
import 'package:campus_mobile/core/theme/campus_theme.dart';

import 'fixtures/in_memory_campus_repository.dart';

import 'package:campus_mobile/features/inbox/inbox_page.dart';
import 'package:campus_mobile/features/search/search_page.dart';
import 'package:campus_mobile/features/study/course_hub_page.dart';
import 'package:campus_mobile/features/study/study_page.dart';
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
          home: const AppShell(),
        ),
      ),
    );
  }

  testWidgets('课程列表与课程表平级切换，智能体留在课程内', (tester) async {
    final state = await buildState();
    await tester.pumpWidget(wrap(state));
    await tester.pumpAndSettle();
    await tester.tap(find.text('课程').last);
    await tester.pumpAndSettle();
    expect(find.text('课程列表'), findsOneWidget);
    expect(find.text('按智能体'), findsNothing);
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
      '首页',
    );

    await state.setLocale(const Locale('en'));
    await tester.pumpAndSettle();
    expect(
      (navigation().destinations.first as NavigationDestination).label,
      'Home',
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

    expect(find.text(l10n.navHome), findsWidgets);
    expect(find.text(l10n.navStore), findsWidgets);
    expect(find.text(l10n.navTimetable), findsWidgets);
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

  testWidgets('顶部栏的通知与搜索入口可用 / the top bar opens notifications and search', (
    WidgetTester tester,
  ) async {
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
    expect(find.byType(SearchPage), findsOneWidget);
    expect(find.text(l10n.searchTitle), findsWidgets);

    // 返回后再打开通知页。用 Navigator 直接 pop，避免依赖平台相关的返回按钮实现。
    // Go back, then open the notification screen. Popping the Navigator directly avoids
    // depending on a platform-specific back button implementation.
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(find.byType(SearchPage), findsNothing);

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

    await tester.tap(find.text(l10n.navTimetable).last);
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
  testWidgets('课程列表和课表详情通向同一课程空间', (WidgetTester tester) async {
    final AppState state = await buildState();
    await tester.pumpWidget(wrap(state));
    await tester.pumpAndSettle();

    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(NavigationBar)),
    );
    await tester.tap(find.text(l10n.navTimetable).last);
    await tester.pumpAndSettle();
    expect(find.text('我的课程'), findsOneWidget);
    expect(find.textContaining('演示课程'), findsWidgets);
    expect(find.text('演示课程 · 未同步'), findsNothing);
    final Finder courseInHub = find.descendant(
      of: find.byType(CourseHubPage),
      matching: find.text('现代软件工程'),
    );
    await tester.ensureVisible(courseInHub);
    await tester.pumpAndSettle();
    await tester.tap(courseInHub);
    await tester.pumpAndSettle();
    expect(find.byType(StudyPage), findsOneWidget);
    expect(find.text('现代软件工程'), findsWidgets);
    await tester.tap(find.text('提问'));
    await tester.pumpAndSettle();
    expect(find.text('围绕这门课继续探究'), findsOneWidget);
    expect(find.text('引用范围 · 已选 0 份资料'), findsOneWidget);
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
    await tester.tap(find.text('进入课程空间'));
    await tester.pumpAndSettle();
    expect(find.text('现代软件工程'), findsWidgets);
    state.dispose();
  });
}
