/// 课程表页面 / the timetable screen (§9).
///
/// §9 要求课程表回答「本周上什么课」，而不是把课程堆成一张列表。因此这一页按教学周
/// 组织：顶部切周、中部按节次 × 星期排布网格、下面挂上与课程相关的待办与通知。
///
/// §9 asks the timetable to answer "what do I have this week" rather than to dump courses
/// into a list. So the screen is organised by teaching week: week switching on top, a
/// period × weekday grid in the middle, and the course's tasks and notices below.
///
/// 这一页**不写 Scaffold / AppBar**：外壳已经提供顶栏，这里的根节点就是内容本身。
/// This page deliberately builds **no Scaffold or AppBar**: the shell owns the top bar, so
/// the root widget here is the content itself.
library;

import 'package:campus_mobile/core/app_scope_repository.dart';
import 'package:campus_mobile/core/config/university_config.dart';
import 'package:campus_mobile/core/i18n/app_i18n.dart';
import 'package:campus_mobile/core/theme/campus_theme.dart';
import 'package:campus_mobile/data/models/course.dart';
import 'package:campus_mobile/data/models/term_calendar.dart';
import 'package:campus_mobile/data/models/transaction.dart';
import 'package:campus_mobile/data/repositories/campus_repository.dart';
import 'package:campus_mobile/data/repositories/data_source_mode.dart';
import 'package:campus_mobile/features/home/widgets/task_tile.dart';
import 'package:campus_mobile/features/inbox/widgets/transaction_details_sheet.dart';
import 'package:campus_mobile/features/shared/widgets/course_details_sheet.dart';
import 'package:campus_mobile/features/shared/widgets/state_views.dart';
import 'package:campus_mobile/features/shared/widgets/transaction_tile.dart';
import 'package:campus_mobile/features/timetable/widgets/timetable_grid.dart';
import 'package:campus_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// 课程通知的原始输入 / the raw inputs behind the course notices.
///
/// 打包成一份不可变输入，是为了让"按周过滤"发生在 `build` 里，而不是在取数时算死：
/// 调课通知必须跟着当前周进出列表。
/// Bundled so the week filter runs in `build` rather than being frozen at fetch time: a schedule
/// change must enter and leave the list with the week on screen.
class _NoticeInputs {
  const _NoticeInputs({
    required this.announcements,
    required this.events,
    required this.courses,
  });

  final List<Announcement> announcements;
  final List<CampusEvent> events;
  final List<Course> courses;
}

/// 课程表 / the timetable.
class TimetablePage extends StatefulWidget {
  const TimetablePage({super.key, this.refreshToken = 0});
  final int refreshToken;

  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  // 空 future 而不是 `late`：首帧永远不会读到未初始化字段。
  // Empty futures rather than `late`: the first frame never reads something
  // uninitialised.
  Future<List<Course>> _courses = Future<List<Course>>.value(const <Course>[]);
  Future<List<CampusTask>> _tasks = Future<List<CampusTask>>.value(
    const <CampusTask>[],
  );

  /// 通知的原始输入（公告 / 活动 / 课程），合并留给 build 按当前周计算。
  /// The raw notice inputs; the merge happens in build, filtered by the week on screen.
  Future<_NoticeInputs> _noticeInputs = Future<_NoticeInputs>.value(
    const _NoticeInputs(
      announcements: <Announcement>[],
      events: <CampusEvent>[],
      courses: <Course>[],
    ),
  );

  /// 本次运行使用的学期日历（**唯一**决定"第几教学周"的地方）。
  ///
  /// 它在 `didChangeDependencies` 里建好，因此首帧之前一定已经存在。锚点未核实时
  /// （`isVerified == false`）界面会标注出来，而不是把演示值当成真实学期显示。
  ///
  /// The term calendar this run uses — the only place that decides "which teaching week it is".
  /// Built in `didChangeDependencies`, so it exists before the first frame; when the anchor is
  /// unverified the UI says so instead of presenting a demo value as fact.
  late TermCalendar _term;

  /// 正在展示的教学周 / the teaching week currently shown.
  int _week = 1;

  /// 首次加载已经排过队了吗。/ whether the first load has already been queued.
  bool _loadQueued = false;

  @override
  void didUpdateWidget(TimetablePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshToken != oldWidget.refreshToken) _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 依赖注入只能在 didChangeDependencies 里读取（initState 里读会触发断言）。
    // Injected dependencies are only readable in didChangeDependencies; doing it in
    // initState trips an assertion.
    if (_loadQueued) return;
    _loadQueued = true;
    // 学期锚点来自高校配置：通用层不认识任何学期，页面也不该自己算一个。
    // The term anchor comes from the university config: the generic layer knows no term, and a
    // page must not invent one either.
    _term = UniversityConfigs.defaultConfig.termCalendar(DateTime.now());
    _week = _term.currentWeekOf(DateTime.now()) ?? 1;
    _load();
  }

  void _load() {
    // read 而非 of：_load 是命令式路径，仓库在应用生命周期内不变，无需订阅。
    // read, not of: _load is imperative and the repository never changes, so there is
    // nothing to subscribe to.
    final CampusRepository repository = CampusRepositoryScope.read(context);
    final Future<List<Course>> courses = repository.fetchCourses();
    final Future<List<CampusTask>> tasks = repository.fetchTasks();
    final Future<List<Announcement>> announcements = repository
        .fetchAnnouncements();
    final Future<List<CampusEvent>> events = repository.fetchEvents();
    // 判断公告有没有提到某门课需要课程名，因此等三者都到齐再合并。
    // Matching an announcement against a course needs the course names, so the merge waits
    // until all three have arrived.
    //
    // 这里只把**原始数据**备好，合并留给 build：调课事件要按"当前在看第几周"过滤，而周次会随
    // 切换器变。此前合并结果是一次性的 `Future`，于是 `concernsWeek` 永远没机会生效——
    // 一个从不被调用的契约字段等于没有。
    //
    // Only the raw inputs are prepared here; the merge happens in build, because a schedule change
    // must be filtered by the week on screen and that changes with the switcher. The merged list
    // used to be a one-shot `Future`, which left `concernsWeek` with no opportunity to run — an
    // unused contract field is the same as no field.
    final Future<_NoticeInputs> noticeInputs =
        Future.wait<Object>(<Future<Object>>[announcements, events, courses])
            .then(
              (List<Object> results) => _NoticeInputs(
                announcements: results[0] as List<Announcement>,
                events: results[1] as List<CampusEvent>,
                courses: results[2] as List<Course>,
              ),
            );
    if (!mounted) {
      _courses = courses;
      _tasks = tasks;
      _noticeInputs = noticeInputs;
      return;
    }
    // 块体而不是箭头体：赋的值是 Future，箭头体会把它当作 setState 回调的返回值。
    // A block body, not an arrow: the assigned values are Futures, which an arrow body
    // would hand back as setState's return value and trip a runtime assertion.
    setState(() {
      _courses = courses;
      _tasks = tasks;
      _noticeInputs = noticeInputs;
    });
  }

  /// 与课程有关的通知：活动按 `relatedCourseId`，公告按正文是否提到课程名。
  /// Course-related notices: events by `relatedCourseId`, announcements by whether their
  /// text mentions a course name.
  ///
  /// 调课事件额外按**周次**过滤：它只属于它调的那一周（`CampusEvent.concernsWeek`）。
  /// 不看周次的话，"第 5 周调课"会出现在第 3、4、9 周的课表上，用户无从判断它什么时候生效。
  ///
  /// A schedule change is additionally filtered by week: it belongs to the week it moves. Without
  /// that, "week 5 moved to room 305" shows up in weeks 3, 4 and 9 alike, leaving the user unable
  /// to tell when it applies.
  static List<CampusTransaction> _courseNotices({
    required List<Announcement> announcements,
    required List<CampusEvent> events,
    required List<Course> courses,
    required int week,
  }) {
    final List<String> names = <String>[
      for (final Course course in courses)
        if (course.name.isNotEmpty) course.name.toLowerCase(),
    ];
    final List<CampusTransaction> notices = <CampusTransaction>[
      for (final CampusEvent event in events)
        if (event.relatedCourseId != null && event.concernsWeek(week))
          EventTransaction(event),
      for (final Announcement announcement in announcements)
        if (_mentionsCourse(announcement, names))
          AnnouncementTransaction(announcement),
    ];
    notices.sort(
      (CampusTransaction a, CampusTransaction b) =>
          b.occurredAt.compareTo(a.occurredAt),
    );
    return notices;
  }

  static bool _mentionsCourse(Announcement announcement, List<String> names) {
    if (names.isEmpty) return false;
    final String haystack =
        '${announcement.title} ${announcement.body} ${announcement.sourceName ?? ''}'
            .toLowerCase();
    for (final String name in names) {
      if (haystack.contains(name)) return true;
    }
    return false;
  }

  /// 正在看本周时高亮今天那一列，其余周不高亮。
  /// Today's column is highlighted only while the current week is on screen.
  int? _highlightWeekday() {
    // "今天"的判定与"本周"标记同源：都用那一个学期日历，不再各算一份。
    // The "today" test shares one source with the "this week" badge: the same term calendar.
    if (_term.currentWeekOf(DateTime.now()) != _week) return null;
    return DateTime.now().weekday;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final CampusRepository repository = CampusRepositoryScope.of(context);

    return RefreshIndicator(
      onRefresh: () async => _load(),
      child: ListView(
        padding: CampusColors.pagePadding,
        children: <Widget>[
          _weekSwitcher(context, l10n, theme),
          const SizedBox(height: CampusColors.gap),
          _TimetableSection(
            title: l10n.timetableTitle,
            icon: Icons.calendar_view_week_outlined,
            badges: _demoBadges(
              context,
              repository,
              l10n,
              const <DataSourceSource>[DataSourceSource.courses],
            ),
            body: _gridBody(context, l10n),
          ),
          const SizedBox(height: CampusColors.gap),
          _TimetableSection(
            title: l10n.timetableCourseTasks,
            icon: Icons.checklist_outlined,
            badges: _demoBadges(
              context,
              repository,
              l10n,
              const <DataSourceSource>[DataSourceSource.tasks],
            ),
            body: _tasksBody(context, l10n),
          ),
          const SizedBox(height: CampusColors.gap),
          _TimetableSection(
            title: l10n.timetableCourseNotices,
            icon: Icons.campaign_outlined,
            badges: _demoBadges(
              context,
              repository,
              l10n,
              // 这一块同时来自公告与活动，两者各自可能是演示数据。
              // This block draws on both announcements and events, each of which may be
              // demo data on its own.
              const <DataSourceSource>[
                DataSourceSource.events,
                DataSourceSource.announcements,
              ],
            ),
            body: _noticesBody(context, l10n),
          ),
        ],
      ),
    );
  }

  /// 「演示数据」标记：只标注真正回退到演示数据的来源。
  /// The "demo data" badges, one per source that actually fell back to the demo dataset.
  List<Widget> _demoBadges(
    BuildContext context,
    CampusRepository repository,
    AppLocalizations l10n,
    List<DataSourceSource> sources,
  ) {
    final List<Widget> badges = <Widget>[];
    for (final DataSourceSource source in sources) {
      if (repository.sourceMode(source) != DataSourceMode.mock) continue;
      badges.add(
        TinyBadge(
          label: l10n.demoDataNotice(l10n.dataSourceSource(source)),
          icon: Icons.science_outlined,
          color: Theme.of(context).statusColors.warning,
        ),
      );
    }
    return badges;
  }

  /// 教学周切换条 / the teaching-week switcher.
  Widget _weekSwitcher(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    // "本周"只在**确实落在学期内**时才显示：锚点未核实、或今天在学期之外时，把某一周
    // 标成"本周"就是在编。
    // "This week" only when today really falls inside the term: with an unverified anchor, or a
    // date outside the term, marking a week as current would be an invention.
    final bool isCurrentWeek = _term.currentWeekOf(DateTime.now()) == _week;
    final MaterialLocalizations material = MaterialLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: <Widget>[
            IconButton(
              onPressed: _week > 1 ? _goToPreviousWeek : null,
              icon: const Icon(Icons.chevron_left),
              tooltip: l10n.timetablePreviousWeek,
            ),
            Expanded(
              child: Column(
                children: <Widget>[
                  Text(
                    l10n.timetableWeekLabel(_week),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // 具体日期区间：只有"第几周"的话，用户没法把它和真实日期对上。
                  // The actual date range: a bare week number cannot be matched to a real date.
                  Text(
                    l10n.timetableWeekDates(
                      material.formatMediumDate(_term.mondayOfWeek(_week)),
                      material.formatMediumDate(_term.sundayOfWeek(_week)),
                    ),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.timetableTermWeeks(_term.weeks),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (!_term.isVerified) ...<Widget>[
                    const SizedBox(height: 6),
                    // 诚实标注：学期起止尚未核实，周号只能当参考。
                    // Labelled honestly: the term's boundaries are unverified, so the week
                    // number is indicative only.
                    TinyBadge(
                      label: l10n.timetableTermUnverified,
                      icon: Icons.science_outlined,
                      color: theme.statusColors.warning,
                    ),
                  ],
                  if (isCurrentWeek) ...<Widget>[
                    const SizedBox(height: 6),
                    // 主色只作小面积强调：一枚"本周"标记。
                    // The primary colour is only a small accent: the "this week" chip.
                    TinyBadge(
                      label: l10n.timetableCurrentWeek,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              onPressed: _week < _term.weeks ? _goToNextWeek : null,
              icon: const Icon(Icons.chevron_right),
              tooltip: l10n.timetableNextWeek,
            ),
          ],
        ),
      ),
    );
  }

  void _goToPreviousWeek() {
    if (_week <= 1) return;
    setState(() {
      _week -= 1;
    });
  }

  void _goToNextWeek() {
    if (_week >= _term.weeks) return;
    setState(() {
      _week += 1;
    });
  }

  /// 网格分区 / the grid block.
  Widget _gridBody(BuildContext context, AppLocalizations l10n) {
    return FutureBuilder<List<Course>>(
      future: _courses,
      builder: (BuildContext context, AsyncSnapshot<List<Course>> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _SectionLoading();
        }
        final Object? error = snapshot.error;
        if (error != null) return _SectionError(message: error.toString());
        final List<Course> all = snapshot.data ?? const <Course>[];
        final List<Course> weekCourses = TimetableGrid.coursesInWeek(
          all,
          _week,
        );
        if (weekCourses.isEmpty) {
          return _SectionEmpty(message: l10n.timetableNoCourses);
        }
        return TimetableGrid(
          week: _week,
          courses: all,
          periodCount: TimetableGrid.lastPeriod(weekCourses),
          highlightWeekday: _highlightWeekday(),
          onCourseTap: (Course course) =>
              showCourseDetails(context, course: course),
        );
      },
    );
  }

  /// 课程相关待办 / the course-related tasks.
  Widget _tasksBody(BuildContext context, AppLocalizations l10n) {
    return FutureBuilder<List<CampusTask>>(
      future: _tasks,
      builder:
          (BuildContext context, AsyncSnapshot<List<CampusTask>> snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _SectionLoading();
            }
            final Object? error = snapshot.error;
            if (error != null) return _SectionError(message: error.toString());
            final List<CampusTask> tasks = <CampusTask>[
              for (final CampusTask task
                  in snapshot.data ?? const <CampusTask>[])
                if (task.relatedCourseId != null && task.isOpen) task,
            ];
            if (tasks.isEmpty) {
              return _SectionEmpty(message: l10n.timetableNoCourseTasks);
            }
            return Column(
              children: <Widget>[
                for (final CampusTask task in tasks)
                  TaskTile(
                    task: task,
                    onTap: () => showTransactionDetails(
                      context,
                      transaction: TaskTransaction(task),
                    ),
                  ),
              ],
            );
          },
    );
  }

  /// 课程相关通知 / the course-related notices.
  ///
  /// 输入是加载时取好的原始数据，**合并按当前周现算**：切换周次时，调课通知会跟着进出列表。
  /// The inputs are fetched once; the merge runs against the week on screen, so a schedule change
  /// appears and disappears as the user switches weeks.
  Widget _noticesBody(BuildContext context, AppLocalizations l10n) {
    return FutureBuilder<_NoticeInputs>(
      future: _noticeInputs,
      builder: (BuildContext context, AsyncSnapshot<_NoticeInputs> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _SectionLoading();
        }
        final Object? error = snapshot.error;
        if (error != null) return _SectionError(message: error.toString());
        final _NoticeInputs inputs =
            snapshot.data ??
            const _NoticeInputs(
              announcements: <Announcement>[],
              events: <CampusEvent>[],
              courses: <Course>[],
            );
        final List<CampusTransaction> notices = _courseNotices(
          announcements: inputs.announcements,
          events: inputs.events,
          courses: inputs.courses,
          week: _week,
        );
        if (notices.isEmpty) {
          return _SectionEmpty(message: l10n.timetableNoCourseNotices);
        }
        return Column(
          children: <Widget>[
            for (final CampusTransaction notice in notices)
              TransactionTile(
                transaction: notice,
                onTap: () =>
                    showTransactionDetails(context, transaction: notice),
              ),
          ],
        );
      },
    );
  }
}

/// 带标题的一小块内容 / one titled block.
///
/// 与首页的 `HomeSection` 同形，但标题被 `Expanded` 包住、徽标排在右侧，因此窄屏上标题
/// 先省略而不是让整行溢出——「演示数据」徽标最多可能同时出现两个。
///
/// Same shape as Home's `HomeSection`, except the title is wrapped in `Expanded` and the
/// badges sit at the end, so on a narrow screen the title ellipsises instead of overflowing
/// the row — up to two demo-data badges can appear at once.
class _TimetableSection extends StatelessWidget {
  const _TimetableSection({
    required this.title,
    required this.icon,
    required this.body,
    this.badges = const <Widget>[],
  });

  final String title;
  final IconData icon;
  final Widget body;
  final List<Widget> badges;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                // 主色只做小面积强调：标题左侧 3dp 的细竖条。
                // The primary colour stays a small accent: a 3dp bar left of the title.
                Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                for (final Widget badge in badges) ...<Widget>[
                  const SizedBox(width: 6),
                  badge,
                ],
                const SizedBox(width: 6),
                Icon(icon, size: 18, color: theme.colorScheme.outline),
              ],
            ),
            const SizedBox(height: 8),
            body,
          ],
        ),
      ),
    );
  }
}

/// 分区内的加载态 / an in-section loading state.
class _SectionLoading extends StatelessWidget {
  const _SectionLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: LoadingView(),
    );
  }
}

/// 分区内的空态 / an in-section empty state.
class _SectionEmpty extends StatelessWidget {
  const _SectionEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// 分区内的错误态 / an in-section error state.
///
/// 分区粒度下不给重试按钮：整页顶部已有下拉刷新，这里只需说明情况。
/// No retry button at section granularity: pull-to-refresh already covers the page, so this
/// only needs to explain itself.
class _SectionError extends StatelessWidget {
  const _SectionError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.error_outline, size: 16, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
