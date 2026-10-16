/// 「应用」Tab 的测试 / tests for the Apps tab.
///
/// 这一页现在承载产品规则：**校园服务与学生应用混在同一张列表里，官方的只多一个标识**，
/// 且**每个子列表各有自己的搜索与排序**。因此测试守的是这四件事：
///
///   1. 三个子列表平级、都是「应用」Tab 内的一等公民，学生应用不再藏在推入页里；
///   2. 同一个子列表里官方入口与学生项目并排，官方那一行才有校徽；
///   3. 搜索与排序是**按子列表隔离**的（切走再切回来，输入还在，也不会串到别的子列表）；
///   4. 点一下就直接打开且参数正确，打开成功后才记热度；话题（标签）筛选把标签**原样**
///      交给后端。
///
/// Four things this screen must keep true: the three sub-lists are peers and student apps are no
/// longer behind a pushed page; official rows and student projects sit side by side in one
/// sub-list with the school mark only on official rows; search and ordering are **isolated per
/// sub-list**; and a tap opens directly while the topic filter hands the tag to the backend
/// verbatim.
library;

import 'dart:async';

import 'package:campus_mobile/core/app_scope_repository.dart';
import 'package:campus_mobile/core/app_state.dart';
import 'package:campus_mobile/core/config/app_config.dart';
import 'package:campus_mobile/core/config/preference_store.dart';
import 'package:campus_mobile/core/launcher/campus_launcher.dart';
import 'package:campus_mobile/core/locale_resolution.dart';
import 'package:campus_mobile/core/theme/campus_theme.dart';
import 'package:campus_mobile/data/models/campus_app.dart';
import 'package:campus_mobile/data/models/campus_service.dart';
import 'package:campus_mobile/data/models/launch_target.dart';
import 'package:campus_mobile/data/repositories/campus_repository.dart';

import 'fixtures/in_memory_campus_repository.dart';

import 'package:campus_mobile/features/apps/apps_page.dart';
import 'package:campus_mobile/features/apps/campus_entry.dart';
import 'package:campus_mobile/features/shared/widgets/university_brand_mark.dart';
import 'package:campus_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 记录被要求打开的目标（点击即跳转的观测点）。
/// Records what it was asked to open — the observation point for "a tap opens".
class RecordingLauncher implements CampusLauncher {
  final List<LaunchTarget> targets = <LaunchTarget>[];

  @override
  Future<LaunchOutcome> launch(
    BuildContext context,
    LaunchTarget target,
  ) async {
    targets.add(target);
    return LaunchOutcome.handedOff;
  }
}

/// 记录收到的查询，并可给服务注入热度 / records queries, and can inject heat into services.
class RecordingCampusRepository extends InMemoryCampusRepository {
  final List<CampusServicesQuery> serviceQueries = <CampusServicesQuery>[];
  final List<CampusAppsQuery> appQueries = <CampusAppsQuery>[];
  final List<String> openedServices = <String>[];

  /// 给某条服务加的热度（按名字），用来验证"有计数才给热度排序"。
  Map<String, int> heatByName = const <String, int>{};

  @override
  Future<List<CampusService>> listServices(CampusServicesQuery query) async {
    serviceQueries.add(query);
    final List<CampusService> services = await super.listServices(query);
    if (heatByName.isEmpty) return services;
    return <CampusService>[
      for (final CampusService service in services)
        if (heatByName[service.name] case final int heat)
          CampusService(
            id: service.id,
            universityId: service.universityId,
            name: service.name,
            description: service.description,
            iconUrl: service.iconUrl,
            category: service.category,
            type: service.type,
            launchTarget: service.launchTarget,
            isOfficial: service.isOfficial,
            origin: service.origin,
            sourceSystem: service.sourceSystem,
            sourceId: service.sourceId,
            tags: service.tags,
            openCount: heat,
            lastVerifiedAt: service.lastVerifiedAt,
            status: service.status,
            createdAt: service.createdAt,
            updatedAt: service.updatedAt,
          )
        else
          service,
    ];
  }

  @override
  Future<List<CampusApp>> fetchCampusApps(CampusAppsQuery query) async {
    appQueries.add(query);
    return super.fetchCampusApps(query);
  }

  @override
  Future<void> recordServiceOpen(String serviceId) async {
    openedServices.add(serviceId);
  }
}

class EmptyingCatalogueRepository extends RecordingCampusRepository {
  bool empty = false;
  @override
  Future<List<CampusService>> listServices(CampusServicesQuery query) async =>
      empty ? <CampusService>[] : super.listServices(query);
  @override
  Future<List<CampusApp>> fetchCampusApps(CampusAppsQuery query) async =>
      empty ? <CampusApp>[] : super.fetchCampusApps(query);
}

class CommunityResourcesRepository extends RecordingCampusRepository {
  @override
  Future<List<CampusService>> listServices(CampusServicesQuery query) async => [
    ...await super.listServices(query),
    CampusService.tryFromJson({
      'id': 'community-resource',
      'universityId': AppState.defaultUniversityId,
      'name': '狮学园学生作品社区介绍',
      'description': '学院公开介绍',
      'category': 'other',
      'origin': 'external',
      'isOfficial': false,
      'status': 'active',
      'tags': ['校园社区'],
      'launchTarget': {
        'type': 'web',
        'url': 'https://comm.ecnu.edu.cn/a8/be/c41509a567486/page.htm',
        'preferredMode': 'external',
      },
    })!,
  ];
}

class PendingCatalogueRepository extends RecordingCampusRepository {
  final pendingServices = Completer<List<CampusService>>();
  int attempts = 0;
  bool recovered = false;

  @override
  Future<List<CampusService>> listServices(CampusServicesQuery query) {
    attempts++;
    if (recovered) return super.listServices(query);
    return pendingServices.future;
  }
}

void main() {
  /// 视口调高，让页首、芯片、搜索框与子列表里的条目一次全部完成布局。
  ///
  /// 默认视口只有 800×600，`ListView` 不会构建屏幕外的子项，那些行"找不到"是视口问题，
  /// 不是分组错了。
  /// A taller viewport so the header, chips, search box and rows all lay out at once. The
  /// default 800×600 means the `ListView` never builds off-screen children, and a missing row
  /// would then be a viewport problem rather than a grouping bug.
  void useTallViewport(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(440, 2600);
    addTearDown(tester.view.reset);
  }

  Future<AppState> buildState(RecordingCampusRepository repository) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final PreferenceStore preferences = PreferenceStore(
      await SharedPreferences.getInstance(),
    );
    return AppState(
      repository: repository,
      config: AppConfig.defaults(),
      preferences: preferences,
      initialLocale: const Locale('zh'),
      initialThemeMode: ThemeMode.system,
    );
  }

  Widget wrap(AppState state, {CampusLauncher? launcher}) {
    return AppScope(
      state: state,
      child: CampusRepositoryScope(
        repository: state.repository,
        child: CampusLauncherScope(
          launcher: launcher ?? RecordingLauncher(),
          child: MaterialApp(
            theme: CampusTheme.light(),
            locale: state.locale,
            localeResolutionCallback: resolveSupportedLocale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const Scaffold(body: AppsPage()),
          ),
        ),
      ),
    );
  }

  /// 子列表芯片的文案（带条数）/ a sub-list chip's label, which carries its count.
  String subListLabel(
    AppLocalizations l10n,
    WidgetTester tester,
    String title,
  ) {
    for (final Element element in find.byType(ChoiceChip).evaluate()) {
      final ChoiceChip chip = element.widget as ChoiceChip;
      final Widget label = chip.label;
      if (label is Text && (label.data ?? '').startsWith(title)) {
        return label.data!;
      }
    }
    fail('没有找到标题为 $title 的子列表芯片');
  }

  /// 切到一个子列表 / switch to one sub-list.
  Future<void> switchTo(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(ChoiceChip, label));
    await tester.pumpAndSettle();
  }

  /// 只在**列表行**里找一个名字 / look a name up **inside a row**.
  ///
  /// 必须限定在 `Card` 里：同一个字也会出现在话题芯片（「图书馆」既是服务名也是一个标签）、
  /// 搜索框里已输入的词、以及副标题里，`find.text` 会把它们全都算上。
  ///
  /// Scoping to `Card` is required: the same word also appears in a topic chip (「图书馆」 is
  /// both a service name and a tag), in the search field's own text, and in subtitles.
  Finder row(String name) => find.widgetWithText(Card, name);

  testWidgets(
    'community resources use the managed directory and real web launcher',
    (tester) async {
      useTallViewport(tester);
      final repository = CommunityResourcesRepository();
      final state = await buildState(repository);
      final launcher = RecordingLauncher();
      await tester.pumpWidget(wrap(state, launcher: launcher));
      await tester.pumpAndSettle();
      final l10n = l10nOf(tester);
      await tester.tap(find.text(l10n.appsForge));
      await tester.pumpAndSettle();
      await tester.tap(find.text('校内社区与开源资源'));
      await tester.pumpAndSettle();
      expect(row('狮学园学生作品社区介绍'), findsOneWidget);
      expect(row('教务处'), findsNothing);
      await tester.tap(find.text('狮学园学生作品社区介绍'));
      await tester.pumpAndSettle();
      final target = launcher.targets.single as WebLaunchTarget;
      expect(
        target.url.toString(),
        'https://comm.ecnu.edu.cn/a8/be/c41509a567486/page.htm',
      );
      expect(target.preferredMode, WebLaunchMode.external);
      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    },
  );

  for (final fails in [false, true]) {
    testWidgets(
      'community stays accessible while catalog ${fails ? 'fails' : 'loads'}',
      (tester) async {
        useTallViewport(tester);
        final repository = PendingCatalogueRepository();
        final state = await buildState(repository);
        await tester.pumpWidget(wrap(state));
        await tester.pump();
        if (fails) {
          repository.pendingServices.completeError(
            StateError('catalog unavailable'),
          );
          await tester.pumpAndSettle();
        }
        final l10n = l10nOf(tester);
        expect(find.text(l10n.appsForge), findsOneWidget);
        await tester.tap(find.text(l10n.appsForge));
        await tester.pumpAndSettle();
        expect(find.text('连接校园服务后参与项目交流'), findsOneWidget);
        expect(repository.attempts, 1);
        if (!fails) {
          repository.pendingServices.complete(<CampusService>[]);
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text(l10n.appsQuickAccess));
        await tester.pumpAndSettle();
        expect(repository.attempts, 1);
        if (fails) {
          repository.recovered = true;
          await tester.tap(find.text(l10n.actionRetry));
          await tester.pumpAndSettle();
          expect(repository.attempts, 2);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        state.dispose();
      },
    );
  }

  testWidgets('目录刷新移除消失的标签；选择栏不使用勾号', (tester) async {
    useTallViewport(tester);
    final repository = EmptyingCatalogueRepository();
    final state = await buildState(repository);
    await tester.pumpWidget(wrap(state));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ChoiceChip, '羽毛球'), findsNothing);
    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();
    expect(find.text('校园生活'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '羽毛球'), findsOneWidget);
    final context = tester.element(find.byType(AppsPage));
    expect(Theme.of(context).chipTheme.showCheckmark, isFalse);
    final segmented = tester.widget<SegmentedButton<dynamic>>(
      find.byWidgetPredicate((widget) => widget is SegmentedButton),
    );
    expect(segmented.showSelectedIcon, isFalse);
    repository.empty = true;
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ChoiceChip, '羽毛球'), findsNothing);
    state.dispose();
  });

  testWidgets('校园作品进入社区，工具继续在快速入口使用', (WidgetTester tester) async {
    useTallViewport(tester);
    final RecordingCampusRepository repository = RecordingCampusRepository();
    final AppState state = await buildState(repository);
    await tester.pumpWidget(wrap(state));
    await tester.pumpAndSettle();
    final AppLocalizations l10n = l10nOf(tester);
    await tester.tap(find.text(l10n.appsForge));
    await tester.pumpAndSettle();
    expect(find.text('连接校园服务后参与项目交流'), findsOneWidget);
    expect(row('教务处'), findsNothing);
    await tester.tap(find.text(l10n.appsQuickAccess));
    await tester.pumpAndSettle();
    await switchTo(tester, subListLabel(l10n, tester, l10n.appsGroupWeb));
    expect(row('空教室查询'), findsOneWidget);
    expect(row('教务处'), findsOneWidget);
    state.dispose();
  });

  testWidgets('三个子列表平级，学生应用不再藏在推入页 / three peer sub-lists', (
    WidgetTester tester,
  ) async {
    useTallViewport(tester);
    final RecordingCampusRepository repository = RecordingCampusRepository();
    final AppState state = await buildState(repository);
    await tester.pumpWidget(wrap(state));
    await tester.pumpAndSettle();

    final AppLocalizations l10n = l10nOf(tester);
    expect(find.textContaining('点一下直接打开'), findsNothing);

    // 三个子列表都在，而且各自带条数。
    for (final String title in <String>[
      l10n.appsGroupOfficialWorkbench,
      l10n.appsGroupWeb,
      l10n.appsGroupMiniProgram,
    ]) {
      expect(
        find.widgetWithText(ChoiceChip, subListLabel(l10n, tester, title)),
        findsOneWidget,
        reason: '缺少子列表 $title',
      );
    }

    // 默认是官方工作台，随师办在这里，而且**只出现一次**。
    expect(row('随师办'), findsOneWidget);
    // 别的子列表的条目此刻不在屏幕上：一次只看一个子列表。
    expect(row('教务处'), findsNothing);

    state.dispose();
  });

  testWidgets(
    '官方入口与学生项目并排，只有官方那行有校徽 / peers in one list, mark only on official',
    (WidgetTester tester) async {
      useTallViewport(tester);
      final RecordingCampusRepository repository = RecordingCampusRepository();
      final AppState state = await buildState(repository);
      await tester.pumpWidget(wrap(state));
      await tester.pumpAndSettle();

      final AppLocalizations l10n = l10nOf(tester);
      await switchTo(tester, subListLabel(l10n, tester, l10n.appsGroupWeb));

      // 同一个 Web 子列表里：官方入口（教务处）与学生应用（空教室查询）并排。
      expect(row('教务处'), findsOneWidget);
      expect(row('空教室查询'), findsOneWidget);

      // 官方的"特殊标识"：校徽只出现在官方那一行。
      expect(
        find.descendant(
          of: row('教务处'),
          matching: find.byType(UniversityBrandMark),
        ),
        findsOneWidget,
        reason: '官方条目必须带归属标识',
      );
      expect(
        find.descendant(
          of: row('空教室查询'),
          matching: find.byType(UniversityBrandMark),
        ),
        findsNothing,
        reason: '学生项目不该被加上官方标识',
      );
      // 来源徽章两者都有：地位相同，只差归属标识。
      expect(
        find.descendant(
          of: row('空教室查询'),
          matching: find.text(l10n.originStudentDeveloped),
        ),
        findsOneWidget,
      );

      // 开源仓库入口：学生应用有（它是取信凭据），学校服务没有——服务根本没有仓库字段，
      // 因此不能出现一个指向空地址的按钮。
      // The repository affordance: student apps have one (it is the trust signal), school services
      // do not — a service has no repository field, so no button may point at nothing.
      expect(
        find.descendant(of: row('空教室查询'), matching: find.byIcon(Icons.code)),
        findsOneWidget,
        reason: '挂了仓库的学生应用要给出可见入口',
      );
      expect(
        find.descendant(of: row('教务处'), matching: find.byIcon(Icons.code)),
        findsNothing,
        reason: '学校服务没有仓库，不该出现空链接按钮',
      );

      state.dispose();
    },
  );

  testWidgets('每个子列表各有自己的搜索，互不串 / search is isolated per sub-list', (
    WidgetTester tester,
  ) async {
    useTallViewport(tester);
    final RecordingCampusRepository repository = RecordingCampusRepository();
    final AppState state = await buildState(repository);
    await tester.pumpWidget(wrap(state));
    await tester.pumpAndSettle();

    final AppLocalizations l10n = l10nOf(tester);
    await switchTo(tester, subListLabel(l10n, tester, l10n.appsGroupWeb));

    await tester.enterText(find.byType(TextField), '图书馆');
    await tester.pumpAndSettle();
    expect(row('图书馆'), findsOneWidget);
    expect(row('教务处'), findsNothing, reason: '搜索应当把不匹配的行筛掉');

    // 切到官方工作台：它的搜索框是空的，因此随师办照常显示。
    await switchTo(
      tester,
      subListLabel(l10n, tester, l10n.appsGroupOfficialWorkbench),
    );
    expect(row('随师办'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '',
      reason: '子列表之间的搜索词必须互不影响',
    );

    // 切回 Web：刚才输入的关键词还在（每个子列表记住自己的筛选）。
    await switchTo(tester, subListLabel(l10n, tester, l10n.appsGroupWeb));
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '图书馆',
    );
    expect(row('教务处'), findsNothing);

    // 搜索无结果与"子列表为空"是两句不同的话。
    await tester.enterText(find.byType(TextField), '不存在的东西');
    await tester.pumpAndSettle();
    expect(find.text(l10n.appsSearchEmpty), findsOneWidget);
    expect(find.text(l10n.appsGroupEmpty), findsNothing);

    state.dispose();
  });

  testWidgets('没有热度数据时不给热度排序 / heat ordering only when counts are real', (
    WidgetTester tester,
  ) async {
    useTallViewport(tester);
    final RecordingCampusRepository repository = RecordingCampusRepository();
    final AppState state = await buildState(repository);
    await tester.pumpWidget(wrap(state));
    await tester.pumpAndSettle();

    final AppLocalizations l10n = l10nOf(tester);
    await switchTo(tester, subListLabel(l10n, tester, l10n.appsGroupWeb));

    await tester.tap(find.byType(PopupMenuButton<CampusEntrySort>));
    await tester.pumpAndSettle();
    expect(find.text(l10n.appsSortName), findsWidgets);
    expect(find.text(l10n.appsSortRecent), findsWidgets);
    // 全部计数为 0 时不提供热度：点它看到的会是名称顺序，一个"看着能用、其实没信息"的选项。
    expect(find.text(l10n.appsSortHeat), findsNothing);

    state.dispose();
  });

  testWidgets('有真实计数时出现热度徽标，热度排序把它排到最前 / heat appears once counts exist', (
    WidgetTester tester,
  ) async {
    useTallViewport(tester);
    final RecordingCampusRepository repository = RecordingCampusRepository();
    // 只给「校园卡」注入热度。挑它是因为**按名称排序时它排在最后**（「校」的码位最大），
    // 于是"热度排序真的生效"与"其实还在按名称排"能区分开——若挑一个本来就靠前的条目，
    // 断言会在排序根本没生效时也通过。
    //
    // 「校园卡」is picked precisely because it sorts **last** by name, so a passing assertion
    // really proves the heat ordering ran rather than the name ordering still being in effect.
    repository.heatByName = <String, int>{'校园卡': 7};
    final AppState state = await buildState(repository);
    await tester.pumpWidget(wrap(state));
    await tester.pumpAndSettle();

    final AppLocalizations l10n = l10nOf(tester);
    await switchTo(tester, subListLabel(l10n, tester, l10n.appsGroupWeb));

    expect(row('7'), findsOneWidget, reason: '热度徽标要显示真实计数');

    await tester.tap(find.byType(PopupMenuButton<CampusEntrySort>));
    await tester.pumpAndSettle();
    // 点菜单项本身而不是里面的 Text：弹出菜单会重新布局，直接点 Text 的中心有可能落空。
    // Tap the menu item, not the Text inside it: the popup re-lays out and the Text's centre can
    // miss the hit test.
    await tester.tap(
      find
          .ancestor(
            of: find.text(l10n.appsSortHeat),
            matching: find.byType(CheckedPopupMenuItem<CampusEntrySort>),
          )
          .last,
    );
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(row('校园卡')).dy,
      lessThan(tester.getTopLeft(row('体育场馆预约')).dy),
      reason: '按热度排序时被打开最多的必须在最前（按名称它本该排最后）',
    );

    state.dispose();
  });

  testWidgets('点一下列表项就直接打开且参数正确；成功后才记热度 / a tap opens, heat after success', (
    WidgetTester tester,
  ) async {
    useTallViewport(tester);
    final RecordingCampusRepository repository = RecordingCampusRepository();
    final AppState state = await buildState(repository);
    final RecordingLauncher launcher = RecordingLauncher();
    await tester.pumpWidget(wrap(state, launcher: launcher));
    await tester.pumpAndSettle();

    final AppLocalizations l10n = l10nOf(tester);
    await switchTo(tester, subListLabel(l10n, tester, l10n.appsGroupWeb));

    await tester.tap(row('教务处'));
    await tester.pumpAndSettle();
    expect(launcher.targets, hasLength(1), reason: '点击列表项必须触发一次打开');
    final LaunchTarget web = launcher.targets.single;
    expect(web, isA<WebLaunchTarget>());
    expect((web as WebLaunchTarget).url, 'https://jwc.ecnu.edu.cn/');

    // 打开**成功**之后才记热度：失败的一次点击不是一次使用。
    expect(repository.openedServices, hasLength(1));

    // 详情不该被这次点击打开：点一下是"打开"，不是"点开详情再点一次"。
    expect(find.text(l10n.contactGroupNumberCopy), findsNothing);

    state.dispose();
  });

  testWidgets('话题筛选把标签原样交给后端 / the topic filter hands the tag to the backend', (
    WidgetTester tester,
  ) async {
    useTallViewport(tester);
    final RecordingCampusRepository repository = RecordingCampusRepository();
    final AppState state = await buildState(repository);
    await tester.pumpWidget(wrap(state));
    await tester.pumpAndSettle();

    // 话题芯片的取值来自服务端返回的规范名；点它只是把标签**原样**发出去，
    // 客户端不做归一化（归一化只有服务端一份）。
    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '羽毛球'));
    await tester.pumpAndSettle();

    // 应用走真正的 `?tag=`；服务没有标签参数，走它自己的 `?q=`。
    expect(repository.appQueries.last.tag, '羽毛球');
    expect(repository.serviceQueries.last.text, '羽毛球');

    // 筛选之后 Web 组里只剩带着这个标签的入口。
    final AppLocalizations l10n = l10nOf(tester);
    await switchTo(tester, subListLabel(l10n, tester, l10n.appsGroupWeb));
    expect(row('体育场馆预约'), findsOneWidget);
    expect(row('教务处'), findsNothing);

    state.dispose();
  });

  testWidgets('官方目录详情仅展示管理员提供的群号', (WidgetTester tester) async {
    useTallViewport(tester);
    final RecordingCampusRepository repository = RecordingCampusRepository();
    final AppState state = await buildState(repository);
    await tester.pumpWidget(wrap(state));
    await tester.pumpAndSettle();

    final AppLocalizations l10n = l10nOf(tester);
    // 详情由长按进入（列表项右侧的「更多」按钮同理）。
    await tester.longPress(row('随师办'));
    await tester.pumpAndSettle();

    expect(find.text(l10n.contactGroupNumberLabel), findsNothing);
    expect(find.text('1078634219'), findsNothing);
    // 不允许谎称它来自后端：必须带"演示数据"标记。
    expect(
      find.text(l10n.demoDataNotice(l10n.dataSourceLabelContactGroupNumber)),
      findsNothing,
    );

    state.dispose();
  });
}

/// 取当前树上的本地化文案 / the localization of the current tree.
AppLocalizations l10nOf(WidgetTester tester) =>
    AppLocalizations.of(find.byType(AppsPage).evaluate().first);
