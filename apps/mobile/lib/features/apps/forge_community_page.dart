import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import '../shared/widgets/workspace_layout.dart';
import 'forge_repository.dart';

const _channels = [
  (kind: null, label: '全部', icon: Icons.forum_outlined),
  (kind: 'question', label: '技术问答', icon: Icons.help_outline),
  (kind: 'idea', label: '经验与建议', icon: Icons.lightbulb_outline),
  (kind: 'update', label: '项目动态', icon: Icons.campaign_outlined),
  (kind: 'bug', label: '问题反馈', icon: Icons.bug_report_outlined),
];

/// A campus-wide feed of conversations attached to approved public projects.
class ForgeCommunityPage extends StatefulWidget {
  const ForgeCommunityPage({
    super.key,
    required this.repository,
    required this.onOpenThread,
    required this.onOpenProject,
    required this.onCompose,
    this.onOpenAccount,
  });

  final ForgeRepository repository;
  final Future<void> Function(RecordModel thread, RecordModel project)
  onOpenThread;
  final Future<void> Function(RecordModel project) onOpenProject;
  final Future<bool> Function(RecordModel project, String kind) onCompose;
  final VoidCallback? onOpenAccount;

  @override
  State<ForgeCommunityPage> createState() => _ForgeCommunityPageState();
}

class _ForgeCommunityPageState extends State<ForgeCommunityPage> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  late Future<ResultList<RecordModel>> _future;
  String _query = '', _sort = 'created';
  String? _kind;
  bool _starred = false, _opening = false;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ForgeCommunityPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _page = 1;
      _load();
    }
  }

  void _load() {
    _future = _starred && widget.repository.userId.isEmpty
        ? Future.value(ResultList(page: 1, perPage: 20))
        : widget.repository.communityThreads(
            page: _page,
            query: _query,
            kind: _kind,
            starred: _starred,
            sort: _sort,
          );
  }

  void _filter({
    String? kind,
    bool changeKind = false,
    bool? starred,
    String? sort,
  }) {
    _debounce?.cancel();
    setState(() {
      _query = _search.text.trim();
      if (changeKind) _kind = kind;
      _starred = starred ?? _starred;
      _sort = sort ?? _sort;
      _page = 1;
      _load();
    });
  }

  Future<void> _refresh({bool firstPage = false}) async {
    if (!mounted) return;
    _debounce?.cancel();
    final query = _search.text.trim();
    setState(() {
      if (firstPage || query != _query) _page = 1;
      _query = query;
      _load();
    });
    try {
      await _future;
    } catch (_) {
      // The feed's error state exposes the failed request and its retry action.
    }
  }

  void _account() {
    if (widget.onOpenAccount != null) {
      widget.onOpenAccount!();
    } else {
      _message('登录并验证邮箱后，就能发起交流、关注收藏的项目');
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _open(Future<void> Function() action) async {
    if (_opening) return;
    _opening = true;
    try {
      await action();
      if (mounted) await _refresh(firstPage: true);
    } catch (_) {
      if (mounted) _message('打开遇到问题，请稍后重试');
    } finally {
      _opening = false;
    }
  }

  Future<void> _compose() async {
    if (!widget.repository.canWrite) {
      _account();
      return;
    }
    if (_opening) return;
    _opening = true;
    try {
      final project = await showDialog<RecordModel>(
        context: context,
        builder: (_) => _ProjectPicker(repository: widget.repository),
      );
      if (project == null || !mounted) return;
      final saved = await widget.onCompose(project, _kind ?? 'question');
      if (saved && mounted) await _refresh(firstPage: true);
    } catch (_) {
      if (mounted) _message('发起交流遇到问题，请稍后重试');
    } finally {
      _opening = false;
    }
  }

  void _goToPage(int page) {
    _debounce?.cancel();
    final query = _search.text.trim();
    setState(() {
      _page = query == _query ? page : 1;
      _query = query;
      _load();
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('社区交流')),
    body: WorkspaceCanvas(
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: ListView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                WorkspaceBanner(
                  eyebrow: 'CAMPUS COMMUNITY',
                  title: '从项目聊起',
                  subtitle: '提问、分享经验，让校园项目一起成长。',
                  icon: Icons.forum_outlined,
                  actions: [
                    FilledButton.icon(
                      onPressed: _compose,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('发起交流'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final channel in _channels)
                      ChoiceChip(
                        label: Text(channel.label),
                        avatar: Icon(channel.icon, size: 18),
                        showCheckmark: false,
                        selected: _kind == channel.kind,
                        onSelected: (_) =>
                            _filter(kind: channel.kind, changeKind: true),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: '搜索交流',
                    hintText: '标题、正文、项目或话题',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      tooltip: '清空搜索',
                      onPressed: () {
                        _search.clear();
                        _filter();
                      },
                      icon: const Icon(Icons.close),
                    ),
                  ),
                  onSubmitted: (_) => _filter(),
                  onChanged: (_) {
                    _debounce?.cancel();
                    _debounce = Timer(
                      const Duration(milliseconds: 300),
                      () => _filter(),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilterChip(
                      label: const Text('收藏的项目'),
                      avatar: const Icon(Icons.star_border, size: 18),
                      showCheckmark: false,
                      selected: _starred,
                      onSelected: (value) => _filter(starred: value),
                    ),
                    PopupMenuButton<String>(
                      tooltip: '交流排序',
                      initialValue: _sort,
                      onSelected: (value) => _filter(sort: value),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'created', child: Text('最新发布')),
                        PopupMenuItem(value: 'updated', child: Text('最近更新')),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.sort, size: 18),
                            const SizedBox(width: 6),
                            Text(_sort == 'created' ? '最新发布' : '最近更新'),
                            const Icon(Icons.expand_more, size: 18),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '刷新交流',
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_starred && widget.repository.userId.isEmpty)
                  _FeedState(
                    icon: Icons.star_outline,
                    title: '登录查看收藏项目的交流',
                    message: '收藏感兴趣的项目，集中看看大家的提问与分享。',
                    action: TextButton.icon(
                      onPressed: _account,
                      icon: const Icon(Icons.login),
                      label: const Text('登录账号'),
                    ),
                  )
                else
                  FutureBuilder<ResultList<RecordModel>>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Padding(
                          padding: EdgeInsets.all(48),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snapshot.hasError) {
                        return _FeedState(
                          icon: Icons.cloud_off_outlined,
                          title: '交流加载遇到问题',
                          message: '检查网络连接后，再试一次。',
                          action: TextButton.icon(
                            onPressed: _refresh,
                            icon: const Icon(Icons.refresh),
                            label: const Text('重新加载'),
                          ),
                        );
                      }
                      final data = snapshot.data!;
                      if (data.items.isEmpty) {
                        return _FeedState(
                          icon: Icons.chat_bubble_outline,
                          title: _query.isNotEmpty || _kind != null || _starred
                              ? '换个条件，发现更多交流'
                              : '从一个校园项目聊起',
                          message:
                              _query.isNotEmpty || _kind != null || _starred
                              ? '换个关键词或频道，看看其他项目的讨论。'
                              : '选择一个已审核项目，分享经验或提出你的第一个问题。',
                          action: TextButton.icon(
                            onPressed: _compose,
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('发起交流'),
                          ),
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              '${data.totalItems} 条交流 · 来自已审核的校园项目',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          for (final thread in data.items)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _ThreadCard(
                                thread: thread,
                                onOpenThread: (project) => _open(
                                  () => widget.onOpenThread(thread, project),
                                ),
                                onOpenProject: (project) =>
                                    _open(() => widget.onOpenProject(project)),
                              ),
                            ),
                          _FeedPager(
                            page: _page,
                            total: data.totalPages,
                            onPage: _goToPage,
                          ),
                        ],
                      );
                    },
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _ThreadCard extends StatelessWidget {
  const _ThreadCard({
    required this.thread,
    required this.onOpenThread,
    required this.onOpenProject,
  });

  final RecordModel thread;
  final ValueChanged<RecordModel> onOpenThread, onOpenProject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final project = thread.get<RecordModel?>('expand.repository');
    final kind = thread.getStringValue('kind');
    final channel = _channels.where((item) => item.kind == kind).firstOrNull;
    final projectName = project?.getStringValue('name') ?? '';
    final isAuthor =
        project != null &&
        project.getStringValue('owner').isNotEmpty &&
        project.getStringValue('owner') == thread.getStringValue('owner');
    final date = DateTime.tryParse(thread.getStringValue('created'))?.toLocal();
    final excerpt = thread
        .getStringValue('body')
        .replaceAllMapped(RegExp(r'!?\[([^\]]*)\]\([^)]*\)'), (m) => m[1]!)
        .replaceAll(RegExp(r'[`#>*_~]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer.withValues(alpha: .65),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    channel?.label ?? '交流',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.onSecondaryContainer,
                    ),
                  ),
                ),
                Text(
                  isAuthor ? '项目作者' : '社区成员',
                  style: theme.textTheme.bodySmall,
                ),
                if (date != null)
                  Text(
                    '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}',
                    style: theme.textTheme.bodySmall,
                  ),
                if (thread.getStringValue('status') == 'closed')
                  Text('已结束', style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: project == null ? null : () => onOpenThread(project),
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      thread.getStringValue('title'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (excerpt.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        excerpt,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.55,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: project == null ? null : () => onOpenProject(project),
              icon: const Icon(Icons.source_outlined, size: 17),
              label: Text(
                projectName.isEmpty ? '项目信息待更新' : projectName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedState extends StatelessWidget {
  const _FeedState({
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
  });

  final IconData icon;
  final String title, message;
  final Widget action;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 32),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          action,
        ],
      ),
    ),
  );
}

class _FeedPager extends StatelessWidget {
  const _FeedPager({
    required this.page,
    required this.total,
    required this.onPage,
  });

  final int page, total;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) => total <= 1
      ? const SizedBox.shrink()
      : Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IconButton(
              tooltip: '上一页',
              onPressed: page > 1 ? () => onPage(page - 1) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text('$page / $total'),
            IconButton(
              tooltip: '下一页',
              onPressed: page < total ? () => onPage(page + 1) : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        );
}

class _ProjectPicker extends StatefulWidget {
  const _ProjectPicker({required this.repository});

  final ForgeRepository repository;

  @override
  State<_ProjectPicker> createState() => _ProjectPickerState();
}

class _ProjectPickerState extends State<_ProjectPicker> {
  final _search = TextEditingController();
  Timer? _debounce;
  late Future<ResultList<RecordModel>> _future;
  String _query = '';
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = widget.repository.projects(page: _page, query: _query);
  }

  void _searchProjects() {
    _debounce?.cancel();
    setState(() {
      _query = _search.text.trim();
      _page = 1;
      _load();
    });
  }

  void _goToPage(int page) {
    _debounce?.cancel();
    final query = _search.text.trim();
    setState(() {
      _page = query == _query ? page : 1;
      _query = query;
      _load();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(16),
    child: SizedBox(
      width: 640,
      height: MediaQuery.sizeOf(context).height * .8,
      child: FutureBuilder<ResultList<RecordModel>>(
        future: _future,
        builder: (context, snapshot) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '选择交流的项目',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: '关闭项目选择',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('交流会展示在项目中，也会出现在社区信息流。'),
            const SizedBox(height: 16),
            TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                labelText: '搜索项目',
                hintText: '项目名称或话题',
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: (_) => _searchProjects(),
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(
                  const Duration(milliseconds: 300),
                  _searchProjects,
                );
              },
            ),
            const SizedBox(height: 16),
            if (snapshot.connectionState != ConnectionState.done)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (snapshot.hasError)
              TextButton.icon(
                onPressed: () => _goToPage(_page),
                icon: const Icon(Icons.refresh),
                label: const Text('项目加载失败，点击重试'),
              )
            else if (snapshot.data!.items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('试试其他关键词，查找已审核的项目。'),
              )
            else ...[
              for (final project in snapshot.data!.items)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(project),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            project.getStringValue('name'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (project.getStringValue('summary').isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              project.getStringValue('summary'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              _FeedPager(
                page: _page,
                total: snapshot.data!.totalPages,
                onPage: _goToPage,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
