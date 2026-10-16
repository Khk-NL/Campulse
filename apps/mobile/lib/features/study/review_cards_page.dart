import 'package:campus_mobile/features/study/review_card_repository.dart';
import 'package:campus_mobile/features/study/review_session_page.dart';
import 'package:campus_mobile/features/shared/widgets/workspace_layout.dart';
import 'package:flutter/material.dart';

class ReviewCardsPage extends StatefulWidget {
  const ReviewCardsPage({
    super.key,
    required this.courseId,
    required this.repository,
    this.initialFront = '',
    this.initialBack = '',
    this.noteId = '',
  });

  final String courseId;
  final ReviewCardRepository repository;
  final String initialFront;
  final String initialBack;
  final String noteId;

  @override
  State<ReviewCardsPage> createState() => _ReviewCardsPageState();
}

class _ReviewCardsPageState extends State<ReviewCardsPage> {
  bool _dueOnly = false;
  late Future<List<ReviewCard>> _cards = widget.repository.list(
    widget.courseId,
  );

  @override
  void initState() {
    super.initState();
    if (widget.noteId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _edit();
      });
    }
  }

  void _reload() => setState(() {
    _cards = widget.repository.list(widget.courseId);
  });

  Future<void> _startSession(List<ReviewCard> cards) async {
    final queue = cards.where((card) => card.isDue(DateTime.now())).toList()
      ..sort((a, b) => a.due.compareTo(b.due));
    if (queue.isEmpty) return;
    await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) =>
            ReviewSessionPage(cards: queue, repository: widget.repository),
      ),
    );
    if (mounted) _reload();
  }

  Future<void> _edit([ReviewCard? card]) async {
    String front = card?.front ?? widget.initialFront;
    String back = card?.back ?? widget.initialBack;
    final bool? save = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(card == null ? '新建卡片' : '编辑卡片'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                initialValue: front,
                onChanged: (String value) => front = value,
                maxLines: 2,
                decoration: const InputDecoration(labelText: '正面 · 问题'),
              ),
              TextFormField(
                initialValue: back,
                onChanged: (String value) => back = value,
                maxLines: 5,
                decoration: const InputDecoration(labelText: '背面 · 答案'),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (save == true && front.trim().isNotEmpty && back.trim().isNotEmpty) {
      try {
        await widget.repository.save(
          ReviewCard(
            id: card?.id ?? '',
            courseId: widget.courseId,
            noteId: card?.noteId ?? widget.noteId,
            front: front.trim(),
            back: back.trim(),
            due: card?.due ?? DateTime.now(),
            scheduler: card?.scheduler ?? const <String, dynamic>{},
            reviewHistory:
                card?.reviewHistory ?? const <Map<String, dynamic>>[],
          ),
        );
        if (mounted) _reload();
      } on Exception catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('卡片保存失败：$error')));
        }
      }
    }
  }

  Future<void> _review(ReviewCard card) async {
    bool revealed = false;
    final int? rating = await showDialog<int>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) =>
            AlertDialog(
              title: const Text('复习卡片'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 280),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        card.front,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      AnimatedSize(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 240),
                        alignment: Alignment.topCenter,
                        child: AnimatedSwitcher(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 180),
                          child: revealed
                              ? Column(
                                  key: const ValueKey<String>('answer'),
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    const Divider(height: 28),
                                    SelectableText(card.back),
                                  ],
                                )
                              : const SizedBox.shrink(
                                  key: ValueKey<String>('hidden'),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: revealed
                  ? <Widget>[
                      for (final (int rating, String label) in <(int, String)>[
                        (1, '重来'),
                        (2, '困难'),
                        (3, '记得'),
                        (4, '简单'),
                      ])
                        TextButton(
                          onPressed: () => Navigator.pop(context, rating),
                          child: Text(label),
                        ),
                    ]
                  : <Widget>[
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('关闭'),
                      ),
                      FilledButton(
                        onPressed: () => setDialogState(() => revealed = true),
                        child: const Text('显示答案'),
                      ),
                    ],
            ),
      ),
    );
    if (rating == null) return;
    try {
      final ReviewCard reviewed = await widget.repository.review(card, rating);
      if (mounted) {
        _reload();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '复习已保存 · 下次 ${reviewed.due.toLocal().toString().substring(0, 16)}',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('复习保存失败：$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('复习卡片')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _edit(),
      icon: const Icon(Icons.add),
      label: const Text('新建卡片'),
    ),
    body: FutureBuilder<List<ReviewCard>>(
      future: _cards,
      builder: (BuildContext context, AsyncSnapshot<List<ReviewCard>> snapshot) {
        if (!snapshot.hasData && !snapshot.hasError) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: _reload,
              child: const Text('卡片加载失败，点击重试'),
            ),
          );
        }
        final List<ReviewCard> cards = snapshot.data!;
        final DateTime now = DateTime.now();
        final int due = cards
            .where((ReviewCard card) => card.isDue(now))
            .length;
        final visible =
            cards.where((card) => !_dueOnly || card.isDue(now)).toList()
              ..sort((a, b) => a.due.compareTo(b.due));
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
          children: <Widget>[
            WorkspaceBanner(
              eyebrow: 'SPACED REPETITION',
              title: '让知识留下来',
              subtitle: '回想答案，再为掌握程度评分。',
              icon: Icons.style_outlined,
              actions: [
                FilledButton.icon(
                  onPressed: due == 0 ? null : () => _startSession(cards),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('开始复习'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            WorkspaceGrid(
              minWidth: 170,
              children: [
                WorkspaceMetric(
                  value: '$due',
                  label: '到期卡片',
                  icon: Icons.bolt_rounded,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                WorkspaceMetric(
                  value: '${cards.length}',
                  label: '卡片总数',
                  icon: Icons.layers_outlined,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  '今天待复习 $due 张 · 共 ${cards.length} 张',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  showCheckmark: false,
                  label: const Text('全部卡片'),
                  selected: !_dueOnly,
                  onSelected: (_) => setState(() => _dueOnly = false),
                ),
                ChoiceChip(
                  showCheckmark: false,
                  label: const Text('到期复习'),
                  selected: _dueOnly,
                  onSelected: (_) => setState(() => _dueOnly = true),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (cards.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('从笔记制作卡片，或直接新建卡片。')),
              ),
            if (_dueOnly && visible.isEmpty && cards.isNotEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('本轮复习已完成，稍后继续积累。'),
              ),
            for (final ReviewCard card in visible)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: card.isDue(now)
                          ? Theme.of(context).colorScheme.tertiaryContainer
                          : Theme.of(context).colorScheme.secondaryContainer,
                      child: Icon(
                        card.isDue(now) ? Icons.bolt : Icons.schedule,
                      ),
                    ),
                    title: Text(
                      card.front,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${card.isDue(now) ? '现在复习' : '下次：${card.due.toLocal().toString().substring(0, 16)}'} · 已复习 ${card.reviewHistory.length} 次',
                    ),
                    onTap: () => _review(card),
                    trailing: PopupMenuButton<String>(
                      onSelected: (String action) async {
                        if (action == 'edit') {
                          await _edit(card);
                          return;
                        }
                        try {
                          await widget.repository.delete(card.id);
                          if (mounted) _reload();
                        } on Exception catch (error) {
                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(content: Text('删除失败：$error')),
                            );
                          }
                        }
                      },
                      itemBuilder: (BuildContext context) =>
                          const <PopupMenuEntry<String>>[
                            PopupMenuItem<String>(
                              value: 'edit',
                              child: Text('编辑'),
                            ),
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Text('删除'),
                            ),
                          ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}
