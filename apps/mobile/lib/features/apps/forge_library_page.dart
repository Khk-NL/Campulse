import 'package:campus_mobile/core/config/app_config.dart';
import 'package:campus_mobile/core/launcher/external_opener.dart';
import 'package:campus_mobile/features/shared/widgets/workspace_layout.dart';
import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import 'forge_integrations.dart';
import 'forge_library_repository.dart';
import 'forge_markdown.dart';
import 'forge_repository.dart';

const _categoryColors = ['#A41F35', '#B77912', '#7057C7', '#3F6BA8', '#C65770'];

Color _categoryColor(String text) => Color(
  int.tryParse('FF${text.replaceFirst('#', '')}', radix: 16) ?? 0xFFA41F35,
);

String _date(String value) {
  final date = DateTime.tryParse(value)?.toLocal();
  return date == null
      ? ''
      : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

String _libraryError(Object error, String fallback) {
  if (error is ForgeGatewayException) return error.message;
  if (error is StateError) return error.message;
  if (error is ArgumentError && error.message != null) {
    return '${error.message}';
  }
  return fallback;
}

/// Personal organization stays separate from a project's public star count.
class ForgeLibraryPage extends StatefulWidget {
  const ForgeLibraryPage({
    super.key,
    required this.repository,
    this.gateway,
    this.settingsStore,
    this.libraryRepository,
    this.onOpenProject,
    this.initialRepositoryId,
  });

  final ForgeRepository repository;
  final ForgeGateway? gateway;
  final ForgeIntegrationStore? settingsStore;
  final ForgeLibraryRepository? libraryRepository;
  final Future<void> Function(String)? onOpenProject;
  final String? initialRepositoryId;

  @override
  State<ForgeLibraryPage> createState() => _ForgeLibraryPageState();
}

class _ForgeLibraryPageState extends State<ForgeLibraryPage> {
  late final _library =
      widget.libraryRepository ?? ForgeLibraryRepository(widget.repository);
  late final _store = widget.settingsStore ?? ForgeIntegrationStore();
  ForgeGateway get _gateway =>
      widget.gateway ??
      ForgeGateway(
        baseUrl: AppConfig.configuredEduWorkGatewayUrl,
        token: widget.repository.client.authStore.token,
      );
  late Future<ForgeLibrarySnapshot> _future;
  ForgeLibrarySnapshot _data = const ForgeLibrarySnapshot();
  String? _category;
  String _query = '', _sort = 'starred';
  final _selected = <String>{};
  final _search = TextEditingController();
  int _tab = 0, _githubPage = 1;
  bool _categoriesExpanded = false, _busy = false, _unreadOnly = false;
  bool _desktopCategoriesCollapsed = false;
  String? _error, _refreshResult;
  List<Map<String, dynamic>> _releaseErrors = const [];
  Future<Map<String, dynamic>>? _githubFuture;
  final _imported = <String>{};
  bool _initialEntryOpened = false;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.canWrite
        ? _fetch()
        : Future.value(const ForgeLibrarySnapshot());
  }

  Future<ForgeLibrarySnapshot> _fetch() async {
    final data = await _library.load();
    _data = data;
    _selected.retainAll(data.entries.map((entry) => entry.id));
    if (_category != null &&
        _category!.isNotEmpty &&
        !data.categories.any((row) => row.id == _category)) {
      _category = null;
    }
    if (!_initialEntryOpened && widget.initialRepositoryId != null) {
      _initialEntryOpened = true;
      for (final entry in data.entries) {
        if (entry.id != widget.initialRepositoryId) continue;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _openEntry(entry);
        });
        break;
      }
    }
    return data;
  }

  Future<void> _reload() async {
    final next = _fetch();
    if (mounted) setState(() => _future = next);
    await next;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      await _reload();
    } catch (error) {
      if (mounted) {
        setState(() => _error = _libraryError(error, '操作保存失败，请检查连接后重试'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _configure() async {
    final saved = await showForgeIntegrationSettings(
      context,
      store: _store,
      gateway: _gateway,
    );
    if (saved && mounted && _tab == 2) {
      setState(() => _githubFuture = _githubStars());
    }
  }

  Future<Map<String, dynamic>> _githubStars() async {
    final settings = await _store.load();
    if (settings.githubToken.trim().isEmpty) return {'configured': false};
    return {
      'configured': true,
      ...await _gateway.githubStars(settings, page: _githubPage),
    };
  }

  Future<void> _refreshReleases() => _run(() async {
    final settings = await _store.load();
    int page = 1, checked = 0, created = 0;
    final errors = <dynamic>[];
    do {
      final result = await _gateway.refreshReleases(settings, page: page);
      checked += (result['checked'] as num?)?.toInt() ?? 0;
      created += (result['created'] as num?)?.toInt() ?? 0;
      if (result['errors'] is List) errors.addAll(result['errors'] as List);
      final next = int.tryParse('${result['nextPage'] ?? ''}');
      if (next == null || next <= page) break;
      page = next;
    } while (mounted);
    if (mounted) {
      setState(() {
        _refreshResult =
            '已检查 $checked 项订阅，新增 $created 个版本'
            '${errors.isEmpty ? '' : '；${errors.length} 项待重试'}';
        _releaseErrors = errors.whereType<Map>().map(libraryMap).toList();
      });
    }
  });

  Future<void> _editCategory([RecordModel? category]) async {
    final name = TextEditingController(
      text: category?.getStringValue('name') ?? '',
    );
    String color = category?.getStringValue('color') ?? _categoryColors.first;
    bool locked = category?.getBoolValue('locked') ?? false;
    bool saving = false;
    String? error;
    final route = DialogRoute<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(category == null ? '新建收藏分类' : '编辑收藏分类'),
          scrollable: true,
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  maxLength: 60,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: '分类名称'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final value in _categoryColors)
                      ChoiceChip(
                        showCheckmark: false,
                        selected: color == value,
                        avatar: CircleAvatar(
                          backgroundColor: _categoryColor(value),
                          radius: 7,
                        ),
                        label: Text(value),
                        onSelected: saving
                            ? null
                            : (_) => update(() => color = value),
                      ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('保留此分类'),
                  subtitle: const Text('应用 AI 建议时保留当前分类'),
                  value: locked,
                  onChanged: saving
                      ? null
                      : (value) => update(() => locked = value),
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
                      if (name.text.trim().isEmpty) {
                        update(() => error = '请填写分类名称');
                        return;
                      }
                      update(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        await _library.saveCategory(
                          category: category,
                          name: name.text,
                          color: color,
                          locked: locked,
                          position: _data.categories.length,
                        );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (_) {
                        if (dialogContext.mounted) {
                          update(() {
                            saving = false;
                            error = '分类保存失败，请重试';
                          });
                        }
                      }
                    },
              child: Text(saving ? '保存中…' : '保存'),
            ),
          ],
        ),
      ),
    );
    final saved = await Navigator.of(context).push(route);
    await route.completed;
    name.dispose();
    if (saved == true && mounted) await _run(() async {});
  }

  Future<void> _deleteCategory(RecordModel category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除收藏分类'),
        content: Text('删除“${category.getStringValue('name')}”，其中的收藏移入待分类。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除分类'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await _run(() => _library.deleteCategory(category));
    }
  }

  Future<void> _moveSelected() async {
    final target = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('移动 ${_selected.length} 个收藏'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('待分类'),
          ),
          for (final row in _data.categories)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, row.id),
              child: Text(row.getStringValue('name')),
            ),
        ],
      ),
    );
    if (target != null && mounted) {
      await _run(() async {
        await _library.moveToCategory(_selected.toList(), target);
        _selected.clear();
      });
    }
  }

  Future<void> _openEntry(ForgeLibraryEntry entry) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 1020),
      builder: (_) => FractionallySizedBox(
        heightFactor: .94,
        child: _ProjectPanel(
          entry: entry,
          snapshot: _data,
          repository: _library,
          gateway: _gateway,
          settingsStore: _store,
          onOpenProject: widget.onOpenProject,
        ),
      ),
    );
    if (mounted) await _run(() async {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('我的收藏'),
      actions: [
        IconButton(
          tooltip: '集成设置',
          onPressed: _configure,
          icon: const Icon(Icons.tune),
        ),
        IconButton(
          tooltip: '刷新收藏',
          onPressed: _busy ? null : () => _run(() async {}),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: !widget.repository.canWrite
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('登录并验证邮箱，整理自己的项目收藏'),
            ),
          )
        : WorkspaceCanvas(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            for (final (index, label, icon) in [
                              (0, '收藏库', Icons.bookmarks_outlined),
                              (1, '版本订阅', Icons.update_outlined),
                              (2, 'GitHub Star', Icons.code_outlined),
                            ])
                              ChoiceChip(
                                showCheckmark: false,
                                selected: _tab == index,
                                avatar: Icon(icon, size: 17),
                                label: Text(label),
                                onSelected: (_) => setState(() {
                                  _tab = index;
                                  if (index == 2) {
                                    _githubFuture ??= _githubStars();
                                  }
                                }),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_busy) const LinearProgressIndicator(minHeight: 2),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '收起提示',
                          onPressed: () => setState(() => _error = null),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: _tab == 2
                      ? _githubView()
                      : FutureBuilder<ForgeLibrarySnapshot>(
                          future: _future,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState !=
                                ConnectionState.done) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (snapshot.hasError) {
                              return _retry(() => _run(() async {}));
                            }
                            return _tab == 0
                                ? _collectionView(snapshot.data!)
                                : _releaseView(snapshot.data!);
                          },
                        ),
                ),
              ],
            ),
          ),
  );

  Widget _retry(VoidCallback onRetry) => Center(
    child: TextButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh),
      label: const Text('加载失败，点击重试'),
    ),
  );

  Widget _categoryList(ForgeLibrarySnapshot data) => ListView(
    padding: const EdgeInsets.all(8),
    children: [
      ListTile(
        title: const Text('收藏分类'),
        trailing: IconButton(
          tooltip: '新建分类',
          onPressed: _busy ? null : _editCategory,
          icon: const Icon(Icons.create_new_folder_outlined),
        ),
      ),
      ListTile(
        selected: _category == null,
        leading: const Icon(Icons.all_inbox_outlined),
        title: const Text('全部收藏'),
        trailing: Text('${data.entries.length}'),
        onTap: () => setState(() {
          _category = null;
          _selected.clear();
        }),
      ),
      ListTile(
        selected: _category == '',
        leading: const Icon(Icons.inbox_outlined),
        title: const Text('待分类'),
        trailing: Text('${data.categoryCounts[''] ?? 0}'),
        onTap: () => setState(() {
          _category = '';
          _selected.clear();
        }),
      ),
      for (final row in data.categories)
        ListTile(
          selected: _category == row.id,
          leading: Icon(
            row.getBoolValue('locked')
                ? Icons.lock_outline
                : Icons.folder_outlined,
            color: _categoryColor(row.getStringValue('color')),
          ),
          title: Text(row.getStringValue('name')),
          subtitle: Text('${data.categoryCounts[row.id] ?? 0} 个收藏'),
          onTap: () => setState(() {
            _category = row.id;
            _selected.clear();
          }),
          trailing: PopupMenuButton<String>(
            tooltip: '分类操作',
            onSelected: (action) {
              if (action == 'edit') _editCategory(row);
              if (action == 'delete') _deleteCategory(row);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('编辑名称、颜色与锁定')),
              PopupMenuItem(value: 'delete', child: Text('删除分类')),
            ],
          ),
        ),
    ],
  );

  Widget _collectionView(ForgeLibrarySnapshot data) => LayoutBuilder(
    builder: (context, bounds) {
      final wide = bounds.maxWidth >= 880;
      final visible = data.filtered(
        category: _category,
        query: _query,
        sort: _sort,
      );
      final content = Column(
        children: [
          if (!wide)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () => setState(
                      () => _categoriesExpanded = !_categoriesExpanded,
                    ),
                    icon: Icon(
                      _categoriesExpanded
                          ? Icons.expand_less
                          : Icons.folder_outlined,
                    ),
                    label: Text('分类 · ${data.categories.length}'),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: '新建分类',
                    onPressed: _busy ? null : _editCategory,
                    icon: const Icon(Icons.create_new_folder_outlined),
                  ),
                ],
              ),
            ),
          if (!wide && _categoriesExpanded)
            SizedBox(
              height: bounds.maxHeight * .35,
              child: _categoryList(data),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Column(
              children: [
                TextField(
                  controller: _search,
                  onChanged: (value) => setState(() {
                    _query = value;
                    _selected.clear();
                  }),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: '搜索收藏、个人标签或备注',
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('${visible.length} / ${data.entries.length} 个收藏'),
                    PopupMenuButton<String>(
                      tooltip: '收藏排序',
                      initialValue: _sort,
                      onSelected: (value) => setState(() => _sort = value),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'starred', child: Text('最近收藏')),
                        PopupMenuItem(value: 'name', child: Text('名称排序')),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(_sort == 'name' ? '名称排序 ▾' : '最近收藏 ▾'),
                      ),
                    ),
                    TextButton(
                      onPressed: visible.isEmpty
                          ? null
                          : () => setState(() {
                              final ids = visible
                                  .map((entry) => entry.id)
                                  .toSet();
                              if (_selected.containsAll(ids)) {
                                _selected.removeAll(ids);
                              } else {
                                _selected.addAll(ids);
                              }
                            }),
                      child: Text(
                        _selected.isEmpty
                            ? '选择当前结果'
                            : '已选 ${_selected.length} 项',
                      ),
                    ),
                    if (_selected.isNotEmpty)
                      FilledButton.tonalIcon(
                        onPressed: _busy ? null : _moveSelected,
                        icon: const Icon(Icons.drive_file_move_outlined),
                        label: const Text('移动分类'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('在探索中 Star 项目，再来整理标签、备注与分类。'),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    itemCount: visible.length,
                    itemBuilder: (context, index) => _entryCard(visible[index]),
                  ),
          ),
        ],
      );
      return wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: _desktopCategoriesCollapsed ? 60 : 246,
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          tooltip: _desktopCategoriesCollapsed
                              ? '展开分类'
                              : '收起分类',
                          onPressed: () => setState(
                            () => _desktopCategoriesCollapsed =
                                !_desktopCategoriesCollapsed,
                          ),
                          icon: Icon(
                            _desktopCategoriesCollapsed
                                ? Icons.chevron_right
                                : Icons.chevron_left,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _desktopCategoriesCollapsed
                            ? Column(
                                children: [
                                  IconButton(
                                    tooltip: '全部收藏',
                                    onPressed: () =>
                                        setState(() => _category = null),
                                    icon: const Icon(Icons.all_inbox_outlined),
                                  ),
                                  IconButton(
                                    tooltip: '新建分类',
                                    onPressed: _busy ? null : _editCategory,
                                    icon: const Icon(
                                      Icons.create_new_folder_outlined,
                                    ),
                                  ),
                                ],
                              )
                            : _categoryList(data),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: content),
              ],
            )
          : content;
    },
  );

  Widget _entryCard(ForgeLibraryEntry entry) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      key: ValueKey('library-project-${entry.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openEntry(entry),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _selected.contains(entry.id),
                onChanged: _busy
                    ? null
                    : (checked) => setState(() {
                        if (checked == true) {
                          _selected.add(entry.id);
                        } else {
                          _selected.remove(entry.id);
                        }
                      }),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(color: colors.primary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      entry.project.getStringValue('summary'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (entry.tags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            for (final tag in entry.tags)
                              ActionChip(
                                label: Text(tag),
                                visualDensity: VisualDensity.compact,
                                onPressed: () => setState(() {
                                  _query = tag;
                                  _search.text = tag;
                                  _selected.clear();
                                }),
                              ),
                          ],
                        ),
                      ),
                    if (entry.note.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          entry.note,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      '收藏于 ${_date(entry.star.getStringValue('created'))}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _releaseView(ForgeLibrarySnapshot data) {
    final entries = {for (final entry in data.entries) entry.id: entry};
    final events = data.releases
        .where((row) => !_unreadOnly || !row.getBoolValue('read'))
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.tonalIcon(
              onPressed: _busy ? null : _refreshReleases,
              icon: const Icon(Icons.sync),
              label: const Text('刷新版本'),
            ),
            FilterChip(
              showCheckmark: false,
              selected: _unreadOnly,
              label: Text(
                '待读 ${data.releases.where((r) => !r.getBoolValue('read')).length}',
              ),
              onSelected: (value) => setState(() => _unreadOnly = value),
            ),
          ],
        ),
        if (_refreshResult != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(_refreshResult!),
          ),
        if (_releaseErrors.isNotEmpty)
          ExpansionTile(
            title: Text('待处理订阅 · ${_releaseErrors.length}'),
            children: [
              for (final error in _releaseErrors)
                ListTile(
                  title: Text(
                    entries['${error['repositoryId']}']?.name ??
                        '${error['repositoryId'] ?? '订阅'}',
                  ),
                  subtitle: Text('${error['error'] ?? '请稍后重试'}'),
                ),
            ],
          ),
        ExpansionTile(
          title: Text('管理订阅 · ${data.subscriptions.length}'),
          children: [
            for (final subscription in data.subscriptions)
              ListTile(
                title: Text(
                  entries[subscription.getStringValue('repository')]?.name ??
                      '项目订阅',
                ),
                subtitle: Text(
                  subscription.getBoolValue('includePrereleases')
                      ? '含预发布版本'
                      : '正式版本',
                ),
                trailing: IconButton(
                  tooltip: '取消订阅',
                  onPressed: _busy
                      ? null
                      : () => _run(() => _library.unsubscribe(subscription)),
                  icon: const Icon(Icons.notifications_off_outlined),
                ),
                onTap:
                    entries[subscription.getStringValue('repository')] == null
                    ? null
                    : () => _openEntry(
                        entries[subscription.getStringValue('repository')]!,
                      ),
              ),
          ],
        ),
        if (events.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('从收藏项目详情开启版本订阅，刷新后在这里查看发布记录。'),
          ),
        for (final event in events)
          _releaseCard(event, entries[event.getStringValue('repository')]),
      ],
    );
  }

  Widget _releaseCard(RecordModel event, ForgeLibraryEntry? entry) {
    final payload = libraryMap(event.data['payload']);
    final read = event.getBoolValue('read');
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  read
                      ? Icons.check_circle_outline
                      : Icons.new_releases_outlined,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${entry?.name ?? '项目'} · ${payload['name'] ?? payload['tag'] ?? '新版本'}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: read ? '标为待读' : '标为已读',
                  onPressed: _busy
                      ? null
                      : () => _run(() => _library.markRead(event, !read)),
                  icon: Icon(
                    read
                        ? Icons.mark_email_unread_outlined
                        : Icons.mark_email_read_outlined,
                  ),
                ),
              ],
            ),
            Text(_date(event.getStringValue('publishedAt'))),
            if (payload['prerelease'] == true) const Chip(label: Text('预发布')),
            if ('${payload['body'] ?? ''}'.trim().isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('发布说明'),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: ForgeMarkdown(data: '${payload['body']}'),
                  ),
                ],
              ),
            if ('${payload['url'] ?? ''}'.isNotEmpty)
              TextButton.icon(
                onPressed: () => _openUrl('${payload['url']}'),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('前往 GitHub Release'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !['https', 'http'].contains(uri.scheme)) return;
    final opened = await openUrlExternally(uri);
    if (!opened && mounted) setState(() => _error = '请检查浏览器后重试打开链接');
  }

  Widget _githubView() => FutureBuilder<Map<String, dynamic>>(
    future: _githubFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return _retry(() => setState(() => _githubFuture = _githubStars()));
      }
      final data = snapshot.data ?? {};
      if (data['configured'] != true) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('连接 GitHub，查看自己 Star 的仓库并存入个人项目。'),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _configure,
                  icon: const Icon(Icons.key_outlined),
                  label: const Text('配置 GitHub Token'),
                ),
              ],
            ),
          ),
        );
      }
      final items = data['items'] is List
          ? (data['items'] as List).whereType<Map>().map(libraryMap).toList()
          : <Map<String, dynamic>>[];
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const WorkspaceBanner(
            eyebrow: 'YOUR GITHUB STARS',
            title: '把灵感带回校园',
            subtitle: '选择仓库存入个人项目，归属材料与上架审核在每个项目中单独提交。',
            icon: Icons.code_outlined,
          ),
          const SizedBox(height: 12),
          for (final item in items)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item['fullName'] ?? item['name'] ?? ''}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text('${item['description'] ?? ''}'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if ('${item['language'] ?? ''}'.isNotEmpty)
                          Chip(label: Text('${item['language']}')),
                        TextButton.icon(
                          onPressed: () => _openUrl('${item['url'] ?? ''}'),
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text('GitHub'),
                        ),
                        FilledButton.tonal(
                          onPressed:
                              _busy || _imported.contains('${item['fullName']}')
                              ? null
                              : () => _run(() async {
                                  await _gateway.importGithub(
                                    '${item['fullName']}',
                                    await _store.load(),
                                  );
                                  if (mounted) {
                                    setState(
                                      () =>
                                          _imported.add('${item['fullName']}'),
                                    );
                                  }
                                }),
                          child: Text(
                            _imported.contains('${item['fullName']}')
                                ? '已存入个人仓库'
                                : '存入个人仓库',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: '上一页',
                onPressed: _githubPage > 1
                    ? () => setState(() {
                        _githubPage--;
                        _githubFuture = _githubStars();
                      })
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text('第 $_githubPage 页'),
              IconButton(
                tooltip: '下一页',
                onPressed: data['nextPage'] == null
                    ? null
                    : () => setState(() {
                        _githubPage =
                            int.tryParse('${data['nextPage']}') ??
                            _githubPage + 1;
                        _githubFuture = _githubStars();
                      }),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      );
    },
  );
}

class _ProjectPanel extends StatefulWidget {
  const _ProjectPanel({
    required this.entry,
    required this.snapshot,
    required this.repository,
    required this.gateway,
    required this.settingsStore,
    this.onOpenProject,
  });
  final ForgeLibraryEntry entry;
  final ForgeLibrarySnapshot snapshot;
  final ForgeLibraryRepository repository;
  final ForgeGateway gateway;
  final ForgeIntegrationStore settingsStore;
  final Future<void> Function(String)? onOpenProject;
  @override
  State<_ProjectPanel> createState() => _ProjectPanelState();
}

class _ProjectPanelState extends State<_ProjectPanel> {
  late ForgeLibraryEntry _entry = widget.entry;
  late ForgeLibrarySnapshot _snapshot = widget.snapshot;
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      final data = await widget.repository.load();
      if (mounted) {
        setState(() {
          _snapshot = data;
          for (final entry in data.entries) {
            if (entry.id == _entry.id) _entry = entry;
          }
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = _libraryError(error, '操作失败，请检查集成设置与连接后重试'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit() async {
    final tags = TextEditingController(text: _entry.tags.join(', '));
    final note = TextEditingController(text: _entry.note);
    String category = _entry.categoryId;
    bool saving = false;
    String? error;
    if (!_snapshot.categories.any((row) => row.id == category)) category = '';
    final route = DialogRoute<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('整理个人收藏'),
          scrollable: true,
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: category,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '个人分类'),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('待分类')),
                    for (final row in _snapshot.categories)
                      DropdownMenuItem(
                        value: row.id,
                        child: Text(row.getStringValue('name')),
                      ),
                  ],
                  onChanged: saving
                      ? null
                      : (value) => update(() => category = value ?? ''),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tags,
                  enabled: !saving,
                  decoration: const InputDecoration(
                    labelText: '个人标签',
                    helperText: '使用逗号分隔',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: note,
                  enabled: !saving,
                  minLines: 3,
                  maxLines: 7,
                  decoration: const InputDecoration(labelText: '个人备注'),
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
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      update(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        await widget.repository.saveBookmark(
                          _entry.id,
                          category: category,
                          tags: tags.text.split(RegExp(r'[,，\n]')),
                          note: note.text,
                        );
                        if (context.mounted) Navigator.pop(context, true);
                      } catch (exception) {
                        if (context.mounted) {
                          update(() {
                            saving = false;
                            error = _libraryError(exception, '整理保存失败，请保留内容后重试');
                          });
                        }
                      }
                    },
              child: Text(saving ? '保存中…' : '保存'),
            ),
          ],
        ),
      ),
    );
    final saved = await Navigator.of(context).push(route);
    await route.completed;
    tags.dispose();
    note.dispose();
    if (saved == true && mounted) await _run(() async {});
  }

  @override
  Widget build(BuildContext context) {
    final analysis = _entry.analysis;
    final metadata = _entry.metadata;
    final github = libraryMap(metadata['repo']);
    final source = libraryMap(analysis['source']);
    RecordModel? subscription;
    for (final row in _snapshot.subscriptions) {
      if (row.getStringValue('repository') == _entry.id) subscription = row;
    }
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_entry.name),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              tooltip: '关闭项目面板',
              onPressed: _busy ? null : () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
          children: [
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Text(_entry.project.getStringValue('summary')),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _busy ? null : _edit,
                  icon: const Icon(Icons.edit_note),
                  label: const Text('分类、标签与备注'),
                ),
                if (widget.onOpenProject != null)
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(() => widget.onOpenProject!(_entry.id)),
                    icon: const Icon(Icons.source_outlined),
                    label: const Text('项目主页'),
                  ),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                          await widget.gateway.github(
                            _entry.id,
                            await widget.settingsStore.load(),
                          );
                        }),
                  icon: const Icon(Icons.cloud_sync_outlined),
                  label: const Text('更新 GitHub 信息'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                          await widget.gateway.analyze(
                            _entry.id,
                            await widget.settingsStore.load(),
                          );
                        }),
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('AI 分析'),
                ),
                TextButton.icon(
                  onPressed: _busy
                      ? null
                      : () => showForgeIntegrationSettings(
                          context,
                          store: widget.settingsStore,
                          gateway: widget.gateway,
                        ),
                  icon: const Icon(Icons.tune),
                  label: const Text('集成设置'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_entry.tags.isNotEmpty)
              Wrap(
                spacing: 6,
                children: [
                  for (final tag in _entry.tags) Chip(label: Text(tag)),
                ],
              ),
            if (_entry.note.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(_entry.note),
                ),
              ),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('订阅 GitHub 版本'),
                    subtitle: const Text('发布记录汇入自己的版本时间线'),
                    value: subscription != null,
                    onChanged: _busy
                        ? null
                        : (value) => _run(() async {
                            if (value) {
                              await widget.repository.subscribe(_entry.id);
                            } else {
                              await widget.repository.unsubscribe(
                                subscription!,
                              );
                            }
                          }),
                  ),
                  if (subscription != null)
                    SwitchListTile(
                      title: const Text('包含预发布版本'),
                      value: subscription.getBoolValue('includePrereleases'),
                      onChanged: _busy
                          ? null
                          : (value) => _run(() async {
                              await widget.repository.subscribe(
                                _entry.id,
                                includePrereleases: value,
                              );
                            }),
                    ),
                ],
              ),
            ),
            if (github.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('GitHub 信息', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('${github['fullName'] ?? ''}'),
              Wrap(
                spacing: 8,
                children: [
                  for (final text in [
                    github['language'],
                    github['license'],
                    'Star ${github['stars'] ?? 0}',
                    'Fork ${github['forks'] ?? 0}',
                  ])
                    if (text != null && '$text'.isNotEmpty)
                      Chip(label: Text('$text')),
                ],
              ),
              Text('代码更新 ${_date('${github['pushedAt'] ?? ''}')}'),
            ],
            const SizedBox(height: 20),
            Text('项目分析', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (analysis.isEmpty)
              const Text('点 AI 分析，整理项目用途、上手步骤和使用建议。')
            else ...[
              if ('${analysis['summary'] ?? ''}'.isNotEmpty)
                ForgeMarkdown(data: '${analysis['summary']}'),
              for (final (key, title) in [
                ('useCases', '适合做什么'),
                ('gettingStarted', '上手步骤'),
                ('risks', '使用时留意'),
              ])
                if (libraryStrings(analysis[key]).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        ForgeMarkdown(
                          data: libraryStrings(analysis[key])
                              .map((v) => '- $v')
                              .join('\n'),
                        ),
                      ],
                    ),
                  ),
              const SizedBox(height: 16),
              Text('建议分类：${analysis['suggestedCategory'] ?? '个人分类'}'),
              Wrap(
                spacing: 6,
                children: [
                  for (final tag in libraryStrings(analysis['suggestedTags']))
                    Chip(label: Text(tag)),
                ],
              ),
              FilledButton.tonalIcon(
                onPressed: _busy
                    ? null
                    : () => _run(
                        () => widget.repository.applySuggestions(
                          _entry,
                          _snapshot.categories,
                        ),
                      ),
                icon: const Icon(Icons.playlist_add_check),
                label: const Text('应用分类与标签建议'),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('已锁定的分类保留，建议标签与个人标签合并。'),
              ),
              if (source.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    '${source['provider'] ?? ''} · ${source['model'] ?? ''} · ${_date('${source['analyzedAt'] ?? ''}')}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
