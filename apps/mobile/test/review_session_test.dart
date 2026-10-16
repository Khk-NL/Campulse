import 'dart:async';

import 'package:campus_mobile/core/theme/campus_theme.dart';
import 'package:campus_mobile/features/study/review_card_repository.dart';
import 'package:campus_mobile/features/study/review_session_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

ReviewCard card(String id) => ReviewCard(
  id: id,
  courseId: 'course',
  front: '问题 $id',
  back: '答案 $id',
  due: DateTime(2020),
);

class SessionRepository implements ReviewCardRepository {
  bool fail = false;
  Completer<ReviewCard>? pending;
  int calls = 0;
  @override
  Future<List<ReviewCard>> list(String courseId) async => [
    card('a'),
    card('b'),
  ];
  @override
  Future<ReviewCard> save(ReviewCard card) async => card;
  @override
  Future<void> delete(String id) async {}
  @override
  Future<ReviewCard> review(ReviewCard item, int rating) async {
    calls++;
    if (fail) throw StateError('network');
    if (pending != null) return pending!.future;
    return item;
  }
}

void useViewport(WidgetTester tester, [Size size = const Size(600, 1000)]) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

Widget app(Widget child) =>
    MaterialApp(theme: CampusTheme.light(), home: child);

void main() {
  testWidgets('session persists each rating and finishes with real totals', (
    tester,
  ) async {
    useViewport(tester);
    SharedPreferences.setMockInitialValues({});
    final repo = LocalReviewCardRepository(
      await SharedPreferences.getInstance(),
    );
    final first = await repo.save(card('a'));
    final second = await repo.save(card('b'));
    await tester.pumpWidget(
      app(ReviewSessionPage(cards: [first, second], repository: repo)),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    expect(
      (await repo.list('course')).every((item) => item.reviewHistory.isEmpty),
      isTrue,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(find.text('答案 a'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await tester.pumpAndSettle();
    expect(find.text('问题 b'), findsOneWidget);
    expect(
      (await repo.list('course'))
          .firstWhere((item) => item.id == first.id)
          .reviewHistory
          .single['rating'],
      3,
    );
    await tester.tap(find.text('显示答案'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('简单'));
    await tester.pumpAndSettle();
    expect(find.text('本轮复习完成'), findsOneWidget);
    final readback = await LocalReviewCardRepository(
      await SharedPreferences.getInstance(),
    ).list('course');
    expect(readback.every((item) => item.reviewHistory.length == 1), isTrue);
    expect(readback.every((item) => item.due.isAfter(DateTime.now())), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('save failure retains revealed card and retry advances once', (
    tester,
  ) async {
    useViewport(tester);
    final repo = SessionRepository()..fail = true;
    await tester.pumpWidget(
      app(ReviewSessionPage(cards: [card('a')], repository: repo)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('显示答案'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('记得'));
    await tester.pumpAndSettle();
    expect(find.text('评分保存失败，请检查连接后重试'), findsOneWidget);
    expect(find.text('答案 a'), findsOneWidget);
    expect(find.text('本轮复习完成'), findsNothing);
    repo.fail = false;
    await tester.tap(find.text('记得'));
    await tester.pumpAndSettle();
    expect(repo.calls, 2);
    expect(find.text('本轮复习完成'), findsOneWidget);
  });

  testWidgets(
    'in-flight rating rejects repeated shortcuts and back navigation',
    (tester) async {
      useViewport(tester);
      final repo = SessionRepository()..pending = Completer<ReviewCard>();
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) =>
                        ReviewSessionPage(cards: [card('a')], repository: repo),
                  ),
                ),
                child: const Text('进入复习'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('进入复习'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('显示答案'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      await tester.pageBack();
      await tester.pump();
      expect(repo.calls, 1);
      expect(find.byType(ReviewSessionPage), findsOneWidget);
      repo.pending!.complete(card('a'));
      await tester.pumpAndSettle();
      expect(find.text('本轮复习完成'), findsOneWidget);
    },
  );

  testWidgets('short large-text viewport scrolls long questions and answers', (
    tester,
  ) async {
    useViewport(tester, const Size(360, 640));
    final long = ReviewCard(
      id: 'long',
      courseId: 'course',
      front: List.filled(16, '长问题与概念').join(' '),
      back: List.filled(40, '完整解释与例子').join(' '),
      due: DateTime(2020),
    );
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.6),
              disableAnimations: true,
            ),
            child: ReviewSessionPage(
              cards: [long],
              repository: SessionRepository(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('显示答案'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('困难'));
    await tester.pumpAndSettle();
    expect(find.text('本轮复习完成'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
