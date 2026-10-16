import 'fixtures/study_workspace_fixture.dart';
import 'package:campus_mobile/features/study/study_page.dart';
import 'package:campus_mobile/features/study/study_repository.dart';
import 'package:campus_mobile/features/study/task_planner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Store implements StudyRepository {
  StudyWorkspace workspace = buildStudyWorkspaceFixture();
  bool fail = false;
  @override
  Future<StudyWorkspace> load() async => workspace;
  @override
  Future<void> save(StudyWorkspace workspace) async {
    if (fail) throw StateError('offline');
    this.workspace = workspace;
  }
}

void main() {
  test(
    'legacy tasks default to pending; archive and subtasks survive reload',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = LocalStudyRepository(prefs);
      final workspace = buildStudyWorkspaceFixture();
      expect(workspace.activities.first.isCompleted, isFalse);
      workspace.activities[0] = workspace.activities[0].copyWith(
        completed: true,
        priority: 2,
        tags: ['期末'],
        estimateMinutes: 30,
        subtasks: [const StudySubtask(title: '整理资料', done: true)],
      );
      await store.save(workspace);
      final task = (await store.load()).activities.first;
      expect(task.isCompleted, isTrue);
      expect(task.priority, 2);
      expect(task.tags, ['期末']);
      expect(task.subtasks.single.done, isTrue);
      expect(task.estimateMinutes, 30);
      expect(task.copyWith(completed: false).completedAt, isNull);
      expect(StudyActivity.fromJson({'id': 'old'}).isCompleted, isFalse);
    },
  );

  testWidgets(
    'complete archives, completed view restores, failures roll back',
    (tester) async {
      final store = _Store();
      await tester.pumpWidget(
        MaterialApp(home: StudyPage(repository: store, plansOnly: true)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('完成计划').first);
      await tester.pumpAndSettle();
      expect(store.workspace.activities.first.isCompleted, isTrue);
      expect(find.text('校园服务需求观察'), findsNothing);
      await tester.tap(find.text('已完成 1'));
      await tester.pumpAndSettle();
      expect(find.text('校园服务需求观察'), findsOneWidget);
      await tester.tap(find.byTooltip('恢复计划'));
      await tester.pumpAndSettle();
      expect(store.workspace.activities.first.isCompleted, isFalse);
      await tester.tap(find.text('待办 2'));
      await tester.pumpAndSettle();
      store.fail = true;
      await tester.tap(find.byTooltip('完成计划').first);
      await tester.pumpAndSettle();
      expect(store.workspace.activities.every((x) => !x.isCompleted), isTrue);
      expect(find.textContaining('计划保存失败'), findsOneWidget);
    },
  );

  testWidgets('390px planner: create/edit with tags, search and subtasks', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = _Store();
    await tester.pumpWidget(
      MaterialApp(home: StudyPage(repository: store, plansOnly: true)),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ChoiceChip, '全部标签'), findsNothing);
    await tester.tap(find.byTooltip('新建计划'));
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), '复习');
    await tester.enterText(fields.at(3), '期末，期末，');
    await tester.ensureVisible(fields.at(4));
    await tester.enterText(fields.at(4), '章节一\n章节二');
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();
    expect(store.workspace.activities.last.tags, ['期末']);
    expect(store.workspace.activities.last.subtasks.length, 2);
    await tester.enterText(find.byType(TextField).first, '复习');
    await tester.pumpAndSettle();
    expect(find.text('校园服务需求观察'), findsNothing);
    await tester.tap(find.text('子任务'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('章节一'));
    await tester.tap(find.text('章节一'));
    await tester.pumpAndSettle();
    expect(store.workspace.activities.last.subtasks.first.done, isTrue);
    expect(tester.takeException(), isNull);
    expect(
      tester
          .widget<SegmentedButton<bool>>(find.byType(SegmentedButton<bool>))
          .showSelectedIcon,
      isFalse,
    );
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '全部标签'))
          .showCheckmark,
      isFalse,
    );
    expect(find.byType(TaskPlanner), findsOneWidget);
  });
}
