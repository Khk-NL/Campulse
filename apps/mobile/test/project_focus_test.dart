import 'package:campus_mobile/core/app_scope_repository.dart';
import 'package:campus_mobile/core/app_state.dart';
import 'package:campus_mobile/core/config/app_config.dart';
import 'package:campus_mobile/core/config/preference_store.dart';
import 'package:campus_mobile/core/theme/campus_theme.dart';
import 'package:campus_mobile/data/models/app_user.dart';
import 'package:campus_mobile/features/apps/apps_page.dart';
import 'package:campus_mobile/features/apps/forge_page.dart';
import 'package:campus_mobile/features/campus/campus_page.dart';
import 'package:campus_mobile/features/community/community_page.dart';
import 'package:campus_mobile/features/profile/profile_page.dart';
import 'package:campus_mobile/features/shell/app_shell.dart';
import 'package:campus_mobile/features/study/course_hub_page.dart';
import 'package:campus_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures/in_memory_campus_repository.dart';
import 'fixtures/project_focus_repository.dart';

class _GuestProjects extends ProjectFocusRepository {
  @override
  String get userId => '';

  @override
  bool get canWrite => false;
}

class _GuestCampus extends InMemoryCampusRepository {
  @override
  Future<AppUser?> fetchCurrentUser() async => null;
}

void main() {
  Future<void> launch(
    WidgetTester tester,
    ProjectFocusRepository projects, {
    InMemoryCampusRepository? campus,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(
      repository: campus ?? InMemoryCampusRepository(),
      config: AppConfig.defaults(),
      preferences: PreferenceStore(await SharedPreferences.getInstance()),
      initialLocale: const Locale('zh'),
      initialThemeMode: ThemeMode.light,
    );
    addTearDown(state.dispose);
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: CampusRepositoryScope(
          repository: state.repository,
          child: MaterialApp(
            theme: CampusTheme.light(),
            locale: const Locale('zh'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: AppShell(forgeRepository: projects),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'public projects are the homepage and personal repositories have their own tab',
    (tester) async {
      final projects = ProjectFocusRepository();
      await launch(tester, projects);
      expect(find.byType(ForgePage), findsOneWidget);
      expect(find.byType(CampusPage), findsNothing);
      expect(find.byType(ProfilePage), findsNothing);
      expect(find.text('校园地图工具'), findsOneWidget);
      expect(find.text('我的课程助手'), findsNothing);
      expect(projects.queries, [(mine: false, query: '')]);
      expect(find.byType(SegmentedButton<bool>), findsNothing);

      await tester.tap(find.text('我的仓库').last);
      await tester.pumpAndSettle();
      expect(find.text('我的课程助手'), findsOneWidget);
      expect(find.text('校园地图工具'), findsNothing);
      expect(projects.queries.last, (mine: true, query: ''));
      await tester.tap(find.text('探索').last);
      await tester.pumpAndSettle();
      expect(find.text('校园地图工具'), findsOneWidget);
      expect(projects.queries.length, 3);
      expect(projects.queries.last, (mine: false, query: ''));
    },
  );

  testWidgets(
    'publishing a draft from exploration opens personal repositories',
    (tester) async {
      final projects = ProjectFocusRepository();
      await launch(tester, projects);
      await tester.tap(find.text('我的仓库').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '搜索我的仓库'), '旧筛选');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('探索').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, '我的 Star'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '搜索项目'), '旧搜索');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('发布项目'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '项目名称'), '新的校园作品');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
      expect(projects.queries.last, (mine: true, query: ''));
      expect(projects.projectOptions.last, (
        mine: true,
        starred: false,
        sort: 'updated',
      ));
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, '搜索我的仓库'))
            .controller!
            .text,
        isEmpty,
      );
      expect(projects.rows.last.getStringValue('reviewState'), 'draft');
      await tester.scrollUntilVisible(
        find.text('新的校园作品'),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('新的校园作品'), findsOneWidget);
      await tester.tap(find.text('探索').last);
      await tester.pumpAndSettle();
      expect(find.text('新的校园作品'), findsNothing);
    },
  );

  testWidgets(
    'project input reaches repository query and keeps each scope independent',
    (tester) async {
      final projects = ProjectFocusRepository();
      await launch(tester, projects);
      await tester.enterText(find.widgetWithText(TextField, '搜索项目'), '地图');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(projects.queries.last, (mine: false, query: '地图'));
      expect(find.text('校园地图工具'), findsOneWidget);
      await tester.tap(find.text('我的仓库').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '搜索我的仓库'), '课程');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(projects.queries.last, (mine: true, query: '课程'));
      expect(find.text('我的课程助手'), findsOneWidget);
      await tester.tap(find.text('探索').last);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, '搜索项目'))
            .controller!
            .text,
        '地图',
      );
    },
  );

  testWidgets(
    'campus retains course tools, quick access and the social square',
    (tester) async {
      final projects = ProjectFocusRepository();
      await launch(tester, projects);
      await tester.tap(find.text('校园').last);
      await tester.pumpAndSettle();
      expect(find.byType(CampusPage), findsOneWidget);
      expect(find.byType(CourseHubPage), findsOneWidget);
      expect(find.byType(AppsPage), findsNothing);
      expect(find.byType(CommunityPage), findsNothing);
      expect(find.text('课程列表'), findsOneWidget);
      expect(find.text('我的计划'), findsNothing);
      expect(find.text('我的资料'), findsNothing);
      expect(find.text('按智能体'), findsNothing);

      await tester.tap(find.text('快速访问').first);
      await tester.pumpAndSettle();
      expect(find.byType(AppsPage), findsOneWidget);
      expect(
        tester.widget<AppsPage>(find.byType(AppsPage)).quickAccessOnly,
        isTrue,
      );
      await tester.tap(find.text('校园广场').first);
      await tester.pumpAndSettle();
      expect(find.byType(CommunityPage), findsOneWidget);
      await tester.tap(find.text('课程与课表'));
      await tester.pumpAndSettle();
      expect(find.byType(CourseHubPage), findsOneWidget);
    },
  );

  testWidgets('keyboard search returns from campus to project exploration', (
    tester,
  ) async {
    final projects = ProjectFocusRepository();
    await launch(tester, projects);
    await tester.tap(find.text('校园').last);
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, '搜索项目'))
          .focusNode!
          .hasFocus,
      isTrue,
    );
    expect(find.byType(CourseHubPage), findsNothing);
  });

  testWidgets(
    'guest repository sign-in opens account and keyboard search returns to public projects',
    (tester) async {
      final projects = _GuestProjects();
      await launch(tester, projects, campus: _GuestCampus());
      await tester.tap(find.text('我的仓库').last);
      await tester.pumpAndSettle();
      expect(find.text('登录管理仓库'), findsOneWidget);
      expect(projects.queries.where((query) => query.mine), isEmpty);
      expect(find.text('我的课程助手'), findsNothing);
      await tester.tap(find.text('登录管理仓库'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        3,
      );
      expect(find.byType(ProfilePage), findsOneWidget);
      expect(find.text('登录'), findsOneWidget);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );
      expect(find.text('校园地图工具'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, '搜索项目'))
            .focusNode!
            .hasFocus,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
