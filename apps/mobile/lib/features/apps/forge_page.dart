import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:campus_mobile/core/pocketbase_session.dart';

import 'forge_repository.dart';
import 'forge_markdown.dart';
import 'forge_library_page.dart';
import '../shared/widgets/workspace_layout.dart';
import '../../core/launcher/external_opener.dart';

Future<void> openForgeLibrary(
  BuildContext context, {
  ForgeRepository? repository,
  String? initialRepositoryId,
}) async {
  final session = PocketBaseSession.instance;
  final target =
      repository ?? (session == null ? null : ForgeRepository(session.client));
  if (target == null || !target.canWrite) {
    _message(context, '登录并验证邮箱后可管理收藏与订阅');
    return;
  }
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => ForgeLibraryPage(
        repository: target,
        initialRepositoryId: initialRepositoryId,
        onOpenProject: (id) async {
          await Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => ForgeProjectPage(repo: target, id: id),
            ),
          );
        },
      ),
    ),
  );
}

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
  String sort = 'updated';
  bool starred = false;
  String? topicSearch;
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
        : repo?.projects(
            page: page,
            query: query,
            mine: mine,
            sort: sort,
            starred: starred,
          );
  }

  @override
  void didUpdateWidget(ForgePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.resetSearchToken != oldWidget.resetSearchToken) {
      searchDebounce?.cancel();
      searchController.clear();
      query = '';
      topicSearch = null;
      starred = false;
      sort = 'updated';
      page = 1;
    }
    if (widget.refreshToken != oldWidget.refreshToken ||
        widget.resetSearchToken != oldWidget.resetSearchToken ||
        (widget.active && !oldWidget.active)) {
      setState(load);
    }
  }

  void search(String value, {bool fromTopic = false}) {
    searchDebounce?.cancel();
    final next = value.trim();
    final nextTopic = fromTopic ? next : null;
    if (next == query && nextTopic == topicSearch) return;
    setState(() {
      query = next;
      topicSearch = nextTopic;
      page = 1;
      load();
    });
  }

  void _filter({String? order, bool? onlyStarred}) {
    searchDebounce?.cancel();
    final nextQuery = searchController.text.trim();
    final nextTopic = topicSearch == nextQuery ? topicSearch : null;
    final nextSort = order ?? sort;
    final nextStarred = onlyStarred ?? starred;
    if (nextQuery == query &&
        nextTopic == topicSearch &&
        nextSort == sort &&
        nextStarred == starred) {
      return;
    }
    setState(() {
      query = nextQuery;
      topicSearch = nextTopic;
      sort = nextSort;
      starred = nextStarred;
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
      searchDebounce?.cancel();
      searchController.clear();
      setState(() {
        query = '';
        topicSearch = null;
        starred = false;
        sort = 'updated';
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
        : LayoutBuilder(
            builder: (context, viewport) => Column(
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: viewport.maxHeight * .6,
                  ),
                  child: SingleChildScrollView(
                    child: Padding(
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
                                      starred = false;
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
                                    repo!.canWrite ||
                                        widget.onOpenAccount != null
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
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () async {
                                  if (repo!.userId.isEmpty &&
                                      widget.onOpenAccount != null) {
                                    widget.onOpenAccount!();
                                    return;
                                  }
                                  await openForgeLibrary(
                                    context,
                                    repository: repo!,
                                  );
                                  if (mounted) {
                                    setState(() {
                                      page = 1;
                                      load();
                                    });
                                  }
                                },
                                icon: const Icon(
                                  Icons.bookmarks_outlined,
                                  size: 18,
                                ),
                                label: const Text('收藏与订阅'),
                              ),
                              if (!mine) ...[
                                ChoiceChip(
                                  showCheckmark: false,
                                  avatar: const Icon(
                                    Icons.explore_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('全部项目'),
                                  selected: !starred,
                                  onSelected: (_) =>
                                      _filter(onlyStarred: false),
                                ),
                                ChoiceChip(
                                  showCheckmark: false,
                                  avatar: const Icon(
                                    Icons.star_outline,
                                    size: 18,
                                  ),
                                  label: const Text('我的 Star'),
                                  selected: starred,
                                  onSelected: (_) => _filter(onlyStarred: true),
                                ),
                              ],
                              PopupMenuButton<String>(
                                tooltip: '项目排序',
                                initialValue: sort,
                                onSelected: (value) => _filter(order: value),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'updated',
                                    child: Text('最近更新'),
                                  ),
                                  PopupMenuItem(
                                    value: 'created',
                                    child: Text('最新发布'),
                                  ),
                                  PopupMenuItem(
                                    value: 'name',
                                    child: Text('名称排序'),
                                  ),
                                ],
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.sort, size: 18),
                                      const SizedBox(width: 6),
                                      Text(switch (sort) {
                                        'created' => '最新发布',
                                        'name' => '名称排序',
                                        _ => '最近更新',
                                      }),
                                      const Icon(Icons.expand_more, size: 18),
                                    ],
                                  ),
                                ),
                              ),
                              if (topicSearch != null)
                                InputChip(
                                  label: Text('话题搜索：$topicSearch'),
                                  onDeleted: () {
                                    searchController.clear();
                                    search('');
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 36,
                                ),
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
                                      starred && repo!.userId.isEmpty
                                          ? '登录查看收藏的项目'
                                          : query.isNotEmpty
                                          ? '换个项目名或技术话题试试'
                                          : starred
                                          ? '把感兴趣的项目留在这里'
                                          : mine
                                          ? '把你的第一个项目放到这里'
                                          : '从一个校园需求开始',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      starred && repo!.userId.isEmpty
                                          ? '使用 Campulse 账号，在手机和电脑间整理 Star 项目。'
                                          : query.isNotEmpty
                                          ? '搜索项目名称、介绍和技术话题。'
                                          : starred
                                          ? '在项目详情点亮 Star，之后从这里继续阅读和交流。'
                                          : mine
                                          ? '添加源码链接和介绍，准备好后提交审核。'
                                          : '上架后的作品会出现在这里，也欢迎分享你正在做的工具。',
                                      textAlign: TextAlign.center,
                                    ),
                                    if (starred &&
                                        repo!.userId.isEmpty &&
                                        widget.onOpenAccount != null) ...[
                                      const SizedBox(height: 16),
                                      FilledButton.icon(
                                        onPressed: widget.onOpenAccount,
                                        icon: const Icon(Icons.login),
                                        label: const Text('登录账号'),
                                      ),
                                    ] else if (!starred &&
                                        query.isEmpty &&
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
                            for (final item in rows.items)
                              _repositoryCard(item),
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
            if (mounted) {
              setState(() {
                page = 1;
                load();
              });
            }
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
                            search(topic, fromTopic: true);
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
                    if (_recordDate(context, item).isNotEmpty)
                      Text(
                        '更新于 ${_recordDate(context, item)}',
                        style: theme.textTheme.labelSmall,
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
  int starRevision = 0;
  int page = 1;
  String? discussionStatus;
  String? discussionKind;
  String discussionQuery = '';
  final discussionSearch = TextEditingController();
  Timer? discussionDebounce;
  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    project = widget.repo.project(widget.id);
    discussions = fetchDiscussions();
    _loadStars();
  }

  void _loadStars() {
    final revision = ++starRevision;
    starReady = false;
    stars = widget.repo.stars(widget.id);
    widget.repo
        .myStar(widget.id)
        .then((value) {
          if (mounted && revision == starRevision) {
            setState(() {
              star = value;
              starReady = true;
            });
          }
        })
        .catchError((Object error) {
          if (mounted && revision == starRevision) {
            _message(context, 'Star 状态加载失败，请刷新重试');
          }
        });
  }

  Future<ResultList<RecordModel>> fetchDiscussions() => widget.repo.discussions(
    widget.id,
    page: page,
    status: discussionStatus,
    kind: discussionKind,
    query: discussionQuery,
  );

  void _filterDiscussions({
    String? status,
    String? kind,
    bool changeStatus = false,
    bool changeKind = false,
  }) {
    discussionDebounce?.cancel();
    final nextQuery = discussionSearch.text.trim();
    final nextStatus = changeStatus ? status : discussionStatus;
    final nextKind = changeKind ? kind : discussionKind;
    if (nextQuery == discussionQuery &&
        nextStatus == discussionStatus &&
        nextKind == discussionKind) {
      return;
    }
    setState(() {
      discussionQuery = nextQuery;
      discussionStatus = nextStatus;
      discussionKind = nextKind;
      page = 1;
      discussions = fetchDiscussions();
    });
  }

  @override
  void dispose() {
    discussionDebounce?.cancel();
    discussionSearch.dispose();
    super.dispose();
  }

  Widget _discussionFilters() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Column(
      children: [
        TextField(
          controller: discussionSearch,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: '搜索讨论',
            hintText: '搜索标题与正文',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              tooltip: '清空讨论搜索',
              onPressed: () {
                discussionSearch.clear();
                _filterDiscussions();
              },
              icon: const Icon(Icons.clear),
            ),
          ),
          onChanged: (_) {
            discussionDebounce?.cancel();
            discussionDebounce = Timer(
              const Duration(milliseconds: 300),
              () => _filterDiscussions(),
            );
          },
          onSubmitted: (_) => _filterDiscussions(),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final status in <String?>[null, 'open', 'closed'])
              ChoiceChip(
                showCheckmark: false,
                label: Text(switch (status) {
                  'open' => '讨论中',
                  'closed' => '已解决',
                  _ => '全部讨论',
                }),
                selected: discussionStatus == status,
                onSelected: (_) =>
                    _filterDiscussions(status: status, changeStatus: true),
              ),
            SizedBox(
              width: 150,
              child: DropdownButtonFormField<String>(
                key: ValueKey(discussionKind),
                initialValue: discussionKind ?? '',
                decoration: const InputDecoration(
                  labelText: '讨论类型',
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(value: '', child: Text('全部类型')),
                  for (final kind in ['question', 'idea', 'bug', 'update'])
                    DropdownMenuItem(value: kind, child: Text(_kind(kind))),
                ],
                onChanged: (value) => _filterDiscussions(
                  kind: value == '' ? null : value,
                  changeKind: true,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: widget.repo.canWrite
                  ? () async {
                      final created = await _newDiscussion(
                        context,
                        widget.repo,
                        widget.id,
                      );
                      if (created && mounted) {
                        discussionSearch.clear();
                        discussionDebounce?.cancel();
                        setState(() {
                          page = 1;
                          discussionQuery = '';
                          discussionStatus = null;
                          discussionKind = null;
                          discussions = fetchDiscussions();
                        });
                      }
                    }
                  : null,
              icon: const Icon(Icons.add_comment_outlined),
              label: const Text('发起讨论'),
            ),
          ],
        ),
      ],
    ),
  );

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
          child: LayoutBuilder(
            builder: (context, viewport) => Column(
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: viewport.maxHeight * .42,
                  ),
                  child: SingleChildScrollView(
                    child: Padding(
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
                                  item.getStringValue('reviewState') !=
                                      'approved')
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
                                              setState(
                                                () => submitting = false,
                                              );
                                            }
                                          }
                                        },
                                  icon: const Icon(Icons.fact_check_outlined),
                                  label: Text(
                                    item.getStringValue('reviewState') ==
                                            'pending'
                                        ? '审核中'
                                        : '提交审核',
                                  ),
                                ),
                              if (item
                                  .getStringValue('repositoryUrl')
                                  .isNotEmpty)
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
                                builder: (context, count) =>
                                    OutlinedButton.icon(
                                      onPressed:
                                          widget.repo.canWrite &&
                                              !starring &&
                                              starReady
                                          ? () async {
                                              setState(() => starring = true);
                                              try {
                                                await widget.repo.toggleStar(
                                                  widget.id,
                                                );
                                                if (mounted) {
                                                  setState(_loadStars);
                                                }
                                              } catch (error) {
                                                if (context.mounted) {
                                                  _message(
                                                    context,
                                                    'Star 操作失败，请重试',
                                                  );
                                                }
                                              } finally {
                                                if (mounted) {
                                                  setState(
                                                    () => starring = false,
                                                  );
                                                }
                                              }
                                            }
                                          : null,
                                      icon: Icon(
                                        star == null
                                            ? Icons.star_outline
                                            : Icons.star,
                                      ),
                                      label: Text(
                                        'Star ${count.data?.totalItems ?? '…'}',
                                      ),
                                    ),
                              ),
                              if (!starReady && widget.repo.canWrite)
                                TextButton.icon(
                                  onPressed: () => setState(_loadStars),
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('刷新 Star 状态'),
                                ),
                              OutlinedButton.icon(
                                onPressed:
                                    widget.repo.canWrite &&
                                        starReady &&
                                        !starring
                                    ? () async {
                                        setState(() => starring = true);
                                        try {
                                          if (star == null) {
                                            await widget.repo.toggleStar(
                                              widget.id,
                                            );
                                          }
                                          if (context.mounted) {
                                            await openForgeLibrary(
                                              context,
                                              repository: widget.repo,
                                              initialRepositoryId: widget.id,
                                            );
                                          }
                                        } catch (_) {
                                          if (context.mounted) {
                                            _message(
                                              context,
                                              '收藏读取失败，请检查连接后重试',
                                            );
                                          }
                                        } finally {
                                          if (mounted) {
                                            setState(() {
                                              starring = false;
                                              _loadStars();
                                            });
                                          }
                                        }
                                      }
                                    : null,
                                icon: const Icon(Icons.auto_awesome_outlined),
                                label: Text(
                                  star == null ? 'Star 并整理' : '整理与 AI 分析',
                                ),
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
                        child: ForgeMarkdown(
                          data: item.getStringValue('readme').isEmpty
                              ? '写下项目目标、使用方法和参与方式。'
                              : item.getStringValue('readme'),
                        ),
                      ),
                      LayoutBuilder(
                        builder: (context, area) => Column(
                          children: [
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: area.maxHeight * .6,
                              ),
                              child: SingleChildScrollView(
                                child: _discussionFilters(),
                              ),
                            ),
                            Expanded(
                              child: FutureBuilder<ResultList<RecordModel>>(
                                future: discussions,
                                builder: (context, threads) {
                                  if (threads.hasError) {
                                    return _Retry(
                                      onRetry: () => setState(load),
                                    );
                                  }
                                  if (!threads.hasData) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }
                                  return ListView(
                                    padding: const EdgeInsets.all(16),
                                    children: [
                                      if (threads.data!.items.isEmpty)
                                        Padding(
                                          padding: const EdgeInsets.all(24),
                                          child: Text(
                                            discussionQuery.isNotEmpty ||
                                                    discussionStatus != null ||
                                                    discussionKind != null
                                                ? '调整关键词或筛选条件，继续查找讨论。'
                                                : '分享建议，提出问题，让项目继续前进。',
                                          ),
                                        ),
                                      for (final thread in threads.data!.items)
                                        Card(
                                          child: ListTile(
                                            leading: Icon(
                                              thread.getStringValue('status') ==
                                                      'closed'
                                                  ? Icons.task_alt
                                                  : Icons.chat_bubble_outline,
                                            ),
                                            title: Text(
                                              thread.getStringValue('title'),
                                            ),
                                            subtitle: Text(
                                              [
                                                _kind(
                                                  thread.getStringValue('kind'),
                                                ),
                                                thread.getStringValue(
                                                          'status',
                                                        ) ==
                                                        'closed'
                                                    ? '已解决'
                                                    : '讨论中',
                                                _authorLabel(
                                                  thread.getStringValue(
                                                    'owner',
                                                  ),
                                                  widget.repo.userId,
                                                  item.getStringValue('owner'),
                                                ),
                                                if (_recordDate(
                                                  context,
                                                  thread,
                                                  created: true,
                                                ).isNotEmpty)
                                                  _recordDate(
                                                    context,
                                                    thread,
                                                    created: true,
                                                  ),
                                              ].join(' · '),
                                            ),
                                            trailing: const Icon(
                                              Icons.chevron_right,
                                            ),
                                            onTap: () => Navigator.of(context)
                                                .push(
                                                  MaterialPageRoute<void>(
                                                    builder: (_) =>
                                                        ForgeDiscussionPage(
                                                          repo: widget.repo,
                                                          thread: thread,
                                                          repositoryOwner: item
                                                              .getStringValue(
                                                                'owner',
                                                              ),
                                                        ),
                                                  ),
                                                )
                                                .then((_) {
                                                  if (mounted) {
                                                    setState(() {
                                                      page = 1;
                                                      discussions =
                                                          fetchDiscussions();
                                                    });
                                                  }
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
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
                  Text(
                    [
                      _kind(widget.thread.getStringValue('kind')),
                      _authorLabel(
                        widget.thread.getStringValue('owner'),
                        widget.repo.userId,
                        widget.repositoryOwner,
                      ),
                      if (_recordDate(
                        context,
                        widget.thread,
                        created: true,
                      ).isNotEmpty)
                        _recordDate(context, widget.thread, created: true),
                    ].join(' · '),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 12),
                  ForgeMarkdown(data: widget.thread.getStringValue('body')),
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
                                [
                                  _authorLabel(
                                    reply.getStringValue('owner'),
                                    widget.repo.userId,
                                    widget.repositoryOwner,
                                  ),
                                  if (_recordDate(
                                    context,
                                    reply,
                                    created: true,
                                  ).isNotEmpty)
                                    _recordDate(context, reply, created: true),
                                ].join(' · '),
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                              const SizedBox(height: 8),
                              ForgeMarkdown(data: reply.getStringValue('body')),
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
                      child: i == 2
                          ? _MarkdownComposer(
                              controller: controllers[i],
                              enabled: !saving,
                              label: 'README：目标、用法与参与方式',
                              maxLength: 100000,
                            )
                          : TextField(
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
                  _MarkdownComposer(
                    controller: body,
                    maxLength: 20000,
                    enabled: !busy,
                    label: '内容',
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

class _MarkdownComposer extends StatefulWidget {
  const _MarkdownComposer({
    required this.controller,
    required this.label,
    required this.maxLength,
    this.enabled = true,
  });
  final TextEditingController controller;
  final String label;
  final int maxLength;
  final bool enabled;

  @override
  State<_MarkdownComposer> createState() => _MarkdownComposerState();
}

class _MarkdownComposerState extends State<_MarkdownComposer> {
  bool preview = false;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Align(
        alignment: Alignment.centerRight,
        child: SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: false,
              label: Text('编辑'),
              icon: Icon(Icons.edit_outlined),
            ),
            ButtonSegment(
              value: true,
              label: Text('预览'),
              icon: Icon(Icons.visibility_outlined),
            ),
          ],
          selected: {preview},
          onSelectionChanged: widget.enabled
              ? (values) => setState(() => preview = values.first)
              : null,
        ),
      ),
      const SizedBox(height: 10),
      if (preview)
        Container(
          constraints: const BoxConstraints(minHeight: 140, maxHeight: 300),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: SingleChildScrollView(
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: widget.controller,
              builder: (context, value, _) => ForgeMarkdown(
                data: value.text.trim().isEmpty ? '写下内容后，在这里查看排版。' : value.text,
              ),
            ),
          ),
        )
      else
        TextField(
          controller: widget.controller,
          enabled: widget.enabled,
          maxLength: widget.maxLength,
          minLines: 4,
          maxLines: 8,
          decoration: InputDecoration(
            labelText: widget.label,
            helperText: '支持 Markdown、代码块与网页链接',
          ),
        ),
    ],
  );
}

String _recordDate(
  BuildContext context,
  RecordModel row, {
  bool created = false,
}) {
  final date = DateTime.tryParse(
    row.getStringValue(created ? 'created' : 'updated'),
  )?.toLocal();
  return date == null
      ? ''
      : MaterialLocalizations.of(context).formatCompactDate(date);
}

String _authorLabel(String owner, String userId, String repositoryOwner) =>
    owner.isNotEmpty && owner == userId
    ? '你'
    : owner.isNotEmpty && owner == repositoryOwner
    ? '项目维护者'
    : '社区成员';

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
  'idea' => '功能建议',
  'bug' => '缺陷反馈',
  'update' => '进展分享',
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
