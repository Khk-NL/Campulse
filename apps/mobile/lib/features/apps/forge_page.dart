import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:campus_mobile/core/pocketbase_session.dart';

import 'forge_repository.dart';
import '../shared/widgets/workspace_layout.dart';
import '../../core/launcher/external_opener.dart';

class ForgePage extends StatefulWidget {
  const ForgePage({
    super.key,
    this.repository,
    this.embedded = false,
    this.initialMine = false,
    this.refreshToken = 0,
    this.showViewSwitcher = true,
    this.searchFocusNode,
    this.onOpenAccount,
    this.onOpenRepositories,
    this.active = true,
    this.resetSearchToken = 0,
  });
  final ForgeRepository? repository;
  final bool embedded;
  final bool initialMine;
  final int refreshToken;
  final bool showViewSwitcher;
  final FocusNode? searchFocusNode;
  final VoidCallback? onOpenAccount;
  final VoidCallback? onOpenRepositories;
  final bool active;
  final int resetSearchToken;
  @override
  State<ForgePage> createState() => _ForgePageState();
}

class _ForgePageState extends State<ForgePage> {
  ForgeRepository? get repo {
    if (widget.repository != null) return widget.repository;
    final session = PocketBaseSession.instance;
    return session == null ? null : ForgeRepository(session.client);
  }

  late bool mine = widget.initialMine;
  String query = '';
  int page = 1;
  Future<ResultList<RecordModel>>? result;
  final searchController = TextEditingController();
  Timer? searchDebounce;
  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    result = mine && (repo?.userId.isEmpty ?? true)
        ? null
        : repo?.projects(page: page, query: query, mine: mine);
  }

  @override
  void didUpdateWidget(ForgePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.resetSearchToken != oldWidget.resetSearchToken) {
      searchDebounce?.cancel();
      searchController.clear();
      query = '';
      page = 1;
    }
    if (widget.refreshToken != oldWidget.refreshToken ||
        widget.resetSearchToken != oldWidget.resetSearchToken ||
        (widget.active && !oldWidget.active)) {
      setState(load);
    }
  }

  void search(String value) {
    searchDebounce?.cancel();
    final next = value.trim();
    if (next == query) return;
    setState(() {
      query = next;
      page = 1;
      load();
    });
  }

  @override
  void dispose() {
    searchDebounce?.cancel();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _createProject() async {
    final repository = repo;
    if (repository == null || !repository.canWrite) {
      widget.onOpenAccount?.call();
      return;
    }
    final saved = await showProjectEditor(context, repository);
    if (saved && mounted) {
      if (!mine && widget.onOpenRepositories != null) {
        widget.onOpenRepositories!();
        return;
      }
      setState(() {
        page = 1;
        load();
      });
    }
  }

  Widget _guestRepositories() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const WorkspaceBanner(
        vivid: true,
        eyebrow: 'YOUR REPOSITORIES',
        title: '让项目有一个校园主页',
        subtitle: '绑定 GitHub，整理 README，提交自己的校园作品。',
        icon: Icons.source_outlined,
      ),
      const SizedBox(height: 24),
      Center(
        child: FilledButton.icon(
          onPressed: widget.onOpenAccount,
          icon: const Icon(Icons.login),
          label: const Text('登录管理仓库'),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: widget.embedded ? null : AppBar(title: const Text('校园社区')),
    body: mine && (repo?.userId.isEmpty ?? true)
        ? _guestRepositories()
        : repo == null
        ? const Center(child: Text('连接校园服务后参与项目交流'))
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (widget.showViewSwitcher)
                          Expanded(
                            child: SegmentedButton<bool>(
                              showSelectedIcon: false,
                              segments: const [
                                ButtonSegment(
                                  value: false,
                                  label: Text('发现项目'),
                                  icon: Icon(Icons.explore_outlined),
                                ),
                                ButtonSegment(
                                  value: true,
                                  label: Text('我的仓库'),
                                  icon: Icon(Icons.folder_open),
                                ),
                              ],
                              selected: {mine},
                              onSelectionChanged: (value) => setState(() {
                                searchDebounce?.cancel();
                                query = searchController.text.trim();
                                mine = value.first;
                                page = 1;
                                load();
                              }),
                            ),
                          ),
                        if (widget.showViewSwitcher)
                          const SizedBox(width: 12)
                        else
                          const Spacer(),
                        FilledButton.icon(
                          onPressed:
                              repo!.canWrite || widget.onOpenAccount != null
                              ? _createProject
                              : null,
                          icon: const Icon(Icons.add),
                          label: Text(mine ? '创建项目' : '发布项目'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: searchController,
                      focusNode: widget.searchFocusNode,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: '搜索项目、介绍或技术话题',
                        labelText: mine ? '搜索我的仓库' : '搜索项目',
                        suffixIcon: IconButton(
                          tooltip: '清空搜索',
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            searchController.clear();
                            search('');
                          },
                        ),
                      ),
                      onChanged: (value) {
                        searchDebounce?.cancel();
                        searchDebounce = Timer(
                          const Duration(milliseconds: 300),
                          () => search(value),
                        );
                      },
                      onSubmitted: search,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<ResultList<RecordModel>>(
                  future: result,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _Retry(onRetry: () => setState(load));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final rows = snapshot.data!;
                    return RefreshIndicator(
                      onRefresh: () async {
                        setState(load);
                        await result;
                      },
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          WorkspaceBanner(
                            vivid: true,
                            eyebrow: 'CAMPUS CODE COMMUNITY',
                            title: mine ? '从想法到作品' : '一起构建校园',
                            subtitle: mine
                                ? '管理自己的项目，提交审核，记录迭代。'
                                : '找到同学的代码与工具，围绕项目交流，一起解决校园里的问题。',
                            icon: mine
                                ? Icons.inventory_2_outlined
                                : Icons.forum_outlined,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '${rows.totalItems} 个项目',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 8),
                          if (rows.items.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 36),
                              child: Column(
                                children: [
                                  Icon(
                                    query.isEmpty
                                        ? Icons.terminal
                                        : Icons.search,
                                    size: 44,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .tertiary,
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    query.isNotEmpty
                                        ? '换个项目名或技术话题试试'
                                        : mine
                                        ? '把你的第一个项目放到这里'
                                        : '从一个校园需求开始',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    query.isNotEmpty
                                        ? '搜索项目名称、介绍和技术话题。'
                                        : mine
                                        ? '添加源码链接和介绍，准备好后提交审核。'
                                        : '上架后的作品会出现在这里，也欢迎分享你正在做的工具。',
                                    textAlign: TextAlign.center,
                                  ),
                                  if (query.isEmpty &&
                                      (repo!.canWrite ||
                                          widget.onOpenAccount != null)) ...[
                                    const SizedBox(height: 16),
                                    OutlinedButton.icon(
                                      onPressed: _createProject,
                                      icon: const Icon(Icons.add),
                                      label: Text(mine ? '创建项目' : '分享我的项目'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          for (final item in rows.items) _repositoryCard(item),
                          _Pager(
                            page: page,
                            total: rows.totalPages,
                            onPage: (value) => setState(() {
                              page = value;
                              load();
                            }),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
  );

  Widget _repositoryCard(RecordModel item) {
    final theme = Theme.of(context);
    final topics = item
        .getStringValue('topics')
        .split(RegExp(r'[,，\s]+'))
        .where((value) => value.isNotEmpty)
        .take(6)
        .toList();
    final github = Uri.tryParse(item.getStringValue('repositoryUrl'));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            await Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => ForgeProjectPage(repo: repo!, id: item.id),
              ),
            );
            if (mounted) setState(load);
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.book_outlined,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.getStringValue('name'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    Icon(
                      item.getStringValue('visibility') == 'private'
                          ? Icons.lock_outline
                          : Icons.public,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                if (item.getStringValue('summary').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    item.getStringValue('summary'),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (topics.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final topic in topics)
                        ActionChip(
                          label: Text(topic),
                          onPressed: () {
                            searchController.text = topic;
                            search(topic);
                          },
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      _reviewLabel(item),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.tertiary,
                      ),
                    ),
                    if (github != null &&
                        github.scheme == 'https' &&
                        github.host == 'github.com')
                      TextButton.icon(
                        onPressed: () async {
                          final opened = await openUrlExternally(github);
                          if (!opened && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('请检查浏览器后重试打开链接')),
                            );
                          }
                        },
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('GitHub 源码'),
                      ),
                    Text(
                      '查看项目与讨论',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ForgeProjectPage extends StatefulWidget {
  const ForgeProjectPage({super.key, required this.repo, required this.id});
  final ForgeRepository repo;
  final String id;
  @override
  State<ForgeProjectPage> createState() => _ForgeProjectPageState();
}

class _ForgeProjectPageState extends State<ForgeProjectPage> {
  late Future<RecordModel> project;
  late Future<ResultList<RecordModel>> discussions;
  late Future<ResultList<RecordModel>> stars;
  RecordModel? star;
  bool starReady = false;
  bool starring = false;
  bool submitting = false;
  int page = 1;
  String? discussionStatus;
  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    starReady = false;
    project = widget.repo.project(widget.id);
    discussions = fetchDiscussions();
    stars = widget.repo.stars(widget.id);
    widget.repo
        .myStar(widget.id)
        .then((value) {
          if (mounted) {
            setState(() {
              star = value;
              starReady = true;
            });
          }
        })
        .catchError((Object error) {
          if (mounted) _message(context, '关注状态加载失败，请刷新重试');
        });
  }

  Future<ResultList<RecordModel>> fetchDiscussions() =>
      widget.repo.discussions(widget.id, page: page, status: discussionStatus);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('项目仓库')),
    body: FutureBuilder<RecordModel>(
      future: project,
      builder: (context, snapshot) {
        if (snapshot.hasError) return _Retry(onRetry: () => setState(load));
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final item = snapshot.data!;
        final owned = item.getStringValue('owner') == widget.repo.userId;
        return DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.getStringValue('name'),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(item.getStringValue('summary')),
                    if (owned) ...[
                      Text(_reviewLabel(item)),
                      if (item.getStringValue('reviewNote').isNotEmpty)
                        Text(item.getStringValue('reviewNote')),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (owned &&
                            item.getStringValue('reviewState') != 'approved')
                          FilledButton.icon(
                            onPressed:
                                submitting ||
                                    item.getStringValue('reviewState') ==
                                        'pending'
                                ? null
                                : () async {
                                    setState(() => submitting = true);
                                    try {
                                      await widget.repo.submitProject(
                                        widget.id,
                                      );
                                      if (mounted) {
                                        setState(load);
                                      }
                                      if (context.mounted) {
                                        _message(context, '项目已提交审核');
                                      }
                                    } catch (error) {
                                      if (context.mounted) {
                                        _message(
                                          context,
                                          error is StateError
                                              ? error.message.toString()
                                              : '提交失败，请重试',
                                        );
                                      }
                                    } finally {
                                      if (mounted) {
                                        setState(() => submitting = false);
                                      }
                                    }
                                  },
                            icon: const Icon(Icons.fact_check_outlined),
                            label: Text(
                              item.getStringValue('reviewState') == 'pending'
                                  ? '审核中'
                                  : '提交审核',
                            ),
                          ),
                        if (item.getStringValue('repositoryUrl').isNotEmpty)
                          OutlinedButton.icon(
                            onPressed: () async {
                              final uri = Uri.tryParse(
                                item.getStringValue('repositoryUrl'),
                              );
                              final ok =
                                  uri != null &&
                                  uri.scheme == 'https' &&
                                  uri.host == 'github.com' &&
                                  await openUrlExternally(uri);
                              if (!ok && context.mounted) {
                                _message(context, '链接打开失败，请重试');
                              }
                            },
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('GitHub 仓库'),
                          ),
                        FutureBuilder<ResultList<RecordModel>>(
                          future: stars,
                          builder: (context, count) => OutlinedButton.icon(
                            onPressed:
                                widget.repo.canWrite && !starring && starReady
                                ? () async {
                                    setState(() => starring = true);
                                    try {
                                      await widget.repo.toggleStar(widget.id);
                                      if (mounted) setState(load);
                                    } catch (error) {
                                      if (context.mounted) {
                                        _message(context, '关注操作失败，请重试');
                                      }
                                    } finally {
                                      if (mounted) {
                                        setState(() => starring = false);
                                      }
                                    }
                                  }
                                : null,
                            icon: Icon(
                              star == null ? Icons.star_outline : Icons.star,
                            ),
                            label: Text('关注 ${count.data?.totalItems ?? '…'}'),
                          ),
                        ),
                        if (!starReady && widget.repo.canWrite)
                          TextButton.icon(
                            onPressed: () => setState(load),
                            icon: const Icon(Icons.refresh),
                            label: const Text('刷新关注状态'),
                          ),
                        if (owned)
                          OutlinedButton.icon(
                            onPressed: () async {
                              final saved = await showProjectEditor(
                                context,
                                widget.repo,
                                initial: item,
                              );
                              if (saved && mounted) setState(load);
                            },
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('编辑项目'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const TabBar(
                tabs: [
                  Tab(text: 'README'),
                  Tab(text: '讨论与问题'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: SelectionArea(
                        child: Text(
                          item.getStringValue('readme').isEmpty
                              ? '写下项目目标、使用方法和参与方式。'
                              : item.getStringValue('readme'),
                        ),
                      ),
                    ),
                    FutureBuilder<ResultList<RecordModel>>(
                      future: discussions,
                      builder: (context, threads) {
                        if (threads.hasError) {
                          return _Retry(onRetry: () => setState(load));
                        }
                        if (!threads.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        return ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            Wrap(
                              spacing: 8,
                              children: [
                                for (final status in <String?>[
                                  null,
                                  'open',
                                  'closed',
                                ])
                                  ChoiceChip(
                                    showCheckmark: false,
                                    label: Text(switch (status) {
                                      'open' => '讨论中',
                                      'closed' => '已解决',
                                      _ => '全部讨论',
                                    }),
                                    selected: discussionStatus == status,
                                    onSelected: (_) => setState(() {
                                      discussionStatus = status;
                                      page = 1;
                                      discussions = fetchDiscussions();
                                    }),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: widget.repo.canWrite
                                  ? () async {
                                      final created = await _newDiscussion(
                                        context,
                                        widget.repo,
                                        widget.id,
                                      );
                                      if (created && mounted) {
                                        setState(() {
                                          page = 1;
                                          load();
                                        });
                                      }
                                    }
                                  : null,
                              icon: const Icon(Icons.add_comment_outlined),
                              label: const Text('发起讨论'),
                            ),
                            const SizedBox(height: 12),
                            if (threads.data!.items.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(24),
                                child: Text('分享建议，提出问题，让项目继续前进。'),
                              ),
                            for (final thread in threads.data!.items)
                              Card(
                                child: ListTile(
                                  leading: Icon(
                                    thread.getStringValue('status') == 'closed'
                                        ? Icons.task_alt
                                        : Icons.chat_bubble_outline,
                                  ),
                                  title: Text(thread.getStringValue('title')),
                                  subtitle: Text(
                                    '${_kind(thread.getStringValue('kind'))} · ${thread.getStringValue('status') == 'closed' ? '已解决' : '讨论中'}',
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => Navigator.of(context)
                                      .push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => ForgeDiscussionPage(
                                            repo: widget.repo,
                                            thread: thread,
                                            repositoryOwner: item
                                                .getStringValue('owner'),
                                          ),
                                        ),
                                      )
                                      .then((_) {
                                        if (mounted) setState(load);
                                      }),
                                ),
                              ),
                            _Pager(
                              page: page,
                              total: threads.data!.totalPages,
                              onPage: (value) => setState(() {
                                page = value;
                                discussions = fetchDiscussions();
                              }),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class ForgeDiscussionPage extends StatefulWidget {
  const ForgeDiscussionPage({
    super.key,
    required this.repo,
    required this.thread,
    required this.repositoryOwner,
  });
  final ForgeRepository repo;
  final RecordModel thread;
  final String repositoryOwner;
  @override
  State<ForgeDiscussionPage> createState() => _ForgeDiscussionPageState();
}

class _ForgeDiscussionPageState extends State<ForgeDiscussionPage> {
  final input = TextEditingController();
  late Future<ResultList<RecordModel>> replies;
  late String status;
  int statusRevision = 0;
  bool busy = false;
  int page = 1;
  @override
  void initState() {
    super.initState();
    status = widget.thread.getStringValue('status');
    load();
  }

  void load() {
    replies = widget.repo.replies(widget.thread.id, page: page);
    final revision = ++statusRevision;
    widget.repo
        .discussion(widget.thread.id)
        .then((row) {
          if (mounted && revision == statusRevision) {
            setState(() => status = row.getStringValue('status'));
          }
        })
        .catchError((Object error) {
          if (mounted && revision == statusRevision) {
            _message(context, '讨论状态加载失败，请刷新重试');
          }
        });
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final manage =
        widget.repo.userId == widget.thread.getStringValue('owner') ||
        widget.repo.userId == widget.repositoryOwner;
    return Scaffold(
      appBar: AppBar(title: const Text('项目讨论')),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<ResultList<RecordModel>>(
              future: replies,
              builder: (context, snapshot) => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    widget.thread.getStringValue('title'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  SelectableText(widget.thread.getStringValue('body')),
                  const Divider(height: 32),
                  if (snapshot.hasError)
                    _Retry(onRetry: () => setState(load))
                  else if (!snapshot.hasData)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    for (final reply in snapshot.data!.items)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reply.getStringValue('owner') ==
                                        widget.repo.userId
                                    ? '你'
                                    : reply.getStringValue('owner') ==
                                          widget.repositoryOwner
                                    ? '项目维护者'
                                    : '社区成员',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                              const SizedBox(height: 8),
                              SelectableText(reply.getStringValue('body')),
                            ],
                          ),
                        ),
                      ),
                    _Pager(
                      page: page,
                      total: snapshot.data!.totalPages,
                      onPage: (value) => setState(() {
                        page = value;
                        load();
                      }),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (manage)
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      setState(() => busy = true);
                      final next = status == 'open' ? 'closed' : 'open';
                      try {
                        await widget.repo.setStatus(widget.thread.id, next);
                        if (mounted) {
                          statusRevision++;
                          setState(() => status = next);
                        }
                      } catch (error) {
                        if (context.mounted) {
                          _message(context, '状态保存失败，请重试');
                        }
                      } finally {
                        if (mounted) setState(() => busy = false);
                      }
                    },
              child: Text(status == 'open' ? '标记为已解决' : '重新开启讨论'),
            ),
          if (widget.repo.canWrite && status == 'open')
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: input,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 20000,
                        decoration: const InputDecoration(
                          hintText: '参与讨论，写下你的想法',
                          counterText: '',
                        ),
                      ),
                    ),
                    IconButton.filled(
                      tooltip: '发送回复',
                      onPressed: busy
                          ? null
                          : () async {
                              if (input.text.trim().isEmpty) return;
                              setState(() => busy = true);
                              try {
                                await widget.repo.reply(
                                  widget.thread.id,
                                  input.text,
                                );
                                if (!mounted) return;
                                input.clear();
                                final latest = await widget.repo.replies(
                                  widget.thread.id,
                                );
                                if (!mounted) return;
                                final lastPage = latest.totalPages < 1
                                    ? 1
                                    : latest.totalPages;
                                setState(() {
                                  page = lastPage;
                                  replies = lastPage == 1
                                      ? Future.value(latest)
                                      : widget.repo.replies(
                                          widget.thread.id,
                                          page: lastPage,
                                        );
                                });
                              } catch (error) {
                                if (context.mounted) {
                                  _message(context, '回复发送失败，请重试');
                                }
                              } finally {
                                if (mounted) setState(() => busy = false);
                              }
                            },
                      icon: const Icon(Icons.send_outlined),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Future<bool> showProjectEditor(
  BuildContext context,
  ForgeRepository repo, {
  RecordModel? initial,
}) async {
  final controllers = [
    for (final field in [
      'name',
      'summary',
      'readme',
      'topics',
      'schoolProof',
      'repositoryUrl',
    ])
      TextEditingController(text: initial?.getStringValue(field) ?? ''),
  ];
  bool public = initial?.getStringValue('visibility') != 'private';
  bool saving = false;
  String? error;
  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _ControllerOwner(
      controllers: controllers,
      child: StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(initial == null ? '创建项目仓库' : '编辑项目仓库'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < controllers.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextField(
                        controller: controllers[i],
                        enabled: !saving,
                        maxLength: [100, 500, 100000, 300, 2000, 500][i],
                        minLines: i == 2 ? 4 : 1,
                        maxLines: i == 2 ? 8 : 2,
                        decoration: InputDecoration(
                          labelText: [
                            '项目名称',
                            '简介',
                            'README：目标、用法与参与方式',
                            '话题：用空格分隔',
                            '华师大归属材料：团队、用途与核验方式',
                            'GitHub 仓库链接（选填）',
                          ][i],
                        ),
                      ),
                    ),
                  SwitchListTile(
                    title: const Text('校园作品公开范围'),
                    subtitle: const Text('保存为草稿后，在项目详情独立提交审核'),
                    value: public,
                    onChanged: saving
                        ? null
                        : (value) => setState(() => public = value),
                  ),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving
                  ? null
                  : () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (controllers[0].text.trim().isEmpty) {
                        setState(() => error = '请填写项目名称');
                        return;
                      }
                      final link = controllers[5].text.trim();
                      if (link.isNotEmpty &&
                          !RegExp(
                            r'^https://github[.]com/[A-Za-z0-9_-]+/[A-Za-z0-9_.-]+/?$',
                          ).hasMatch(link)) {
                        setState(
                          () => error = '请填写 https://github.com/所有者/仓库 格式的链接',
                        );
                        return;
                      }
                      setState(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        await repo.saveProject(
                          id: initial?.id,
                          name: controllers[0].text,
                          summary: controllers[1].text,
                          readme: controllers[2].text,
                          topics: controllers[3].text,
                          isPublic: public,
                          schoolProof: controllers[4].text,
                          repositoryUrl: controllers[5].text,
                        );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (exception) {
                        if (dialogContext.mounted) {
                          setState(() {
                            saving = false;
                            error = '保存失败，请检查连接后重试';
                          });
                        }
                      }
                    },
              child: Text(saving ? '保存中' : '保存'),
            ),
          ],
        ),
      ),
    ),
  );
  return saved ?? false;
}

Future<bool> _newDiscussion(
  BuildContext context,
  ForgeRepository repo,
  String repository,
) async {
  final title = TextEditingController();
  final body = TextEditingController();
  String kind = 'question';
  bool busy = false;
  String? error;
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _ControllerOwner(
      controllers: [title, body],
      child: StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('发起讨论'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: kind,
                    items: [
                      for (final value in ['question', 'idea', 'bug', 'update'])
                        DropdownMenuItem(
                          value: value,
                          child: Text(_kind(value)),
                        ),
                    ],
                    onChanged: busy
                        ? null
                        : (value) => setState(() => kind = value!),
                    decoration: const InputDecoration(labelText: '分类'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: title,
                    maxLength: 200,
                    enabled: !busy,
                    decoration: const InputDecoration(labelText: '标题'),
                  ),
                  TextField(
                    controller: body,
                    maxLength: 20000,
                    minLines: 4,
                    maxLines: 8,
                    enabled: !busy,
                    decoration: const InputDecoration(labelText: '内容'),
                  ),
                  if (error != null) Text(error!),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy
                  ? null
                  : () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (title.text.trim().isEmpty ||
                          body.text.trim().isEmpty) {
                        setState(() => error = '请填写标题和内容');
                        return;
                      }
                      setState(() => busy = true);
                      try {
                        await repo.discuss(
                          repository,
                          title.text,
                          body.text,
                          kind,
                        );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (exception) {
                        if (dialogContext.mounted) {
                          setState(() {
                            busy = false;
                            error = '发布失败，请检查连接后重试';
                          });
                        }
                      }
                    },
              child: Text(busy ? '发布中' : '发布'),
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}

String _reviewLabel(RecordModel row) {
  if (row.getStringValue('visibility') == 'private') return '个人草稿';
  return switch (row.getStringValue('reviewState')) {
    'approved' => '已审核',
    'rejected' => '待修改',
    'draft' => '待提交',
    _ => '待审核',
  };
}

String _kind(String value) => switch (value) {
  'idea' => '想法与建议',
  'bug' => '问题反馈',
  'update' => '项目进展',
  _ => '问答交流',
};
void _message(BuildContext context, String value) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));

class _ControllerOwner extends StatefulWidget {
  const _ControllerOwner({required this.controllers, required this.child});
  final List<TextEditingController> controllers;
  final Widget child;
  @override
  State<_ControllerOwner> createState() => _ControllerOwnerState();
}

class _ControllerOwnerState extends State<_ControllerOwner> {
  @override
  void dispose() {
    for (final controller in widget.controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _Retry extends StatelessWidget {
  const _Retry({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: TextButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh),
      label: const Text('加载失败，点击重试'),
    ),
  );
}

class _Pager extends StatelessWidget {
  const _Pager({required this.page, required this.total, required this.onPage});
  final int page, total;
  final ValueChanged<int> onPage;
  @override
  Widget build(BuildContext context) => total <= 1
      ? const SizedBox.shrink()
      : Row(
          mainAxisAlignment: MainAxisAlignment.center,
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
