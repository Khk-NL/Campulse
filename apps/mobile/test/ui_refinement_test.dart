import 'dart:io';
import 'dart:ui' as ui;

import 'package:campus_mobile/core/theme/campus_theme.dart';
import 'package:campus_mobile/features/shared/widgets/workspace_layout.dart';
import 'package:campus_mobile/features/study/course_note_repository.dart';
import 'package:campus_mobile/features/study/course_notes_page.dart';
import 'package:campus_mobile/features/study/review_card_repository.dart';
import 'package:campus_mobile/features/study/review_cards_page.dart';
import 'package:campus_mobile/features/study/study_repository.dart';
import 'package:campus_mobile/features/study/task_planner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const previewKey = ValueKey('ui-preview');
Widget surface(Widget child, {bool dark = false}) => MaterialApp(
  theme: previewTheme(dark),
  home: RepaintBoundary(key: previewKey, child: child),
);
ThemeData previewTheme(bool dark) {
  final theme = dark ? CampusTheme.dark() : CampusTheme.light();
  return const bool.fromEnvironment('CAPTURE_UI')
      ? theme.copyWith(
          textTheme: theme.textTheme.apply(
            fontFamily: 'CampulsePreview',
            displayColor: theme.colorScheme.onSurface,
            bodyColor: theme.colorScheme.onSurface,
          ),
          chipTheme: theme.chipTheme.copyWith(
            labelStyle: theme.chipTheme.labelStyle?.copyWith(
              fontFamily: 'CampulsePreview',
            ),
          ),
          appBarTheme: theme.appBarTheme.copyWith(
            titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(
              fontFamily: 'CampulsePreview',
            ),
          ),
        )
      : theme;
}

void viewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_UI')) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(previewKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('../../.tools/ui-refinement')
      ..createSync(recursive: true);
    await File('${directory.path}/$name.png')
        .writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    if (!const bool.fromEnvironment('CAPTURE_UI')) return;
    for (final entry in {
      'CampulsePreview': Platform.environment['CAMPULSE_UI_FONT'],
      'MaterialIcons': Platform.environment['CAMPULSE_UI_ICON_FONT'],
    }.entries) {
      if (entry.value == null) continue;
      final loader = FontLoader(entry.key)
        ..addFont(
          File(entry.value!)
              .readAsBytes()
              .then((bytes) => ByteData.sublistView(bytes)),
        );
      await loader.load();
    }
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'plan time filters use due dates and retain undated plans in all',
    (tester) async {
      viewport(tester, const Size(430, 1100));
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      StudyActivity task(String title, DateTime? date) => StudyActivity(
        id: title,
        course: '学习与生活',
        title: title,
        objective: '',
        deadline: date?.toIso8601String() ?? '',
      );
      final tasks = [
        task('整理课堂笔记', today),
        task('完成项目报告', today.add(const Duration(days: 3))),
        task('补交阅读记录', today.subtract(const Duration(days: 1))),
        task('记录一个新想法', null),
      ];
      await tester.pumpWidget(
        surface(
          Scaffold(
            body: TaskPlanner(
              activities: tasks,
              onSave: (_) async => true,
              onOpen: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('记录一个新想法'), findsOneWidget);
      await capture(tester, 'plans-mobile');
      await tester.tap(find.widgetWithText(ChoiceChip, '今天'));
      await tester.pumpAndSettle();
      expect(find.text('整理课堂笔记'), findsOneWidget);
      expect(find.text('完成项目报告'), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, '未来七天'));
      await tester.pumpAndSettle();
      expect(find.text('完成项目报告'), findsOneWidget);
      expect(find.text('补交阅读记录'), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, '逾期待办'));
      await tester.pumpAndSettle();
      expect(find.text('补交阅读记录'), findsOneWidget);
      expect(find.text('整理课堂笔记'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('source library combines file filters with content search', (
    tester,
  ) async {
    viewport(tester, const Size(1100, 900));
    final repo = LocalCourseNoteRepository(
      await SharedPreferences.getInstance(),
    );
    await repo.save(
      CourseNote(
        id: 'pdf',
        courseId: 'course',
        title: '线性代数教材',
        content: '矩阵与向量空间',
        attachment: 'book.pdf',
        updatedAt: DateTime.now(),
      ),
    );
    await repo.save(
      CourseNote(
        id: 'md',
        courseId: 'course',
        title: '课堂思考',
        content: '特征值的几何意义',
        updatedAt: DateTime.now(),
      ),
    );
    await tester.pumpWidget(
      surface(CourseNotesPage(courseId: 'course', repository: repo)),
    );
    await tester.pumpAndSettle();
    await capture(tester, 'sources-desktop');
    await tester.tap(find.widgetWithText(ChoiceChip, 'PDF 教材'));
    await tester.pumpAndSettle();
    expect(find.text('线性代数教材'), findsOneWidget);
    expect(find.text('课堂思考'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, '文字笔记'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '查找资料'), '几何');
    await tester.pumpAndSettle();
    expect(find.text('课堂思考'), findsOneWidget);
    expect(find.text('线性代数教材'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('due card view starts the actual earliest review dialog', (
    tester,
  ) async {
    viewport(tester, const Size(600, 1100));
    final repo = LocalReviewCardRepository(
      await SharedPreferences.getInstance(),
    );
    for (final (id, days) in [('到期问题', -1), ('未来问题', 3)]) {
      await repo.save(
        ReviewCard(
          id: id,
          courseId: 'course',
          front: id,
          back: '解释和例子',
          due: DateTime.now().add(Duration(days: days)),
        ),
      );
    }
    await tester.pumpWidget(
      surface(ReviewCardsPage(courseId: 'course', repository: repo)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '到期复习'));
    await tester.pumpAndSettle();
    expect(find.text('到期问题'), findsOneWidget);
    expect(find.text('未来问题'), findsNothing);
    await capture(tester, 'review-mobile');
    await tester.tap(find.text('开始复习'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, '显示答案'), findsOneWidget);
    await tester.tap(find.text('显示答案'));
    await tester.pumpAndSettle();
    expect(find.text('解释和例子'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'workspace components adapt to narrow large-text ${dark ? 'dark' : 'light'} mode',
      (tester) async {
        viewport(tester, const Size(320, 900));
        await tester.pumpWidget(
          surface(
            Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.6)),
                child: Scaffold(
                  body: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const WorkspaceBanner(
                        eyebrow: 'CAMPULSE',
                        title: '课程资料与学习工作台',
                        subtitle: '从课程出发，整理每天的学习。',
                        icon: Icons.auto_stories_outlined,
                      ),
                      WorkspaceAction(
                        title: '课程资料库',
                        subtitle: '教材、笔记与复习',
                        icon: Icons.book_outlined,
                        onTap: () {},
                      ),
                      const WorkspaceMetric(
                        value: '128',
                        label: '资料数量',
                        icon: Icons.library_books_outlined,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            dark: dark,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
