import 'package:campus_mobile/data/models/course.dart';
import 'package:campus_mobile/features/study/study_repository.dart';
import 'package:campus_mobile/features/shared/widgets/workspace_layout.dart';
import 'package:flutter/material.dart';

/// Personal plans share the existing owner-scoped study workspace.
class TaskPlanner extends StatefulWidget {
  const TaskPlanner({
    super.key,
    required this.activities,
    required this.onSave,
    required this.onOpen,
    this.course,
  });
  final List<StudyActivity> activities;
  final Future<bool> Function(StudyActivity) onSave;
  final ValueChanged<StudyActivity> onOpen;
  final Course? course;
  @override
  State<TaskPlanner> createState() => _TaskPlannerState();
}

class _TaskPlannerState extends State<TaskPlanner> {
  bool _completed = false, _busy = false;
  String _query = '';
  String? _tag;
  int _sort = 0;
  String _timeScope = 'all';

  bool _matchesTime(StudyActivity task, DateTime today) {
    final due = task.dueDate;
    return switch (_timeScope) {
      'today' =>
        due != null &&
            !due.isBefore(today) &&
            due.isBefore(today.add(const Duration(days: 1))),
      'week' =>
        due != null &&
            !due.isBefore(today) &&
            due.isBefore(today.add(const Duration(days: 7))),
      'overdue' => due != null && due.isBefore(today),
      _ => true,
    };
  }

  List<StudyActivity> get _tasks =>
      widget.activities.where((StudyActivity x) => !x.isNotebook).toList();

  Future<void> _save(StudyActivity task) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bool saved = await widget.onSave(task);
      if (mounted && saved) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(content: Text(task.isCompleted ? '已归档到已完成' : '计划已保存')),
          );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit([StudyActivity? task]) async {
    final StudyActivity? result = await showTaskEditor(
      context,
      course: widget.course,
      task: task,
    );
    if (result != null && mounted) await _save(result);
  }

  @override
  Widget build(BuildContext context) {
    final List<StudyActivity> tasks = _tasks;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final List<StudyActivity> section = tasks
        .where((StudyActivity x) => x.isCompleted == _completed)
        .toList();
    final List<String> tags =
        section
            .expand((StudyActivity x) => x.tags)
            .where((String x) => x.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final String? tag = tags.contains(_tag) ? _tag : null;
    final List<StudyActivity> visible = section
        .where(
          (StudyActivity x) =>
              (_completed || _matchesTime(x, today)) &&
              (tag == null || x.tags.contains(tag)) &&
              '${x.title} ${x.objective} ${x.course} ${x.tags.join(' ')}'
                  .toLowerCase()
                  .contains(_query.toLowerCase()),
        )
        .toList();
    visible.sort((StudyActivity a, StudyActivity b) {
      if (_completed) return b.completedAt!.compareTo(a.completedAt!);
      if (_sort == 1) return b.priority.compareTo(a.priority);
      if (_sort == 2) return a.title.compareTo(b.title);
      final int due = (a.dueDate ?? DateTime(9999)).compareTo(
        b.dueDate ?? DateTime(9999),
      );
      return due != 0 ? due : b.priority.compareTo(a.priority);
    });
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        WorkspaceBanner(
          eyebrow: 'YOUR NEXT STEP',
          title: widget.course?.name ?? '我的计划',
          subtitle: '收集想法，安排优先级，一件一件完成。',
          icon: Icons.checklist_rounded,
        ),
        const SizedBox(height: 16),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: <ButtonSegment<bool>>[
            ButtonSegment(
              value: false,
              label: Text('待办 ${tasks.where((x) => !x.isCompleted).length}'),
              icon: const Icon(Icons.list_alt),
            ),
            ButtonSegment(
              value: true,
              label: Text('已完成 ${tasks.where((x) => x.isCompleted).length}'),
              icon: const Icon(Icons.inventory_2_outlined),
            ),
          ],
          selected: {_completed},
          onSelectionChanged: (Set<bool> value) => setState(() {
            _completed = value.first;
            _tag = null;
          }),
        ),
        const SizedBox(height: 12),
        if (!_completed) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in const {
                'all': '全部时间',
                'today': '今天',
                'week': '未来七天',
                'overdue': '逾期待办',
              }.entries)
                ChoiceChip(
                  showCheckmark: false,
                  label: Text(entry.value),
                  selected: _timeScope == entry.key,
                  onSelected: (_) => setState(() => _timeScope = entry.key),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  hintText: '搜索计划',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (String value) => setState(() => _query = value),
              ),
            ),
            IconButton(
              tooltip: '新建计划',
              onPressed: _busy ? null : () => _edit(),
              icon: const Icon(Icons.add),
            ),
            PopupMenuButton<int>(
              tooltip: '排序',
              icon: const Icon(Icons.sort),
              onSelected: (int value) => setState(() => _sort = value),
              itemBuilder: (_) => const <PopupMenuEntry<int>>[
                PopupMenuItem(value: 0, child: Text('截止日期')),
                PopupMenuItem(value: 1, child: Text('优先级')),
                PopupMenuItem(value: 2, child: Text('名称')),
              ],
            ),
          ],
        ),
        if (tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              children: <Widget>[
                ChoiceChip(
                  showCheckmark: false,
                  label: const Text('全部标签'),
                  selected: tag == null,
                  onSelected: (_) => setState(() => _tag = null),
                ),
                for (final String value in tags)
                  ChoiceChip(
                    showCheckmark: false,
                    label: Text(value),
                    selected: tag == value,
                    onSelected: (_) => setState(() => _tag = value),
                  ),
              ],
            ),
          ),
        if (_busy) const LinearProgressIndicator(),
        const SizedBox(height: 8),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _query.isNotEmpty || tag != null
                  ? '试试其他关键词或筛选条件'
                  : _completed
                  ? '完成计划后在这里查看'
                  : '添加计划，安排接下来的事',
            ),
          ),
        for (final StudyActivity task in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _tile(context, task),
          ),
      ],
    );
  }

  Widget _tile(BuildContext context, StudyActivity task) {
    final DateTime? due = task.dueDate;
    final DateTime now = DateTime.now();
    final dueLabel = due == null
        ? task.deadline
        : MaterialLocalizations.of(context).formatMediumDate(due.toLocal());
    final bool overdue =
        !task.isCompleted &&
        due != null &&
        due.isBefore(DateTime(now.year, now.month, now.day));
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: overdue
              ? Theme.of(context).colorScheme.error.withValues(alpha: .5)
              : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        children: <Widget>[
          ListTile(
            leading: IconButton(
              tooltip: task.isCompleted ? '恢复计划' : '完成计划',
              onPressed: _busy
                  ? null
                  : () => _save(task.copyWith(completed: !task.isCompleted)),
              icon: Icon(
                task.isCompleted ? Icons.restore : Icons.radio_button_unchecked,
              ),
            ),
            title: Text(task.title),
            subtitle: Text(
              [
                if (widget.course == null) task.course,
                if (task.deadline.isNotEmpty && task.deadline != '未设定')
                  '${overdue ? '已逾期 · ' : ''}$dueLabel',
                if (task.priority > 0) task.priority == 2 ? '高优先级' : '中优先级',
                if (task.estimateMinutes > 0) '预计 ${task.estimateMinutes} 分钟',
                if (task.subtasks.isNotEmpty)
                  '${task.subtasks.where((x) => x.done).length}/${task.subtasks.length} 子任务',
                if (task.isCompleted)
                  '完成于 ${task.completedAt!.split('T').first}',
              ].join(' · '),
            ),
            onTap: () => _edit(task),
            trailing: IconButton(
              tooltip: '学习记录',
              icon: const Icon(Icons.edit_note),
              onPressed: _busy ? null : () => widget.onOpen(task),
            ),
          ),
          if (task.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Wrap(
                spacing: 6,
                children: task.tags
                    .map((String x) => Chip(label: Text(x)))
                    .toList(),
              ),
            ),
          if (!task.isCompleted && task.subtasks.isNotEmpty)
            ExpansionTile(
              title: const Text('子任务'),
              children: <Widget>[
                for (int i = 0; i < task.subtasks.length; i++)
                  CheckboxListTile(
                    title: Text(task.subtasks[i].title),
                    value: task.subtasks[i].done,
                    onChanged: _busy
                        ? null
                        : (bool? value) {
                            final List<StudySubtask> items = List.of(
                              task.subtasks,
                            );
                            items[i] = StudySubtask(
                              title: items[i].title,
                              done: value == true,
                            );
                            _save(task.copyWith(subtasks: items));
                          },
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

Future<StudyActivity?> showTaskEditor(
  BuildContext context, {
  Course? course,
  StudyActivity? task,
}) => showDialog<StudyActivity>(
  context: context,
  builder: (_) => _TaskEditor(course: course, task: task),
);

class _TaskEditor extends StatefulWidget {
  const _TaskEditor({this.course, this.task});
  final Course? course;
  final StudyActivity? task;
  @override
  State<_TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<_TaskEditor> {
  late final TextEditingController title,
      objective,
      deadline,
      tags,
      checklist,
      estimate;
  late int priority;
  @override
  void initState() {
    super.initState();
    final StudyActivity? task = widget.task;
    title = TextEditingController(text: task?.title);
    objective = TextEditingController(text: task?.objective);
    deadline = TextEditingController(text: task?.deadline);
    tags = TextEditingController(text: task?.tags.join('，'));
    checklist = TextEditingController(
      text: task?.subtasks.map((x) => x.title).join('\n'),
    );
    estimate = TextEditingController(
      text: task == null || task.estimateMinutes == 0
          ? ''
          : '${task.estimateMinutes}',
    );
    priority = task?.priority ?? 0;
  }

  @override
  void dispose() {
    for (final c in [title, objective, deadline, tags, checklist, estimate]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.task == null ? '新建计划' : '编辑计划'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: '任务名称 *'),
            ),
            TextField(
              controller: objective,
              maxLines: 2,
              decoration: const InputDecoration(labelText: '目标与备注'),
            ),
            TextField(
              controller: deadline,
              decoration: InputDecoration(
                labelText: '截止日期',
                suffixIcon: IconButton(
                  tooltip: '选择日期',
                  icon: const Icon(Icons.calendar_today_outlined),
                  onPressed: () async {
                    final DateTime now = DateTime.now();
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: now,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null && mounted) {
                      deadline.text = picked.toIso8601String().split('T').first;
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const <ButtonSegment<int>>[
                ButtonSegment(value: 0, label: Text('普通')),
                ButtonSegment(value: 1, label: Text('中优先')),
                ButtonSegment(value: 2, label: Text('高优先')),
              ],
              selected: {priority},
              onSelectionChanged: (Set<int> x) =>
                  setState(() => priority = x.first),
            ),
            TextField(
              controller: tags,
              decoration: const InputDecoration(labelText: '标签（逗号分隔）'),
            ),
            TextField(
              controller: checklist,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: '子任务（每行一项）'),
            ),
            TextField(
              controller: estimate,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '预计用时（分钟）'),
            ),
          ],
        ),
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () {
          if (title.text.trim().isEmpty) return;
          final StudyActivity base =
              widget.task ??
              StudyActivity(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                course: widget.course?.name ?? '个人学习',
                courseId: widget.course?.id,
                title: '',
                objective: '',
                deadline: '',
                source: 'personal',
              );
          final List<StudySubtask> children = checklist.text
              .split('\n')
              .map((x) => x.trim())
              .where((x) => x.isNotEmpty)
              .toSet()
              .map(
                (String x) => StudySubtask(
                  title: x,
                  done: base.subtasks.any((old) => old.title == x && old.done),
                ),
              )
              .toList();
          Navigator.pop(
            context,
            base.copyWith(
              title: title.text.trim(),
              objective: objective.text.trim(),
              deadline: deadline.text.trim(),
              priority: priority,
              tags: tags.text
                  .split(RegExp('[,，]'))
                  .map((x) => x.trim())
                  .where((x) => x.isNotEmpty)
                  .toSet()
                  .toList(),
              subtasks: children,
              estimateMinutes: (int.tryParse(estimate.text) ?? 0).clamp(
                0,
                100000,
              ),
            ),
          );
        },
        child: Text(widget.task == null ? '创建' : '保存'),
      ),
    ],
  );
}
