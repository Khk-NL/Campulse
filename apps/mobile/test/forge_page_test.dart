import 'dart:async';

import 'package:campus_mobile/features/apps/forge_page.dart';
import 'package:campus_mobile/features/apps/forge_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';

class FakeForge extends ForgeRepository {
  FakeForge() : super(PocketBase('http://example.test'));
  final rows = <RecordModel>[];
  final threads = <RecordModel>[];
  final responses = <RecordModel>[];
  final queries = <String>[];
  bool fail = false;
  @override
  String get userId => 'member1';
  @override
  bool get canWrite => true;
  @override
  Future<ResultList<RecordModel>> projects({
    int page = 1,
    String query = '',
    bool mine = false,
  }) async {
    queries.add(query);
    if (fail) throw StateError('network');
    final found = rows
        .where((r) => r.getStringValue('name').contains(query))
        .toList();
    return ResultList(items: found, totalItems: found.length, totalPages: 1);
  }

  @override
  Future<RecordModel> saveProject({
    String? id,
    required String name,
    required String summary,
    required String readme,
    required String topics,
    required bool isPublic,
    String schoolProof = '',
    String repositoryUrl = '',
  }) async {
    final row = RecordModel.fromJson({
      'id': 'project1',
      'owner': userId,
      'name': name,
      'summary': summary,
      'readme': readme,
      'topics': topics,
      'visibility': isPublic ? 'public' : 'private',
      'reviewState': 'draft',
      'repositoryUrl': repositoryUrl,
      'schoolProof': schoolProof,
    });
    rows.add(row);
    return row;
  }

  @override
  Future<RecordModel> project(String id) async => rows.first;
  @override
  Future<RecordModel> submitProject(String id) async {
    final row = await project(id);
    row.data['reviewState'] = 'pending';
    return row;
  }

  @override
  Future<ResultList<RecordModel>> stars(
    String repository, {
    int page = 1,
  }) async => ResultList(items: [], totalItems: 0);
  @override
  Future<RecordModel?> myStar(String repository) async => null;
  @override
  Future<ResultList<RecordModel>> discussions(
    String repository, {
    int page = 1,
  }) async =>
      ResultList(items: threads, totalItems: threads.length, totalPages: 1);
  @override
  Future<RecordModel> discuss(
    String repository,
    String title,
    String body,
    String kind,
  ) async {
    final row = RecordModel.fromJson({
      'id': 'thread1',
      'owner': userId,
      'repository': repository,
      'title': title,
      'body': body,
      'kind': kind,
      'status': 'open',
    });
    threads.add(row);
    return row;
  }

  @override
  Future<ResultList<RecordModel>> replies(
    String discussion, {
    int page = 1,
  }) async =>
      ResultList(items: responses, totalItems: responses.length, totalPages: 1);
  @override
  Future<RecordModel> reply(String discussion, String body) async {
    final row = RecordModel.fromJson({
      'id': 'reply1',
      'owner': userId,
      'discussion': discussion,
      'body': body,
    });
    responses.add(row);
    return row;
  }

  @override
  Future<RecordModel> discussion(String id) async =>
      threads.firstWhere((row) => row.id == id);
  @override
  Future<void> setStatus(String id, String status) async {
    (await discussion(id)).data['status'] = status;
  }
}

class PendingForge extends FakeForge {
  final pending = Completer<RecordModel>();
  @override
  Future<RecordModel> reply(String discussion, String body) => pending.future;
}

void main() {
  testWidgets('project search debounces input and clears to all projects', (
    tester,
  ) async {
    final repo = FakeForge();
    await tester.pumpWidget(MaterialApp(home: ForgePage(repository: repo)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '校');
    await tester.pump(const Duration(milliseconds: 150));
    await tester.enterText(find.byType(TextField), '校园');
    await tester.pump(const Duration(milliseconds: 299));
    expect(repo.queries, ['']);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(repo.queries, ['', '校园']);
    await tester.tap(find.byTooltip('清空搜索'));
    await tester.pumpAndSettle();
    expect(repo.queries, ['', '校园', '']);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
  });

  testWidgets(
    'submitted search cancels debounce and leaving cancels pending work',
    (tester) async {
      final repo = FakeForge();
      await tester.pumpWidget(MaterialApp(home: ForgePage(repository: repo)));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '工具');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      expect(repo.queries, ['', '工具']);
      await tester.enterText(find.byType(TextField), '待查询');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 400));
      expect(repo.queries, ['', '工具']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'project owner submits one draft and sees its review state and GitHub link',
    (tester) async {
      final repo = FakeForge();
      final row = await repo.saveProject(
        name: '待提交的项目',
        summary: '',
        readme: '',
        topics: '',
        isPublic: true,
        schoolProof: '归属材料',
        repositoryUrl: 'https://github.com/Khk-NL/Campulse',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ForgeProjectPage(repo: repo, id: row.id),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('待提交'), findsOneWidget);
      expect(find.text('GitHub 仓库'), findsOneWidget);
      await tester.tap(find.text('提交审核'));
      await tester.pumpAndSettle();
      expect(row.getStringValue('reviewState'), 'pending');
      expect(find.text('待审核'), findsOneWidget);
      expect(find.text('审核中'), findsOneWidget);
    },
  );
  testWidgets('leaving discussion during send avoids disposed input access', (
    tester,
  ) async {
    final repo = PendingForge();
    final thread = await repo.discuss('project1', '参与讨论', '内容', 'question');
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ForgeDiscussionPage(
                  repo: repo,
                  thread: thread,
                  repositoryOwner: 'member1',
                ),
              ),
            ),
            child: const Text('进入讨论'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('进入讨论'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '回复');
    await tester.tap(find.byTooltip('发送回复'));
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
    repo.pending.complete(RecordModel.fromJson({'id': 'late'}));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('进入讨论'), findsOneWidget);
  });
  testWidgets(
    'project editor persists data and disposes after route transition',
    (tester) async {
      final repo = FakeForge();
      await tester.pumpWidget(MaterialApp(home: ForgePage(repository: repo)));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('创建项目'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '项目名称'), '校园工具');
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();
      expect(repo.rows.single.getStringValue('name'), '校园工具');
      expect(find.text('校园工具'), findsOneWidget);
      expect(find.textContaining('待提交'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('community load error offers a real retry', (tester) async {
    final repo = FakeForge()..fail = true;
    await tester.pumpWidget(MaterialApp(home: ForgePage(repository: repo)));
    await tester.pumpAndSettle();
    expect(find.text('加载失败，点击重试'), findsOneWidget);
    repo.fail = false;
    await tester.tap(find.text('加载失败，点击重试'));
    await tester.pumpAndSettle();
    expect(find.text('加载失败，点击重试'), findsNothing);
  });
  testWidgets('discussion sends reply and displays server readback', (
    tester,
  ) async {
    final repo = FakeForge();
    final thread = await repo.discuss('project1', '如何参与', '欢迎交流', 'question');
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeDiscussionPage(
          repo: repo,
          thread: thread,
          repositoryOwner: 'member2',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '我想贡献文档');
    await tester.tap(find.byTooltip('发送回复'));
    await tester.pumpAndSettle();
    expect(repo.responses.single.getStringValue('body'), '我想贡献文档');
    expect(find.text('我想贡献文档'), findsOneWidget);
    expect(find.widgetWithText(TextField, '我想贡献文档'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
