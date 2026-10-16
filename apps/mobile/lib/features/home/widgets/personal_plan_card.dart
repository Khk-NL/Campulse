import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:campus_mobile/core/pocketbase_session.dart';
import 'package:campus_mobile/features/study/course_space_entry.dart';
import 'package:campus_mobile/features/study/pocketbase_study_repository.dart';
import 'package:campus_mobile/features/study/sqlite_study_repository.dart';
import 'package:campus_mobile/features/study/study_repository.dart';
import 'package:campus_mobile/features/study/task_planner.dart';

/// 首页与课程计划共用一份工作区。
class PersonalPlanCard extends StatefulWidget {
  const PersonalPlanCard({super.key, this.repository, this.refreshToken = 0});
  final StudyRepository? repository;
  final int refreshToken;
  @override
  State<PersonalPlanCard> createState() => _PersonalPlanCardState();
}

class _PersonalPlanCardState extends State<PersonalPlanCard> {
  StudyRepository? _repository;
  StudyWorkspace? _workspace;
  String? _error;
  bool _busy = false;
  int _readVersion = 0;
  bool get _needsLogin =>
      widget.repository == null &&
      PocketBaseSession.instance != null &&
      !PocketBaseSession.instance!.signedIn;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PersonalPlanCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) _load();
  }

  Future<void> _load() async {
    if (_needsLogin || _busy) return;
    final version = ++_readVersion;
    try {
      _repository ??=
          widget.repository ??
          (PocketBaseSession.instance?.signedIn == true
              ? PocketBaseStudyRepository(PocketBaseSession.instance!.client)
              : const String.fromEnvironment('STUDY_STORAGE') == 'sqlite'
              ? SqliteStudyRepository()
              : LocalStudyRepository(await SharedPreferences.getInstance()));
      final workspace = await _repository!.load();
      if (mounted && version == _readVersion) {
        setState(() {
          _workspace = workspace;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted && version == _readVersion) {
        setState(() => _error = '待办加载失败，请重试');
      }
    }
  }

  Future<void> _save(StudyActivity task) async {
    if (_busy || _repository == null) return;
    _readVersion++;
    setState(() => _busy = true);
    try {
      // 重新读回，保留从课程页写入的笔记、会话和其他计划。
      final workspace = StudyWorkspace.fromJson(
        (await _repository!.load()).toJson(),
      );
      final index = workspace.activities.indexWhere(
        (item) => item.id == task.id,
      );
      if (index < 0) {
        workspace.activities.add(task);
      } else {
        workspace.activities[index] = task;
      }
      await _repository!.save(workspace);
      if (mounted) {
        setState(() {
          _workspace = workspace;
          _error = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(task.isCompleted ? '已归档到已完成' : '计划已保存')),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = '保存失败，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit([StudyActivity? task]) async {
    final result = await showTaskEditor(context, task: task);
    if (result != null && mounted) await _save(result);
  }

  Future<void> _openPlans() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const CourseSpaceEntry(plansOnly: true),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final activities = (_workspace?.activities ?? <StudyActivity>[])
        .where((item) => !item.isNotebook)
        .toList();
    final pending = activities.where((item) => !item.isCompleted).toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));
    final completed = activities.where((item) => item.isCompleted).length;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.secondaryContainer.withValues(alpha: .65),
              scheme.surface,
            ],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: scheme.secondaryContainer,
                  foregroundColor: scheme.onSecondaryContainer,
                  child: const Icon(Icons.checklist_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '我的计划',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text('${pending.length} 项待办 · $completed 项已完成'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (activities.isNotEmpty) ...[
              Semantics(
                label: '计划完成进度',
                value: '$completed / ${activities.length}',
                child: LinearProgressIndicator(value: completed / activities.length, minHeight: 6),
              ),
              const SizedBox(height: 14),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _needsLogin
                      ? _openPlans
                      : (_busy || _workspace == null ? null : () => _edit()),
                  icon: Icon(_needsLogin ? Icons.login : Icons.add),
                  label: Text(_needsLogin ? '登录管理待办' : '新增待办'),
                ),
                TextButton.icon(
                  onPressed: _openPlans,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('全部计划'),
                ),
              ],
            ),
            if (_error != null)
              Row(
                children: [
                  Expanded(
                    child: Text(_error!, style: TextStyle(color: scheme.error)),
                  ),
                  TextButton(
                    onPressed: _busy ? null : _load,
                    child: const Text('重新加载'),
                  ),
                ],
              ),
            if (!_needsLogin && _workspace == null && _error == null)
              const LinearProgressIndicator(),
            AnimatedSize(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 240),
              alignment: Alignment.topCenter,
              child: Column(
                children: [
                  for (final task in pending.take(3))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Checkbox(
                        value: false,
                        onChanged: _busy
                            ? null
                            : (_) => _save(task.copyWith(completed: true)),
                      ),
                      title: Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        task.source == 'demo'
                            ? '示例计划 · ${task.deadline}'
                            : task.deadline.isEmpty
                            ? '随时开始'
                            : task.deadline,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _busy ? null : () => _edit(task),
                    ),
                  if (_workspace != null && pending.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('今天想完成什么？记下第一件事。'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
