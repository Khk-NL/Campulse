/// 项目优先的应用外壳：探索、我的仓库、校园、我的。
/// 搜索聚焦项目输入框，通知独立打开。首次访问装配页面，随后保留其查询和滚动状态。
library;

import 'package:campus_mobile/core/app_scope_repository.dart';
import 'package:campus_mobile/core/app_state.dart';
import 'package:campus_mobile/core/theme/campus_theme.dart';
import 'package:campus_mobile/data/models/transaction.dart';
import 'package:campus_mobile/data/repositories/campus_repository.dart';
import 'package:campus_mobile/features/apps/forge_page.dart';
import 'package:campus_mobile/features/apps/forge_repository.dart';
import 'package:campus_mobile/features/campus/campus_page.dart';
import 'package:campus_mobile/features/profile/profile_page.dart';
import 'package:campus_mobile/features/shared/widgets/offline_banner.dart';
import 'package:campus_mobile/features/shared/widgets/workspace_layout.dart';
import 'package:campus_mobile/features/shell/shell_routes.dart';
import 'package:campus_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 外壳 / the shell.
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.forgeRepository});
  final ForgeRepository? forgeRepository;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  final Set<int> _visited = {0};
  late final AnimationController _transition;
  final _exploreSearch = FocusNode();
  final _repositorySearch = FocusNode();

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
    _exploreSearch.dispose();
    _repositorySearch.dispose();
    super.dispose();
  }

  /// 是否有需要处理的待办——顶部通知入口据此显示小圆点。
  /// Whether anything needs attention; it drives the dot on the notifications entry.
  bool _hasOpenTasks = false;

  /// 首次加载已经排过队了吗。/ whether the first load has already been queued.
  bool _loadQueued = false;
  int _refreshToken = 0;
  bool _refreshing = false;
  int _repositoryResetToken = 0;

  void _showCreatedProject() {
    setState(() => _repositoryResetToken++);
    _select(1);
  }

  void _searchProjects() {
    final mine = _index == 1 && _repositorySearch.context != null;
    _select(mine ? 1 : 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) (mine ? _repositorySearch : _exploreSearch).requestFocus();
    });
  }

  void _select(int index) {
    if (_index == index) return;
    setState(() {
      _index = index;
      _visited.add(index);
    });
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
      l10n.navExplore,
      l10n.navRepositories,
      l10n.navCampus,
      l10n.navProfile,
    ];
    const icons = [
      Icons.explore_outlined,
      Icons.source_outlined,
      Icons.calendar_month_outlined,
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
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _searchProjects,
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
                onPressed: _searchProjects,
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
                                'BUILD · SHARE · CONNECT',
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
                                  ForgePage(
                                    key: const ValueKey('explore-projects'),
                                    active: _index == 0,
                                    embedded: true,
                                    repository: widget.forgeRepository,
                                    showViewSwitcher: false,
                                    searchFocusNode: _exploreSearch,
                                    onOpenAccount: () => _select(3),
                                    onOpenRepositories: _showCreatedProject,
                                    refreshToken: _refreshToken,
                                  ),
                                  if (_visited.contains(1))
                                    ForgePage(
                                      key: const ValueKey('my-repositories'),
                                      resetSearchToken: _repositoryResetToken,
                                      active: _index == 1,
                                      embedded: true,
                                      initialMine: true,
                                      repository: widget.forgeRepository,
                                      showViewSwitcher: false,
                                      searchFocusNode: _repositorySearch,
                                      onOpenAccount: () => _select(3),
                                      refreshToken: _refreshToken,
                                    )
                                  else
                                    const SizedBox.shrink(),
                                  if (_visited.contains(2))
                                    CampusPage(
                                      active: _index == 2,
                                      refreshToken: _refreshToken,
                                    )
                                  else
                                    const SizedBox.shrink(),
                                  if (_visited.contains(3))
                                    ProfilePage(
                                      onOpenRepositories: () => _select(1),
                                    )
                                  else
                                    const SizedBox.shrink(),
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
                      icon: const Icon(Icons.explore_outlined),
                      selectedIcon: const Icon(Icons.explore),
                      label: l10n.navExplore,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.source_outlined),
                      selectedIcon: const Icon(Icons.source),
                      label: l10n.navRepositories,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.calendar_month_outlined),
                      selectedIcon: const Icon(Icons.calendar_month),
                      label: l10n.navCampus,
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
        return l10n.navExplore;
      case 1:
        return l10n.navRepositories;
      case 2:
        return l10n.navCampus;
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
