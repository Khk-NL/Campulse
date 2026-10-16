import 'package:campus_mobile/core/app_scope_repository.dart';
import 'package:campus_mobile/core/app_state.dart';
import 'package:campus_mobile/core/pocketbase_session.dart';
import 'package:campus_mobile/data/models/course.dart';
import 'package:campus_mobile/features/study/course_space_entry.dart';
import 'package:campus_mobile/features/timetable/timetable_page.dart';
import 'package:campus_mobile/features/timetable/course_import_page.dart';
import 'package:campus_mobile/features/timetable/user_course_repository.dart';
import 'package:flutter/material.dart';
import 'package:campus_mobile/features/shared/widgets/workspace_layout.dart';

/// 课程是一级对象；课表是时间视图，课程空间是单门课的学习记录。
class CourseHubPage extends StatefulWidget {
  const CourseHubPage({super.key, this.active = true, this.refreshToken = 0});
  final bool active;
  final int refreshToken;

  @override
  State<CourseHubPage> createState() => _CourseHubPageState();
}

class _CourseHubPageState extends State<CourseHubPage> {
  bool _timetable = false;
  Future<List<Course>> _courses = Future<List<Course>>.value(const <Course>[]);
  bool _loadQueued = false;
  String _query = '';
  bool _pinnedOnly = false;
  final _search = TextEditingController();
  static const String _pinBoard = 'courses';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CourseHubPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.active && !oldWidget.active) ||
        widget.refreshToken != oldWidget.refreshToken) {
      _load();
    }
  }

  String _text(String zh, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : zh;

  Future<void> _pin(Course course) async {
    try {
      await AppScope.read(context).favorites.toggle(_pinBoard, course.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_text('置顶保存失败，请重试', 'Please retry saving your pin')),
          ),
        );
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadQueued) return;
    _loadQueued = true;
    _load();
  }

  void _load() {
    final Future<List<Course>> next = CampusRepositoryScope.read(context)
        .fetchCourses();
    setState(() {
      _courses = next;
    });
  }

  void _openTimetable() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => Scaffold(
          appBar: AppBar(title: const Text('课程表')),
          body: const TimetablePage(),
        ),
      ),
    );
  }

  void _openCourse(Course course) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => CourseSpaceEntry(course: course),
      ),
    );
  }

  Future<void> _importCourses() async {
    final PocketBaseSession? session = PocketBaseSession.instance;
    if (session == null || !session.signedIn) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请先登录 Campulse 账号')));
      return;
    }
    final List<Course> existing;
    try {
      existing = await _courses;
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _text('请刷新课程后重试导入', 'Refresh your courses before importing'),
            ),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    final int? count = await Navigator.of(context).push<int>(
      MaterialPageRoute<int>(
        builder: (BuildContext context) => CourseImportPage(
          repository: PocketBaseUserCourseRepository(session.client),
          existing: existing,
        ),
      ),
    );
    if (count != null && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_timetable) {
      return Column(
        children: <Widget>[
          _viewSwitcher(),
          const Expanded(child: TimetablePage()),
        ],
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        _load();
        await _courses;
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: <Widget>[
          _viewSwitcher(),
          const SizedBox(height: 12),
          WorkspaceBanner(
            vivid: true,
            eyebrow: 'LEARNING LIBRARY',
            title: _text('我的课程', 'My courses'),
            subtitle: _text(
              '把教材、笔记、提问和复习收进每一门课。',
              'One space for your sources, notes, questions and review.',
            ),
            icon: Icons.auto_stories_outlined,
            actions: <Widget>[
              OutlinedButton.icon(
                onPressed: _openTimetable,
                icon: const Icon(Icons.calendar_view_week_outlined),
                label: const Text('打开课程表'),
              ),
              OutlinedButton.icon(
                onPressed: _importCourses,
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('导入课程'),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const CourseSpaceEntry(plansOnly: true),
                  ),
                ),
                icon: const Icon(Icons.checklist_outlined),
                label: const Text('我的计划'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            onChanged: (value) =>
                setState(() => _query = value.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: _text(
                '搜索课程、教师或教室',
                'Search courses, teachers or rooms',
              ),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: _text('清空搜索', 'Clear search'),
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text(_text('全部课程', 'All courses')),
                selected: !_pinnedOnly,
                showCheckmark: false,
                onSelected: (_) => setState(() => _pinnedOnly = false),
              ),
              ChoiceChip(
                label: Text(_text('置顶课程', 'Pinned courses')),
                avatar: const Icon(Icons.push_pin_outlined, size: 18),
                selected: _pinnedOnly,
                showCheckmark: false,
                onSelected: (_) => setState(() => _pinnedOnly = true),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<Course>>(
            future: _courses,
            builder: (BuildContext context, AsyncSnapshot<List<Course>> snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              if (snapshot.hasError) {
                return Card(
                  child: ListTile(
                    title: const Text('课程加载失败'),
                    subtitle: Text('${snapshot.error}'),
                    trailing: TextButton(
                      onPressed: _load,
                      child: const Text('重试'),
                    ),
                  ),
                );
              }
              final List<Course> courses = snapshot.data ?? const <Course>[];
              if (courses.isEmpty) {
                return const Card(child: ListTile(title: Text('导入课表，开始整理课程')));
              }
              final favorites = AppScope.of(context).favorites;
              final visible =
                  courses
                      .where(
                        (course) =>
                            (!_pinnedOnly ||
                                favorites.contains(_pinBoard, course.id)) &&
                            '${course.name} ${course.teacher} ${course.location}'
                                .toLowerCase()
                                .contains(_query),
                      )
                      .toList()
                    ..sort((a, b) {
                      final pinned =
                          (favorites.contains(_pinBoard, b.id) ? 1 : 0)
                              .compareTo(
                                favorites.contains(_pinBoard, a.id) ? 1 : 0,
                              );
                      return pinned == 0 ? a.name.compareTo(b.name) : pinned;
                    });
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    _text(
                      '${visible.length} / ${courses.length} 门课程',
                      '${visible.length} / ${courses.length} courses',
                    ),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 12),
                  if (visible.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _text(
                          '调整搜索词，或为常学课程添加置顶。',
                          'Adjust your search or pin a course you study often.',
                        ),
                      ),
                    ),
                  WorkspaceGrid(
                    minWidth: 310,
                    children: [
                      for (final course in visible)
                        _courseCard(
                          course,
                          favorites.contains(_pinBoard, course.id),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _courseCard(Course course, bool pinned) {
    final theme = Theme.of(context);
    final palette = [
      theme.colorScheme.primary,
      theme.colorScheme.tertiary,
      theme.colorScheme.secondary,
    ];
    final accent =
        palette[course.id.codeUnits.fold<int>(0, (sum, c) => sum + c) %
            palette.length];
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openCourse(course),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: accent, width: 4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: accent.withValues(alpha: .12),
                    foregroundColor: accent,
                    child: const Icon(Icons.menu_book_outlined),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: _text(
                      pinned ? '取消置顶' : '置顶课程',
                      pinned ? 'Unpin course' : 'Pin course',
                    ),
                    onPressed: () => _pin(course),
                    icon: Icon(
                      pinned ? Icons.push_pin : Icons.push_pin_outlined,
                      color: accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                course.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                [
                  if (course.teacher.isNotEmpty) course.teacher,
                  if (course.location.isNotEmpty) course.location,
                  if (course.isDemo) '演示课程',
                ].join(' · '),
              ),
              if (course.scheduleRule?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text(course.scheduleRule!, style: theme.textTheme.bodySmall),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Icon(Icons.library_books_outlined, size: 16, color: accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _text('资料 · 提问 · 复习', 'Sources · Ask · Review'),
                      style: theme.textTheme.labelMedium,
                    ),
                  ),
                  Icon(Icons.arrow_forward_rounded, size: 18, color: accent),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _viewSwitcher() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: SegmentedButton<bool>(
      showSelectedIcon: false,
      segments: const <ButtonSegment<bool>>[
        ButtonSegment<bool>(
          value: false,
          label: Text('课程列表'),
          icon: Icon(Icons.school_outlined),
        ),
        ButtonSegment<bool>(
          value: true,
          label: Text('课程表'),
          icon: Icon(Icons.calendar_view_week_outlined),
        ),
      ],
      selected: <bool>{_timetable},
      onSelectionChanged: (Set<bool> value) =>
          setState(() => _timetable = value.first),
    ),
  );
}
