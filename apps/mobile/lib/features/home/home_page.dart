/// 首页 / Home (§12).
///
/// §12 的核心表达是「**我今天在校园里有什么事情？**」，而不是「我还有多少条未读」。
/// 因此这一页刻意**不是**消息流，而是四块结构化内容：
///   Today（今天的课与日程）/ Tasks（待办 + 截止时间）/ Campulse（公告与服务动态）
///   / Quick Access（课表、校园卡、图书馆…）。
///
/// §12's core question is "what is happening on campus today?", not "how many unread
/// items do I have?". So this page is deliberately *not* a feed but four structured
/// blocks: Today, Tasks (with deadlines), Campulse (notices and service updates) and
/// Quick Access.
///
/// 每一块独立加载、独立空态：某一块没数据不会让整页变成空白。
/// Each block loads and empties independently, so one empty block never blanks the page.
library;

import 'package:campus_mobile/core/app_scope_repository.dart';
import 'package:campus_mobile/core/app_state.dart';
import 'package:campus_mobile/core/config/university_config.dart';
import 'package:campus_mobile/data/models/campus_service.dart';
import 'package:campus_mobile/data/models/course.dart';
import 'package:campus_mobile/data/models/period_schedule.dart';
import 'package:campus_mobile/data/models/transaction.dart';
import 'package:campus_mobile/data/repositories/campus_repository.dart';
import 'package:campus_mobile/data/repositories/data_source_mode.dart';
import 'package:campus_mobile/features/home/home_view_model.dart';
import 'package:campus_mobile/features/home/widgets/personal_plan_card.dart';
import 'package:campus_mobile/features/home/widgets/quick_access_grid.dart';
import 'package:campus_mobile/features/home/widgets/task_tile.dart';
import 'package:campus_mobile/features/inbox/widgets/transaction_details_sheet.dart';
import 'package:campus_mobile/features/shared/widgets/offline_banner.dart';
import 'package:campus_mobile/features/shared/widgets/section_card.dart';
import 'package:campus_mobile/features/shared/widgets/transaction_tile.dart';
import 'package:campus_mobile/features/shared/widgets/workspace_layout.dart';
import 'package:campus_mobile/features/study/course_space_entry.dart';
import 'package:campus_mobile/features/study/course_hub_page.dart';
import 'package:campus_mobile/features/apps/apps_page.dart';
import 'package:campus_mobile/features/profile/profile_page.dart';
import 'package:intl/intl.dart';
import 'package:campus_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// 首页 / the home screen.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.active = true,
    this.refreshToken = 0,
    this.onNavigate,
  });
  final bool active;
  final int refreshToken;
  final ValueChanged<int>? onNavigate;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // 用空 future 而不是 `late`：这样即使依赖尚未就绪，首帧也不会抛
  // LateInitializationError，四个分区只是先显示各自的加载态。
  // Empty futures rather than `late` fields, so the first build can never throw
  // LateInitializationError even if dependencies are not ready yet — each section simply
  // shows its loading state.
  Future<List<CampusTask>> _tasks = Future<List<CampusTask>>.value(
    const <CampusTask>[],
  );
  Future<List<Announcement>> _announcements = Future<List<Announcement>>.value(
    const <Announcement>[],
  );
  Future<List<CampusService>> _quickAccess = Future<List<CampusService>>.value(
    const <CampusService>[],
  );
  Future<({List<Course> courses, List<CampusEvent> events})> _today =
      Future<({List<Course> courses, List<CampusEvent> events})>.value((
        courses: const <Course>[],
        events: const <CampusEvent>[],
      ));

  /// 首次加载已经排过队了吗。/ whether the first load has already been queued.
  bool _loadQueued = false;
  int _planRefresh = 0;

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.active && !oldWidget.active) ||
        widget.refreshToken != oldWidget.refreshToken) {
      _load();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 依赖注入要等到 didChangeDependencies 才能读取（initState 里读会触发断言），
    // 因此首次加载放在这里，且只排一次队。
    // Injected dependencies only become readable in didChangeDependencies (reading them
    // in initState trips an assertion), so the first load is queued here, exactly once.
    if (_loadQueued) return;
    _loadQueued = true;
    _load();
  }

  /// 重新发起全部请求。下拉刷新与"重试"都走这里。
  /// Re-issue every request; pull-to-refresh and retry both come through here.
  void _load() {
    final CampusRepository repository = CampusRepositoryScope.of(context);
    // 高校 id 来自 `core/config/universities/`，通用层不认识它。
    // The university id comes from `core/config/universities/`; the generic layer does
    // not know it.
    final String universityId = AppState.defaultUniversityId;
    final Future<List<Course>> courses = repository.fetchCourses();
    final Future<List<CampusEvent>> events = repository.fetchEvents();
    final Future<List<CampusTask>> tasks = repository.fetchTasks();
    final Future<List<Announcement>> announcements = repository
        .fetchAnnouncements();
    final Future<List<CampusService>> quickAccess = repository.listServices(
      CampusServicesQuery(
        // 首页快捷入口只需要少量服务，由 repository 决定来源。
        // Home's quick access needs only a handful of services.
        universityId: universityId,
        sort: ServiceSortOrder.recent,
        limit: 8,
      ),
    );
    final Future<({List<Course> courses, List<CampusEvent> events})> today =
        Future.wait<Object>(<Future<Object>>[courses, events]).then(
          (List<Object> results) => (
            courses: results[0] as List<Course>,
            events: results[1] as List<CampusEvent>,
          ),
        );
    if (!mounted) {
      _tasks = tasks;
      _announcements = announcements;
      _quickAccess = quickAccess;
      _today = today;
      return;
    }
    setState(() {
      _planRefresh++;
      _tasks = tasks;
      _announcements = announcements;
      _quickAccess = quickAccess;
      _today = today;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 本页只返回内容：顶部栏（含通知 / 搜索入口）由 AppShell 统一提供，所以四个 Tab
    // 的顶部栏完全一致。全页只有一条滚动列表，因此只留一个 RefreshIndicator。
    // This screen returns content only: the shell owns the top bar (with the notifications
    // and search entries) so all four tabs share it. One scrollable means one
    // RefreshIndicator.
    return RefreshIndicator(
      onRefresh: () async => _load(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: <Widget>[
          _welcome(),
          const SizedBox(height: 16),
          WorkspaceGrid(
            minWidth: 410,
            children: [
              PersonalPlanCard(
                key: ValueKey(AppScope.of(context).user?.id ?? 'guest'),
                refreshToken: _planRefresh,
              ),
              _todaySection(),
            ],
          ),
          const SizedBox(height: 16),
          _destinations(),
          const SizedBox(height: 16),
          WorkspaceGrid(
            minWidth: 410,
            children: [_tasksSection(), _campusSection()],
          ),
          const SizedBox(height: 16),
          _quickAccessSection(),
        ],
      ),
    );
  }

  Widget _welcome() {
    final state = AppScope.of(context);
    final english = Localizations.localeOf(context).languageCode == 'en';
    final name = state.displayName;
    return WorkspaceBanner(
      eyebrow: DateFormat(
        'MMM d · EEEE',
        english ? 'en' : 'zh',
      ).format(DateTime.now()),
      title: name.isEmpty
          ? (english ? 'Your campus, in focus' : '把今天安排得更从容')
          : (english ? 'Welcome back, $name' : '$name，开启校园新一天'),
      subtitle: english
          ? 'Pick up your learning, plan your day, build together.'
          : '从今日安排出发，继续学习，也参与校园里的新想法。',
      icon: Icons.wb_sunny_outlined,
      actions: [
        FilledButton.icon(
          onPressed: () async {
            await Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const CourseSpaceEntry(plansOnly: true),
              ),
            );
            if (mounted) _load();
          },
          icon: const Icon(Icons.edit_calendar_outlined),
          label: Text(english ? 'Plan my day' : '安排今天'),
        ),
      ],
    );
  }

  Widget _destinations() {
    final english = Localizations.localeOf(context).languageCode == 'en';
    final scheme = Theme.of(context).colorScheme;
    return WorkspaceGrid(
      children: [
        WorkspaceAction(
          title: english ? 'Learning library' : '课程资料库',
          subtitle: english ? 'Sources, notes & review' : '课表 · 教材 · 笔记 · 复习',
          icon: Icons.auto_stories_outlined,
          onTap: () => _navigate(2),
        ),
        WorkspaceAction(
          title: english ? 'Campus connections' : '校园连接',
          subtitle: english
              ? 'Services & student projects'
              : '官方服务 · 学生作品 · 项目交流',
          icon: Icons.hub_outlined,
          color: scheme.tertiary,
          onTap: () => _navigate(1),
        ),
        WorkspaceAction(
          title: english ? 'Personal workspace' : '个人工作区',
          subtitle: english ? 'Your identity & preferences' : '账号 · 收藏 · 个性化',
          icon: Icons.tune_rounded,
          color: scheme.secondary,
          onTap: () => _navigate(3),
        ),
      ],
    );
  }

  void _navigate(int index) {
    if (widget.onNavigate != null) {
      widget.onNavigate!(index);
      return;
    }
    final page = switch (index) {
      1 => const AppsPage(),
      2 => const CourseHubPage(),
      _ => const ProfilePage(),
    };
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Campulse')),
          body: page,
        ),
      ),
    );
  }

  Widget _todaySection() {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return HomeSection<({List<Course> courses, List<CampusEvent> events})>(
      title: l10n.homeToday,
      icon: Icons.today_outlined,
      trailing: const DemoSourceBadge(source: DataSourceSource.courses),
      future: _today,
      emptyMessage: l10n.homeNoTodayItems,
      builder:
          (
            BuildContext context,
            ({List<Course> courses, List<CampusEvent> events}) data,
          ) {
            final DateTime now = DateTime.now();
            // 教学周从**同一个**学期日历取，首页与课表不再各算一份（此前两份实现都在用
            // `DemoTerm` 的滚动锚点，同一天可能给出不同的周号）。
            // The teaching week comes from the **same** term calendar as the timetable; the two no
            // longer each compute their own from a rolling anchor, which could disagree on the same
            // day.
            final int week =
                UniversityConfigs.defaultConfig
                    .termCalendar(now)
                    .currentWeekOf(now) ??
                1;
            // 节次 → 时刻同理：从配置/后端来的作息表回答，首页不再自带一套"08:00 + 45 分钟"。
            // Period → clock time likewise comes from the configured schedule; Home no longer carries
            // its own "08:00 plus 45 minutes".
            final PeriodSchedule schedule =
                AppScope.of(context).university?.config.periodSchedule ??
                UniversityConfigs.defaultConfig.periodSchedule;
            final List<HomeTodayItem> items = <HomeTodayItem>[
              // §12 的 Today 是"今天的课"：只有真在今天上、且本周确实结课的课程才算数，
              // 否则首页会把整学期的课都摊在"今日"里。
              // §12's Today means today's classes, so only courses that really meet today and
              // are still running this week qualify; otherwise the whole term lands under
              // "Today".
              for (final Course course in data.courses)
                if (course.weekday == now.weekday && course.meetsInWeek(week))
                  fromCourse(course, schedule: schedule),
              for (final CampusEvent event in data.events)
                // 调课事件只属于它调的那一周（`concernsWeek`）：否则"第 5 周调课"会出现在今天的
                // 日程里，而它影响的是一周之后的课。
                // A schedule change belongs to the week it moves: otherwise a week-5 change shows up
                // in today's list while it actually affects a class a week away.
                if (event.occursOn(now) && event.concernsWeek(week))
                  fromEvent(event, timeLabel: formatClock(event.startAt)),
            ];
            sortTodayItems(items);
            if (items.isEmpty) return const SizedBox.shrink();
            return Column(
              children: <Widget>[
                for (final HomeTodayItem item in items) _TodayTile(item: item),
              ],
            );
          },
    );
  }

  Widget _tasksSection() {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return HomeSection<List<CampusTask>>(
      title: l10n.homeTasks,
      icon: Icons.checklist_outlined,
      trailing: const DemoSourceBadge(source: DataSourceSource.tasks),
      future: _tasks,
      emptyMessage: l10n.homeNoTasks,
      builder: (BuildContext context, List<CampusTask> tasks) {
        final List<CampusTask> open = <CampusTask>[
          for (final CampusTask task in tasks)
            if (task.isOpen) task,
        ];
        // 截止时间最近的排在前面；没有截止时间的排最后。
        // Nearest deadline first; tasks without one go last.
        open.sort((CampusTask a, CampusTask b) {
          final DateTime? left = a.deadline;
          final DateTime? right = b.deadline;
          if (left == null && right == null) return a.title.compareTo(b.title);
          if (left == null) return 1;
          if (right == null) return -1;
          return left.compareTo(right);
        });
        return Column(
          children: <Widget>[
            for (final CampusTask task in open.take(4)) TaskTile(task: task),
          ],
        );
      },
    );
  }

  Widget _campusSection() {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return HomeSection<List<Announcement>>(
      title: l10n.homeCampus,
      icon: Icons.campaign_outlined,
      trailing: const DemoSourceBadge(source: DataSourceSource.announcements),
      future: _announcements,
      emptyMessage: l10n.homeNoCampusItems,
      builder: (BuildContext context, List<Announcement> announcements) {
        final List<Announcement> sorted = List<Announcement>.of(announcements)
          ..sort(
            (Announcement a, Announcement b) =>
                b.publishedAt.compareTo(a.publishedAt),
          );
        return Column(
          children: <Widget>[
            for (final Announcement announcement in sorted.take(3))
              TransactionTile(
                transaction: AnnouncementTransaction(announcement),
                onTap: () => showTransactionDetails(
                  context,
                  transaction: AnnouncementTransaction(announcement),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _quickAccessSection() {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return HomeSection<List<CampusService>>(
      title: l10n.homeQuickAccess,
      icon: Icons.grid_view_outlined,
      trailing: const DataSourceBadge(),
      future: _quickAccess,
      emptyMessage: l10n.stateEmpty,
      builder: (BuildContext context, List<CampusService> services) {
        return QuickAccessGrid(
          services: services,
          repository: CampusRepositoryScope.of(context),
        );
      },
    );
  }
}

/// 一条今日安排 / one entry in Today.
class _TodayTile extends StatelessWidget {
  const _TodayTile({required this.item});

  final HomeTodayItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 64,
            child: Text(
              item.timeLabel,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(item.title, style: theme.textTheme.bodyLarge),
                if (item.subtitle.isNotEmpty)
                  Text(
                    item.subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Icon(item.icon, size: 18, color: theme.colorScheme.outline),
        ],
      ),
    );
  }
}
