/// 应用外壳：底部 4 Tab 导航 + 统一顶部栏 / the app shell: four bottom tabs and one top bar.
///
/// §13-Phase 0 原本指定五个入口（Home / Search / Inbox / Store / Profile）。本轮的界面
/// 结构把这五个入口重新分工：
///
///   * 底部栏只留 **首页 / 应用 / 课程 / 我的** 四个；课程是主入口，课表是时间视图；
///   * **搜索** 与 **通知（事务）** 从底部栏移到顶部栏，成为**推入的路由页**。
///
/// 这么分不是审美偏好，而是依据"频率与层级"：搜索与通知是随时可能触发的**动作**，
/// 放底部栏会长期占掉两个位置，而底部栏的位置应该留给"我平时待在哪儿"。顶部栏由
/// 外壳统一持有（标题随当前 Tab 变化），因此从任何一个 Tab 都能一眼看到这两个入口，
/// 且它们的行为完全一致。
///
/// Phase 0 fixed five entries (Home, Search, Inbox, Store, Profile). This round regroups
/// them: the bottom bar keeps **Home, Apps, Courses, Profile** only, while **Search** and
/// **Notifications (inbox)** move up into the AppBar as **pushed routes**.
///
/// That split follows frequency and hierarchy rather than taste: search and notifications
/// are *actions* that can fire from anywhere, and giving them two permanent bottom slots
/// costs the bar its real job — the few places a user actually lives in. The shell owns one
/// AppBar (its title follows the active tab), so both entries are reachable and behave
/// identically from every tab.
///
/// 用 `IndexedStack` 而不是按需构建，是为了让每个 Tab 的滚动位置与已加载数据在切换后保留。
/// `IndexedStack` rather than lazy construction keeps each tab's scroll position and loaded
/// data across switches, which the timetable especially needs after moving weeks.
library;

import 'package:campus_mobile/core/app_scope_repository.dart';
import 'package:campus_mobile/core/app_state.dart';
import 'package:campus_mobile/core/theme/campus_theme.dart';
import 'package:campus_mobile/data/models/transaction.dart';
import 'package:campus_mobile/data/repositories/campus_repository.dart';
import 'package:campus_mobile/features/apps/apps_page.dart';
import 'package:campus_mobile/features/home/home_page.dart';
import 'package:campus_mobile/features/profile/profile_page.dart';
import 'package:campus_mobile/features/study/course_hub_page.dart';
import 'package:campus_mobile/features/shared/widgets/offline_banner.dart';
import 'package:campus_mobile/features/shared/widgets/workspace_layout.dart';
import 'package:campus_mobile/features/shell/shell_routes.dart';
import 'package:campus_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 外壳 / the shell.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  late final AnimationController _transition;

  @override
  void initState() {
    super.initState();
    _transition = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: 1,
    );
  }

  @override
  void dispose() {
    _transition.dispose();
    super.dispose();
  }

  /// 是否有需要处理的待办——顶部通知入口据此显示小圆点。
  /// Whether anything needs attention; it drives the dot on the notifications entry.
  bool _hasOpenTasks = false;

  /// 首次加载已经排过队了吗。/ whether the first load has already been queued.
  bool _loadQueued = false;
  int _refreshToken = 0;
  bool _refreshing = false;

  void _select(int index) {
    if (_index == index) return;
    setState(() => _index = index);
    if (MediaQuery.disableAnimationsOf(context)) {
      _transition.value = 1;
    } else {
      _transition.forward(from: 0);
    }
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await AppScope.read(context).retryConnection();
      await _loadBadge();
      if (mounted) setState(() => _refreshToken++);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 依赖注入只能在 didChangeDependencies 里读（initState 里读会触发断言）。
    // Injected dependencies are readable only in didChangeDependencies; reading them in
    // initState trips an assertion.
    if (_loadQueued) return;
    _loadQueued = true;
    _loadBadge();
  }

  Future<void> _loadBadge() async {
    final CampusRepository repository = CampusRepositoryScope.read(context);
    List<CampusTask> tasks;
    try {
      tasks = await repository.fetchTasks();
    } on Exception {
      tasks = const <CampusTask>[];
    }
    if (!mounted) return;
    setState(() {
      _hasOpenTasks = tasks.any((CampusTask task) => task.isOpen);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool desktop = MediaQuery.sizeOf(context).width >= 980;
    final labels = [
      l10n.navHome,
      l10n.navStore,
      l10n.navTimetable,
      l10n.navProfile,
    ];
    const icons = [
      Icons.dashboard_outlined,
      Icons.apps_outlined,
      Icons.school_outlined,
      Icons.person_outline,
    ];
    return CallbackShortcuts(
      bindings: {
        for (int i = 0; i < 4; i++)
          SingleActivator(
            [
              LogicalKeyboardKey.digit1,
              LogicalKeyboardKey.digit2,
              LogicalKeyboardKey.digit3,
              LogicalKeyboardKey.digit4,
            ][i],
            control: true,
          ): () =>
              _select(i),
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
            openSearch(context),
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): _refresh,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: Row(
              children: <Widget>[
                Image.asset(
                  'assets/brand/campulse-logo.png',
                  width: 30,
                  height: 30,
                ),
                const SizedBox(width: 10),
                Flexible(child: Text(_title(l10n))),
              ],
            ),
            actions: <Widget>[
              IconButton(
                tooltip: '刷新云端数据',
                onPressed: _refreshing ? null : _refresh,
                icon: _refreshing
                    ? SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      )
                    : const Icon(Icons.cloud_sync_outlined),
              ),
              _AppBarAction(
                icon: Icons.notifications_none,
                tooltip: l10n.navNotification,
                showDot: _hasOpenTasks,
                onPressed: () => openNotificationCenter(context),
              ),
              _AppBarAction(
                icon: Icons.search,
                tooltip: l10n.navSearch,
                onPressed: () => openSearch(context),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: WorkspaceCanvas(
            child: Row(
              children: [
                if (desktop) ...[
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary
                            .withValues(alpha: .14),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Theme.of(context).colorScheme.primaryContainer
                              .withValues(alpha: .55),
                          Theme.of(context).colorScheme.surface,
                          Theme.of(context).colorScheme.tertiaryContainer
                              .withValues(alpha: .4),
                        ],
                      ),
                    ),
                    child: NavigationRail(
                      backgroundColor: Colors.transparent,
                      extended: MediaQuery.sizeOf(context).width >= 1250,
                      selectedIndex: _index,
                      onDestinationSelected: _select,
                      leading: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 22,
                          horizontal: 12,
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: .12),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                'assets/brand/campulse-logo.png',
                                width: 44,
                                height: 44,
                              ),
                            ),
                            if (MediaQuery.sizeOf(context).width >= 1250) ...[
                              const SizedBox(height: 16),
                              const Text(
                                'CAMPULSE',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'LEARN · BUILD · CONNECT',
                                style: TextStyle(
                                  fontSize: 9,
                                  letterSpacing: 1,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      destinations: [
                        for (int i = 0; i < labels.length; i++)
                          NavigationRailDestination(
                            icon: Icon(icons[i]),
                            label: Text(labels[i]),
                          ),
                      ],
                    ),
                  ),
                ],
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1560),
                      child: Column(
                        children: <Widget>[
                          // 离线横幅只在整个后端都不可达时出现；若只是某些接口还没上线，
                          // 由各区块自己的"演示数据"标记如实说明（见 home_page.dart）。
                          // The offline banner appears only when the whole backend is unreachable; when
                          // merely some endpoints are missing, each block states it with its own demo
                          // badge instead (see home_page.dart).
                          const OfflineBanner(),
                          Expanded(
                            child: FadeTransition(
                              opacity: Tween<double>(
                                begin: .82,
                                end: 1,
                              ).animate(_transition),
                              child: IndexedStack(
                                key: ValueKey<String>(
                                  AppScope.of(context).user?.id ?? 'guest',
                                ),
                                index: _index,
                                children: <Widget>[
                                  HomePage(
                                    active: _index == 0,
                                    refreshToken: _refreshToken,
                                    onNavigate: _select,
                                  ),
                                  AppsPage(refreshToken: _refreshToken),
                                  CourseHubPage(
                                    active: _index == 2,
                                    refreshToken: _refreshToken,
                                  ),
                                  const ProfilePage(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: desktop
              ? null
              : NavigationBar(
                  selectedIndex: _index,
                  onDestinationSelected: _select,
                  destinations: <NavigationDestination>[
                    NavigationDestination(
                      icon: const Icon(Icons.home_outlined),
                      selectedIcon: const Icon(Icons.home),
                      label: l10n.navHome,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.apps_outlined),
                      selectedIcon: const Icon(Icons.apps),
                      label: l10n.navStore,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.school_outlined),
                      selectedIcon: const Icon(Icons.school),
                      label: l10n.navTimetable,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.person_outline),
                      selectedIcon: const Icon(Icons.person),
                      label: l10n.navProfile,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  /// 标题随当前 Tab 变化 / the title follows the active tab.
  String _title(AppLocalizations l10n) {
    switch (_index) {
      case 0:
        return l10n.appTitle;
      case 1:
        // 「应用」Tab 现在装的是校园服务入口（分三组），学生应用只是它的一个推入页，
        // 因此标题不能再用 `storeTitle`。
        // The Apps tab now holds the grouped campus entries, with the student-app store as a
        // pushed page, so its title can no longer be `storeTitle`.
        return l10n.appsTitle;
      case 2:
        return l10n.navTimetable;
      default:
        return l10n.profileTitle;
    }
  }
}

/// 顶部栏的一个图标入口 / one icon entry in the top bar.
///
/// 顶部栏是标准色实色块，因此图标必须是白色（主题的 AppBar 前景色），
/// 小圆点用警告色以便在红底上仍然可辨。
/// The top bar is a solid standard-colour block, so the icon must be white (the theme's
/// AppBar foreground) and the dot uses the warning hue to stay visible on red.
class _AppBarAction extends StatelessWidget {
  const _AppBarAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.showDot = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return IconButton(
      icon: showDot
          ? Badge(
              smallSize: 8,
              backgroundColor: theme.statusColors.warning,
              child: Icon(icon),
            )
          : Icon(icon),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}
