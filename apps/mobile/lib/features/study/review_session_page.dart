import 'package:campus_mobile/features/shared/widgets/workspace_layout.dart';
import 'package:campus_mobile/features/study/review_card_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A bounded session: each card is persisted before moving to the next one.
class ReviewSessionPage extends StatefulWidget {
  const ReviewSessionPage({
    super.key,
    required this.cards,
    required this.repository,
  });
  final List<ReviewCard> cards;
  final ReviewCardRepository repository;

  @override
  State<ReviewSessionPage> createState() => _ReviewSessionPageState();
}

class _ReviewSessionPageState extends State<ReviewSessionPage> {
  late final List<ReviewCard> _queue = List.of(widget.cards);
  final Map<int, int> _ratings = {};
  int _index = 0;
  bool _revealed = false, _busy = false;
  String? _error;
  bool get _finished => _index >= _queue.length;

  void _reveal() {
    if (_finished || _busy || _revealed) return;
    setState(() => _revealed = true);
  }

  Future<void> _rate(int rating) async {
    if (_busy || !_revealed || _finished) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.review(_queue[_index], rating);
      if (!mounted) return;
      setState(() {
        _ratings.update(rating, (value) => value + 1, ifAbsent: () => 1);
        _index++;
        _revealed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _error = '评分保存失败，请检查连接后重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return PopScope(
      canPop: !_busy,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(
            LogicalKeyboardKey.space,
            includeRepeats: false,
          ): _reveal,
          for (final (key, rating) in [
            (LogicalKeyboardKey.digit1, 1),
            (LogicalKeyboardKey.digit2, 2),
            (LogicalKeyboardKey.digit3, 3),
            (LogicalKeyboardKey.digit4, 4),
          ])
            SingleActivator(key, includeRepeats: false): () => _rate(rating),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            appBar: AppBar(title: const Text('专注复习')),
            body: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    WorkspaceBanner(
                      vivid: true,
                      eyebrow: 'FOCUS & RECALL',
                      title: _finished ? '本轮复习完成' : '让每一次回想更清晰',
                      subtitle: _finished
                          ? '已保存 $_index 张卡片的评分与复习排程。'
                          : '先回想，再揭晓答案，按真实掌握程度评分。',
                      icon: _finished
                          ? Icons.auto_awesome
                          : Icons.school_outlined,
                    ),
                    const SizedBox(height: 20),
                    Semantics(
                      label: '复习进度',
                      value: '$_index / ${_queue.length}',
                      child: LinearProgressIndicator(
                        value: _queue.isEmpty ? 1 : _index / _queue.length,
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _finished
                          ? '完成 $_index / ${_queue.length}'
                          : '第 ${_index + 1} 张 / 共 ${_queue.length} 张',
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 20),
                    if (_finished)
                      WorkspaceGrid(
                        minWidth: 160,
                        children: [
                          for (final (rating, label, icon) in [
                            (1, '重来', Icons.replay),
                            (2, '困难', Icons.fitness_center),
                            (3, '记得', Icons.lightbulb_outline),
                            (4, '简单', Icons.bolt),
                          ])
                            WorkspaceMetric(
                              value: '${_ratings[rating] ?? 0}',
                              label: label,
                              icon: icon,
                              color: rating < 3
                                  ? colors.secondary
                                  : colors.tertiary,
                            ),
                        ],
                      )
                    else
                      AnimatedSwitcher(
                        duration: reduced
                            ? Duration.zero
                            : const Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: Tween(
                              begin: .96,
                              end: 1.0,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: Container(
                          key: ValueKey('$_index:$_revealed'),
                          width: double.infinity,
                          constraints: const BoxConstraints(minHeight: 250),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: colors.primary.withValues(alpha: .2),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colors.primary.withValues(alpha: .07),
                                blurRadius: 28,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _revealed
                                        ? Icons.lightbulb_outline
                                        : Icons.psychology_outlined,
                                    color: colors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _revealed ? '回想与核对' : '先想一想',
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: colors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 22),
                              SelectableText(
                                _queue[_index].front,
                                style: theme.textTheme.headlineSmall,
                              ),
                              if (_revealed) ...[
                                const Divider(height: 36),
                                SelectableText(
                                  _queue[_index].back,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    height: 1.7,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            _error!,
                            style: TextStyle(color: colors.error),
                          ),
                        ),
                      ),
                    if (_busy)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: LinearProgressIndicator(),
                      ),
                  ],
                ),
              ),
            ),
            bottomNavigationBar: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_finished)
                      FilledButton.icon(
                        onPressed: () => Navigator.pop(context, _index),
                        icon: const Icon(Icons.done_all),
                        label: const Text('返回卡片库'),
                      )
                    else if (!_revealed)
                      FilledButton.icon(
                        onPressed: _reveal,
                        icon: const Icon(Icons.flip_to_front),
                        label: const Text('显示答案'),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final (rating, label) in [
                            (1, '重来'),
                            (2, '困难'),
                            (3, '记得'),
                            (4, '简单'),
                          ])
                            FilledButton.tonal(
                              onPressed: _busy ? null : () => _rate(rating),
                              style: FilledButton.styleFrom(
                                backgroundColor: rating < 3
                                    ? colors.secondaryContainer
                                    : colors.tertiaryContainer,
                                foregroundColor: rating < 3
                                    ? colors.onSecondaryContainer
                                    : colors.onTertiaryContainer,
                              ),
                              child: Text(label),
                            ),
                        ],
                      ),
                    if (!_finished) ...[
                      const SizedBox(height: 8),
                      Text(
                        '空格显示答案 · 数字 1–4 评分',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
