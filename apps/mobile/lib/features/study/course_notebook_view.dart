import 'package:campus_mobile/data/models/course.dart';
import 'package:campus_mobile/features/study/course_note_repository.dart';
import 'package:campus_mobile/features/study/study_repository.dart';
import 'package:campus_mobile/features/study/task_planner.dart';
import 'package:campus_mobile/features/shared/widgets/workspace_layout.dart';
import 'package:flutter/material.dart';

/// A mobile-first course workspace: sources, questions, then work products.
/// AI answers are shown in the linked study session, not duplicated here.
class CourseNotebookView extends StatefulWidget {
  const CourseNotebookView({
    super.key,
    required this.course,
    required this.workspace,
    required this.notes,
    required this.remote,
    required this.onAddSource,
    required this.onAddKnowledgeBase,
    required this.onOpenNotes,
    required this.onOpenCards,
    required this.onSubmitQuestion,
    required this.onOpenSession,
    required this.onAddActivity,
    required this.onOpenActivity,
    required this.onAddAgent,
    required this.onSaveActivity,
    this.onOpenRemote,
  });

  final Course course;
  final StudyWorkspace workspace;
  final List<CourseNote> notes;
  final bool remote;
  final VoidCallback onAddSource;
  final VoidCallback onAddKnowledgeBase;
  final VoidCallback onOpenNotes;
  final VoidCallback onOpenCards;
  final Future<bool> Function(String question, Set<String> sourceIds)
  onSubmitQuestion;
  final ValueChanged<StudySession> onOpenSession;
  final VoidCallback onAddActivity;
  final ValueChanged<StudyActivity> onOpenActivity;
  final VoidCallback onAddAgent;
  final Future<bool> Function(StudyActivity) onSaveActivity;
  final void Function(List<String> sources, int tab, String? agentId)?
  onOpenRemote;

  @override
  State<CourseNotebookView> createState() => _CourseNotebookViewState();
}

class _CourseNotebookViewState extends State<CourseNotebookView> {
  final TextEditingController _question = TextEditingController();
  final Set<String> _selected = <String>{};
  final Set<String> _knownIds = <String>{};
  int _tab = 0;
  bool _submitting = false;

  String _wikiId(StudyWikiEntry source) => 'wiki:${source.id}';
  String _noteId(CourseNote note) => 'note:${note.id}';

  Set<String> _availableIds(CourseNotebookView view) => <String>{
    for (final StudyWikiEntry source in view.workspace.wikiEntries)
      if (source.courseId == view.course.id) _wikiId(source),
    for (final CourseNote note in view.notes)
      if (note.content.trim().isNotEmpty || note.attachment.isNotEmpty)
        _noteId(note),
  };

  @override
  void initState() {
    super.initState();
    _knownIds.addAll(_availableIds(widget));
    _selected.addAll(_knownIds);
    _tab = _selected.isEmpty ? 0 : 1;
  }

  @override
  void didUpdateWidget(CourseNotebookView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final Set<String> newIds = _availableIds(widget);
    _selected.addAll(newIds.difference(_knownIds));
    _selected.removeWhere((String id) => !newIds.contains(id));
    _knownIds
      ..clear()
      ..addAll(newIds);
  }

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  List<StudyWikiEntry> get _sources => widget.workspace.wikiEntries
      .where((StudyWikiEntry item) => item.courseId == widget.course.id)
      .toList();

  List<StudyActivity> get _activities => widget.workspace.activities
      .where((StudyActivity item) => item.courseId == widget.course.id)
      .toList();

  List<StudySession> get _sessions {
    final Set<String> ids = _activities.map((StudyActivity a) => a.id).toSet();
    ids.add('course:${widget.course.id}:notes');
    return widget.workspace.sessions
        .where((StudySession item) => ids.contains(item.activityId))
        .toList()
      ..sort(
        (StudySession a, StudySession b) => b.updatedAt.compareTo(a.updatedAt),
      );
  }

  List<StudyKnowledgeBase> get _knowledgeBases => widget
      .workspace
      .knowledgeBases
      .where((StudyKnowledgeBase item) => item.courseId == widget.course.id)
      .toList();

  List<StudyAgent> get _agents => widget.workspace.agents
      .where((StudyAgent item) => item.courseId == widget.course.id)
      .toList();

  Future<void> _submit() async {
    final String question = _question.text.trim();
    if (question.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      final bool saved = await widget.onSubmitQuestion(question, _selected);
      if (mounted && saved) _question.clear();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _readSource(String title, String content) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.7,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              SelectableText(content.isEmpty ? '请添加笔记正文' : content),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Size viewport = MediaQuery.sizeOf(context);
    final bool compact =
        viewport.height < 500 || viewport.width > viewport.height;
    final bool desktop = viewport.width >= 1180;
    return Column(
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: compact
              ? const EdgeInsets.fromLTRB(16, 6, 16, 6)
              : const EdgeInsets.fromLTRB(20, 18, 20, 14),
          decoration: BoxDecoration(color: colors.surfaceContainerLow),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (!compact)
                Text(
                  '课程学习空间',
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: colors.primary),
                ),
              if (!compact) const SizedBox(height: 4),
              Text(
                widget.course.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: compact
                    ? Theme.of(context).textTheme.titleMedium
                    : Theme.of(context).textTheme.headlineSmall,
              ),
              if (!compact) const SizedBox(height: 8),
              if (!compact)
                Text(
                  '${_sources.length + widget.notes.length} 份资料 · ${_sessions.length} 个问题 · ${_agents.length} 个智能体',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              if (!compact)
                Text(
                  widget.remote ? '账号已同步' : '本机保存',
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              SizedBox(height: compact ? 4 : 14),
              if (desktop)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('学习空间'),
                      selected: _tab != 2,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _tab = 1),
                    ),
                    ChoiceChip(
                      label: const Text('课程计划'),
                      selected: _tab == 2,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _tab = 2),
                    ),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: const <ButtonSegment<int>>[
                      ButtonSegment<int>(
                        value: 0,
                        label: Text('资料'),
                        icon: Icon(Icons.library_books_outlined),
                      ),
                      ButtonSegment<int>(
                        value: 1,
                        label: Text('提问'),
                        icon: Icon(Icons.forum_outlined),
                      ),
                      ButtonSegment<int>(
                        value: 2,
                        label: Text('计划'),
                        icon: Icon(Icons.checklist_outlined),
                      ),
                      ButtonSegment<int>(
                        value: 3,
                        label: Text('工作台'),
                        icon: Icon(Icons.dashboard_customize_outlined),
                      ),
                    ],
                    selected: <int>{_tab},
                    onSelectionChanged: (Set<int> value) =>
                        setState(() => _tab = value.first),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: desktop && _tab != 2
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 300,
                        child: WorkspacePanel(
                          title: '资料来源',
                          icon: Icons.library_books_outlined,
                          count: _selected.length,
                          child: _sourcePanel(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: WorkspacePanel(
                          title: '提问与探究',
                          icon: Icons.forum_outlined,
                          count: _sessions.length,
                          child: _questionPanel(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 300,
                        child: WorkspacePanel(
                          title: '创作与复习',
                          icon: Icons.auto_awesome_outlined,
                          child: _studioPanel(context),
                        ),
                      ),
                    ],
                  ),
                )
              : switch (_tab) {
                  0 => _sourcePanel(context),
                  1 => _questionPanel(context),
                  2 => TaskPlanner(
                    activities: _activities,
                    onSave: widget.onSaveActivity,
                    onOpen: widget.onOpenActivity,
                    course: widget.course,
                  ),
                  _ => _studioPanel(context),
                },
        ),
      ],
    );
  }

  Widget _sourcePanel(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: <Widget>[
      _sectionTitle(context, '我的资料', '选择资料后，可将其关联到下一条问题。'),
      if (widget.remote && widget.onOpenRemote != null)
        TextButton.icon(
          onPressed: () => widget.onOpenRemote!(_selected.toList(), 0, null),
          icon: const Icon(Icons.search),
          label: const Text('全文搜索与证据引用'),
        ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: <Widget>[
          FilledButton.tonalIcon(
            onPressed: widget.onAddSource,
            icon: const Icon(Icons.add),
            label: const Text('添加文字资料'),
          ),
          OutlinedButton.icon(
            onPressed: widget.onOpenNotes,
            icon: const Icon(Icons.note_alt_outlined),
            label: const Text('课程笔记'),
          ),
          OutlinedButton.icon(
            onPressed: widget.onOpenCards,
            icon: const Icon(Icons.style_outlined),
            label: const Text('复习卡片'),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: Text(
              '已选 ${_selected.length} 份资料',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          TextButton(
            onPressed: () => setState(() {
              if (_selected.length == _knownIds.length) {
                _selected.clear();
              } else {
                _selected.addAll(_knownIds);
              }
            }),
            child: Text(
              _selected.length == _knownIds.length && _knownIds.isNotEmpty
                  ? '清空选择'
                  : '全部选择',
            ),
          ),
        ],
      ),
      if (_sources.isEmpty && widget.notes.isEmpty)
        const _NotebookEmpty(
          icon: Icons.library_add_outlined,
          title: '先放入一份资料',
          detail: '可以粘贴课堂摘录、阅读材料或自己的整理。',
        ),
      for (final StudyWikiEntry source in _sources)
        Card(
          child: CheckboxListTile(
            value: _selected.contains(_wikiId(source)),
            onChanged: (bool? selected) => setState(() {
              if (selected == true) {
                _selected.add(_wikiId(source));
              } else {
                _selected.remove(_wikiId(source));
              }
            }),
            title: Text(source.title),
            subtitle: Text(
              '${source.topic.isEmpty ? '文字资料' : source.topic} · ${source.content}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            secondary: IconButton(
              tooltip: '阅读资料',
              icon: const Icon(Icons.open_in_new),
              onPressed: () => _readSource(source.title, source.content),
            ),
          ),
        ),
      for (final CourseNote note in widget.notes)
        Card(
          child: note.content.trim().isEmpty && !note.hasPdf
              ? ListTile(
                  leading: const Icon(Icons.picture_as_pdf_outlined),
                  title: Text(note.title),
                  subtitle: const Text('PDF 资料 · 打开课程笔记阅读'),
                  onTap: widget.onOpenNotes,
                )
              : CheckboxListTile(
                  value: _selected.contains(_noteId(note)),
                  onChanged: (bool? selected) => setState(() {
                    if (selected == true) {
                      _selected.add(_noteId(note));
                    } else {
                      _selected.remove(_noteId(note));
                    }
                  }),
                  title: Text(note.title),
                  subtitle: Text(
                    note.hasPdf ? 'PDF · 全文检索与页码引用' : note.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  secondary: IconButton(
                    tooltip: '阅读笔记',
                    icon: const Icon(Icons.open_in_new),
                    onPressed: note.hasPdf
                        ? widget.onOpenNotes
                        : () => _readSource(note.title, note.content),
                  ),
                ),
        ),
      const SizedBox(height: 20),
      _sectionTitle(context, '资料集', '按主题整理课程资料。'),
      TextButton.icon(
        onPressed: widget.onAddKnowledgeBase,
        icon: const Icon(Icons.create_new_folder_outlined),
        label: const Text('新建资料集'),
      ),
      for (final StudyKnowledgeBase base in _knowledgeBases)
        ListTile(
          leading: const Icon(Icons.folder_outlined),
          title: Text(base.name),
          subtitle: const Text('请先导入可检索的资料'),
        ),
    ],
  );

  Widget _questionPanel(BuildContext context) {
    final List<StudyWikiEntry> chosen = _sources
        .where((StudyWikiEntry source) => _selected.contains(_wikiId(source)))
        .toList();
    final List<CourseNote> chosenNotes = widget.notes
        .where((CourseNote note) => _selected.contains(_noteId(note)))
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _sectionTitle(context, '围绕这门课继续探究', '选好资料并记录问题，随后可在学习记录中向 AI 提问。'),
        const SizedBox(height: 14),
        Card(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.tune_outlined, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '引用范围 · 已选 ${chosen.length + chosenNotes.length} 份资料',
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _tab = 0),
                      child: const Text('选择资料'),
                    ),
                  ],
                ),
                if (chosen.isNotEmpty || chosenNotes.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    children: <Widget>[
                      for (final StudyWikiEntry source in chosen)
                        Chip(label: Text(source.title)),
                      for (final CourseNote note in chosenNotes)
                        Chip(label: Text(note.title)),
                    ],
                  ),
                const SizedBox(height: 10),
                TextField(
                  controller: _question,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '写下你想弄清的问题',
                    hintText: '例如：这两个概念有什么区别？',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final prompt in const [
                      '梳理这份资料的核心概念',
                      '用例子解释关键知识点',
                      '比较资料中的不同观点',
                    ])
                      ActionChip(
                        label: Text(prompt),
                        onPressed: () => _question.text = prompt,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: const Icon(Icons.arrow_forward),
                    label: Text(_submitting ? '保存中…' : '记录问题'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        _sectionTitle(context, '探究记录', '打开问题，继续补充证据、观察和结论。'),
        const SizedBox(height: 8),
        if (_sessions.isEmpty)
          const _NotebookEmpty(
            icon: Icons.question_answer_outlined,
            title: '开始你的第一个问题',
            detail: '提出第一个问题，从资料和自己的观察开始。',
          ),
        for (final StudySession session in _sessions)
          Card(
            child: ListTile(
              leading: CircleAvatar(
                child: Icon(
                  session.conclusion.isEmpty ? Icons.help_outline : Icons.check,
                ),
              ),
              title: Text(
                session.question.isEmpty ? '学习过程记录' : session.question,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${session.sourceIds.length} 份关联资料 · ${session.conclusion.isEmpty ? '继续探究' : '已有结论'}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => widget.onOpenSession(session),
            ),
          ),
      ],
    );
  }

  Widget _studioPanel(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: <Widget>[
      _sectionTitle(context, '学习工作台', '将资料和问题沉淀成自己的成果。'),
      const SizedBox(height: 10),
      Card(
        child: Column(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.note_alt_outlined),
              title: const Text('课程笔记'),
              subtitle: const Text('写作、整理与修改'),
              trailing: const Icon(Icons.chevron_right),
              onTap: widget.onOpenNotes,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.style_outlined),
              title: const Text('复习卡片'),
              subtitle: const Text('制作卡片，按到期时间复习'),
              trailing: const Icon(Icons.chevron_right),
              onTap: widget.onOpenCards,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.add_task_outlined),
              title: const Text('学习任务'),
              subtitle: Text(
                '待办 ${_activities.where((StudyActivity a) => !a.isNotebook && !a.isCompleted).length} 项',
              ),
              trailing: const Icon(Icons.add),
              onTap: widget.onAddActivity,
            ),
          ],
        ),
      ),
      for (final StudyActivity activity in _activities.where(
        (StudyActivity item) => !item.isNotebook && !item.isCompleted,
      ))
        ListTile(
          leading: const Icon(Icons.task_alt_outlined),
          title: Text(activity.title),
          subtitle: Text(activity.deadline),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => widget.onOpenActivity(activity),
        ),
      const SizedBox(height: 18),
      _sectionTitle(context, '课程智能体', '选择角色，围绕课程资料持续讨论。'),
      TextButton.icon(
        onPressed: widget.onAddAgent,
        icon: const Icon(Icons.add_circle_outline),
        label: const Text('新建智能体'),
      ),
      for (final StudyAgent agent in _agents)
        Card(
          child: ListTile(
            leading: const Icon(Icons.smart_toy_outlined),
            title: Text(agent.name),
            subtitle: Text(
              agent.description.isEmpty ? '配置草稿' : agent.description,
            ),
            onTap: widget.remote && widget.onOpenRemote != null
                ? () => widget.onOpenRemote!(_selected.toList(), 2, agent.id)
                : null,
          ),
        ),
      const SizedBox(height: 18),
      _sectionTitle(context, '学习产物', '从选中的资料生成测验、闪卡和思维导图。'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          FilledButton.icon(
            onPressed: widget.remote && widget.onOpenRemote != null
                ? () => widget.onOpenRemote!(_selected.toList(), 1, null)
                : null,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('测验 · 闪卡 · 思维导图'),
          ),
        ],
      ),
    ],
  );

  Widget _sectionTitle(BuildContext context, String title, String detail) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 3),
          Text(detail, style: Theme.of(context).textTheme.bodySmall),
        ],
      );
}

class _NotebookEmpty extends StatelessWidget {
  const _NotebookEmpty({
    required this.icon,
    required this.title,
    required this.detail,
  });
  final IconData icon;
  final String title, detail;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 32),
          const SizedBox(height: 8),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          Text(detail, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
