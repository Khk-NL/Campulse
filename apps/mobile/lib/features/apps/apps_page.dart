/// 「应用」分成快捷使用与校园作品两种视角，共用同一批入口和收藏状态。
/// 快捷使用按启动方式分组，学生作品也可在其中启动；校园作品只筛学生项目。
/// 详情与打开仍分别走服务或应用路径，保持来源与维护责任清晰。
library;

import 'dart:async';

import 'package:campus_mobile/core/app_scope_repository.dart';
import 'package:campus_mobile/core/app_state.dart';
import 'package:campus_mobile/core/config/university_config.dart';
import 'package:campus_mobile/core/favorites/favorites_controller.dart';
import 'package:campus_mobile/core/i18n/app_i18n.dart';
import 'package:campus_mobile/core/launcher/campus_launcher.dart';
import 'package:campus_mobile/core/launcher/external_opener.dart';
import 'package:campus_mobile/core/text/localized_text.dart';
import 'package:campus_mobile/core/theme/campus_theme.dart';
import 'package:campus_mobile/data/models/campus_app.dart';
import 'package:campus_mobile/data/models/campus_service.dart';
import 'package:campus_mobile/data/models/service_enums.dart';
import 'package:campus_mobile/data/repositories/campus_repository.dart';
import 'package:campus_mobile/data/repositories/data_source_mode.dart';
import 'package:campus_mobile/features/apps/campus_entry.dart';
import 'package:campus_mobile/features/apps/forge_page.dart';
import 'package:campus_mobile/features/community/community_page.dart';
import 'package:campus_mobile/features/apps/service_grouping.dart';
import 'package:campus_mobile/features/shared/widgets/offline_banner.dart';
import 'package:campus_mobile/features/shared/widgets/service_details_sheet.dart';
import 'package:campus_mobile/features/shared/widgets/state_views.dart';
import 'package:campus_mobile/features/shared/widgets/university_brand_mark.dart';
import 'package:campus_mobile/features/shared/widgets/workspace_layout.dart';
import 'package:campus_mobile/features/store/widgets/app_details_sheet.dart';
import 'package:campus_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

enum _AppsSurface { quick, forge, square }

/// 「应用」Tab / the Apps tab.
class AppsPage extends StatefulWidget {
  const AppsPage({
    super.key,
    this.refreshToken = 0,
    this.initialFavorites = false,
    this.quickAccessOnly = false,
  });
  final int refreshToken;
  final bool initialFavorites;
  final bool quickAccessOnly;

  @override
  State<AppsPage> createState() => _AppsPageState();
}

/// 一次取齐的数据 / everything one load needs.
class _Catalogue {
  const _Catalogue({
    required this.entries,
    required this.names,
    required this.descriptions,
  });

  /// 两个来源合并后的条目 / both sources, merged.
  final List<CampusEntry> entries;

  /// 服务的双语名称（演示数据自带；远端只有单语）。
  /// Bilingual service names; the backend sends one name only.
  final Map<String, LocalizedText> names;

  /// 服务的双语描述 / bilingual service descriptions.
  final Map<String, LocalizedText> descriptions;
}

class _AppsPageState extends State<AppsPage> {
  _AppsSurface _surface = _AppsSurface.quick;
  // 空 future 而不是 `late`：首帧永远不会读到未初始化字段。
  // An empty future rather than a `late` field: the first build never reads something
  // uninitialised.
  Future<_Catalogue> _catalogue = Future<_Catalogue>.value(
    const _Catalogue(
      entries: <CampusEntry>[],
      names: <String, LocalizedText>{},
      descriptions: <String, LocalizedText>{},
    ),
  );

  /// 当前子列表 / the selected sub-list.
  ServiceGroup _group = ServiceGroup.officialWorkbench;

  /// **每个子列表各自的**搜索词（互不影响）/ one search term per sub-list.
  final Map<ServiceGroup, String> _queries = <ServiceGroup, String>{
    for (final ServiceGroup group in ServiceGroup.values) group: '',
  };

  /// **每个子列表各自的**排序口径 / one ordering per sub-list.
  final Map<ServiceGroup, CampusEntrySort> _sorts =
      <ServiceGroup, CampusEntrySort>{
        for (final ServiceGroup group in ServiceGroup.values)
          group: CampusEntrySort.name,
      };

  /// 搜索框控制器（每个子列表一个，切回来时原来输入的词还在）。
  /// One controller per sub-list, so switching back keeps what was typed.
  final Map<ServiceGroup, TextEditingController> _controllers =
      <ServiceGroup, TextEditingController>{
        for (final ServiceGroup group in ServiceGroup.values)
          group: TextEditingController(),
      };

  /// 话题（标签）筛选（`null` = 全部）/ the topic filter, null for "all".
  String? _topic;

  /// 话题表：服务端规范名的并集，每次加载从未筛选的列表更新。
  ///
  /// 每次筛选都重建的话，选中一个话题之后其余话题会消失，用户再也换不回去。
  /// Built once from the **unfiltered** list: rebuilding per filter would drop every other topic
  /// and trap the user inside the one they picked.
  List<String> _topics = const <String>[];
  bool _filtersExpanded = false;
  late bool _favoritesOnly = widget.initialFavorites;
  List<CampusEntry> _unfilteredEntries = const <CampusEntry>[];

  /// 首次加载已经排过队了吗。/ whether the first load has already been queued.
  bool _loadQueued = false;

  @override
  void didUpdateWidget(AppsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshToken != oldWidget.refreshToken) _load();
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 依赖注入只能在 didChangeDependencies 里读（initState 里读会触发断言）。
    // Injected dependencies are readable only in didChangeDependencies; doing it in initState
    // trips an assertion.
    if (_loadQueued) return;
    _loadQueued = true;
    _load();
  }

  void _load() {
    final CampusRepository repository = CampusRepositoryScope.read(context);
    final Future<_Catalogue> catalogue = _fetch(repository);
    if (!mounted) {
      _catalogue = catalogue;
      return;
    }
    // 块体而非箭头体：赋的值是 Future，箭头体会把它当作 setState 回调的返回值。
    // A block body, not an arrow: the value is a Future, which an arrow body would hand back as
    // setState's return value.
    setState(() {
      _catalogue = catalogue;
    });
  }

  Future<_Catalogue> _fetch(CampusRepository repository) async {
    final String? topic = _topic;
    // 两个来源**都**在后端过滤，但用的是各自接口的语义：
    //   * 应用有真正的标签筛选（`?tag=`，归一化在服务端：全角、大小写、别名归并）；
    //   * 服务没有标签参数，只有 `?q=`（标题 / 说明 / 标签的子串）。
    // 这个不对称是**刻意**的：与其在客户端自己实现一套标签匹配（那正是标签分裂的起点），
    // 不如各用各的既定口径，并把差异写在这里。
    //
    // Both sources filter server-side, each with its own endpoint's semantics: apps have a real
    // `?tag=` filter normalised on the server, services only have `?q=`. The asymmetry is
    // deliberate — reimplementing tag matching here is how tag keys split.
    final List<CampusService> allServices = await repository.listServices(
      CampusServicesQuery(
        universityId: AppState.defaultUniversityId,
        sort: ServiceSortOrder.name,
      ),
    );
    final List<CampusApp> allApps = await repository.fetchCampusApps(
      const CampusAppsQuery(),
    );
    _unfilteredEntries = CampusEntries.merge(
      services: allServices,
      apps: allApps,
    );
    _topics = _collectTopics(_unfilteredEntries);
    final String? activeTopic = _topics.contains(topic) ? topic : null;
    _topic = activeTopic;
    final List<CampusService> services = activeTopic == null
        ? allServices
        : await repository.listServices(
            CampusServicesQuery(
              universityId: AppState.defaultUniversityId,
              text: activeTopic,
              sort: ServiceSortOrder.name,
            ),
          );
    final List<CampusApp> apps = activeTopic == null
        ? allApps
        : await repository.fetchCampusApps(CampusAppsQuery(tag: activeTopic));

    return _Catalogue(
      entries: CampusEntries.merge(services: services, apps: apps),
      names: await repository.fetchServiceNames(),
      descriptions: await repository.fetchServiceDescriptions(),
    );
  }

  /// 话题 = 两个来源的规范标签名的并集 / topics: the union of canonical tag names.
  static List<String> _collectTopics(List<CampusEntry> entries) {
    final Set<String> topics = <String>{};
    for (final CampusEntry entry in entries) {
      topics.addAll(entry.tags.where((String x) => x.trim().isNotEmpty));
    }
    return topics.toList()..sort();
  }

  /// 选一个话题（`null` = 全部）并向**后端**重新取数。
  /// Select a topic (null clears it) and re-fetch **from the backend**.
  void _selectTopic(String? topic) {
    if (_topic == topic) return;
    _topic = topic;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (widget.quickAccessOnly) return _quickAccess(context, l10n);
    // 只返回内容：顶部栏由 AppShell 统一提供（应用 Tab）。
    // Content only: the shell supplies the shared top bar for the Apps tab.
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              _surfaceSwitcher(l10n),
              if (_surface == _AppsSurface.forge)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _browseCommunityResources,
                    icon: const Icon(Icons.hub_outlined),
                    label: Text(
                      Localizations.localeOf(context).languageCode == 'en'
                          ? 'Campus communities & open source'
                          : '校内社区与开源资源',
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _surface == _AppsSurface.forge
              ? ForgePage(embedded: true, refreshToken: widget.refreshToken)
              : _surface == _AppsSurface.square
              ? CommunityPage(refreshToken: widget.refreshToken)
              : _quickAccess(context, l10n),
        ),
      ],
    );
  }

  void _browseCommunityResources() {
    final hadTopic = _topic != null;
    setState(() {
      _surface = _AppsSurface.quick;
      _group = ServiceGroup.web;
      _topic = null;
      _queries[ServiceGroup.web] = '校园社区';
      _controllers[ServiceGroup.web]!.text = '校园社区';
    });
    if (hadTopic) _load();
  }

  Widget _quickAccess(BuildContext context, AppLocalizations l10n) {
    return FutureBuilder<_Catalogue>(
      future: _catalogue,
      builder: (BuildContext context, AsyncSnapshot<_Catalogue> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingView();
        }
        final Object? error = snapshot.error;
        if (error != null) {
          return ErrorRetryView(details: error.toString(), onRetry: _load);
        }
        final _Catalogue catalogue =
            snapshot.data ??
            const _Catalogue(
              entries: <CampusEntry>[],
              names: <String, LocalizedText>{},
              descriptions: <String, LocalizedText>{},
            );

        final FavoritesController favorites = AppScope.of(context).favorites;
        bool isFavorite(CampusEntry entry) => favorites.contains(
          ServiceGrouping.favoriteBoardOf(ServiceGrouping.groupOfEntry(entry)),
          entry.key,
        );

        final Map<ServiceGroup, List<CampusEntry>> grouped =
            <ServiceGroup, List<CampusEntry>>{
              for (final ServiceGroup group in ServiceGrouping.orderedGroups)
                group: <CampusEntry>[],
            };
        for (final CampusEntry entry in catalogue.entries) {
          grouped[ServiceGrouping.groupOfEntry(entry)]!.add(entry);
        }

        final List<CampusEntry> source = _favoritesOnly
            ? catalogue.entries.where(isFavorite).toList()
            : grouped[_group]!;
        final List<CampusEntry> searched = CampusEntries.search(
          source,
          _queries[_group]!,
        );
        final List<CampusEntry> ordered = CampusEntries.sorted(
          searched,
          _sorts[_group]!,
        );
        final List<CampusEntry> visible = ServiceGrouping.favoritesFirstEntries(
          ordered,
          isFavorite: isFavorite,
        );

        return RefreshIndicator(
          onRefresh: () async => _load(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: <Widget>[
              WorkspaceBanner(
                eyebrow: 'CAMPUS CONNECTIONS',
                title: Localizations.localeOf(context).languageCode == 'en'
                    ? 'Find your next stop'
                    : '找到校园里的下一站',
                subtitle: Localizations.localeOf(context).languageCode == 'en'
                    ? 'Official services, useful tools and student communities.'
                    : '学校工作台、办事入口与学生工具，在这里连接。',
                icon: Icons.explore_outlined,
                actions: [_header(context, l10n)],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    showCheckmark: false,
                    selected: !_favoritesOnly,
                    label: Text(
                      Localizations.localeOf(context).languageCode == 'en'
                          ? 'Service directory'
                          : '服务目录',
                    ),
                    onSelected: (_) => setState(() => _favoritesOnly = false),
                  ),
                  ChoiceChip(
                    showCheckmark: false,
                    selected: _favoritesOnly,
                    avatar: const Icon(Icons.star_outline, size: 18),
                    label: Text(
                      Localizations.localeOf(context).languageCode == 'en'
                          ? 'My favorites'
                          : '我的收藏',
                    ),
                    onSelected: (_) => setState(() => _favoritesOnly = true),
                  ),
                ],
              ),
              if (_topics.isNotEmpty) _topicFilter(context, l10n),
              const SizedBox(height: 12),
              if (!_favoritesOnly) _subListSwitcher(context, l10n, grouped),
              const SizedBox(height: 8),
              _searchAndSort(
                context,
                l10n,
                hasHeat: CampusEntries.hasHeat(catalogue.entries),
              ),
              const SizedBox(height: 8),
              if (visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: EmptyStateView(
                    message:
                        _favoritesOnly && !_unfilteredEntries.any(isFavorite)
                        ? l10n.appsFavoritesEmpty
                        : _favoritesOnly
                        ? l10n.appsSearchEmpty
                        : grouped[_group]!.isEmpty
                        ? l10n.appsGroupEmpty
                        : l10n.appsSearchEmpty,
                    icon: Icons.filter_alt_off_outlined,
                  ),
                )
              else
                for (final CampusEntry entry in visible)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _EntryTile(
                      entry: entry,
                      name: _nameOf(catalogue, entry),
                      description: _descriptionOf(catalogue, entry),
                      isFavorite: isFavorite(entry),
                      onToggleFavorite: () async {
                        try {
                          await favorites.toggle(
                            ServiceGrouping.favoriteBoardOf(
                              ServiceGrouping.groupOfEntry(entry),
                            ),
                            entry.key,
                          );
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('收藏保存失败，请检查连接后重试')),
                            );
                          }
                        }
                      },
                      onOpen: () => _open(context, entry),
                      onDetails: () => _showDetails(context, entry),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }

  Widget _surfaceSwitcher(AppLocalizations l10n) =>
      SegmentedButton<_AppsSurface>(
        showSelectedIcon: false,
        segments: <ButtonSegment<_AppsSurface>>[
          ButtonSegment<_AppsSurface>(
            value: _AppsSurface.quick,
            label: Text(l10n.appsQuickAccess),
            icon: const Icon(Icons.bolt_outlined),
          ),
          ButtonSegment<_AppsSurface>(
            value: _AppsSurface.forge,
            label: Text(l10n.appsForge),
            icon: const Icon(Icons.code_outlined),
          ),
          ButtonSegment<_AppsSurface>(
            value: _AppsSurface.square,
            label: Text(
              Localizations.localeOf(context).languageCode == 'en'
                  ? 'Together'
                  : '校园广场',
            ),
            icon: const Icon(Icons.groups_outlined),
          ),
        ],
        selected: <_AppsSurface>{_surface},
        onSelectionChanged: (Set<_AppsSurface> selected) {
          setState(() {
            _surface = selected.first;
          });
        },
      );

  /// 服务可能带双语名 / a service may carry a bilingual name.
  String _nameOf(_Catalogue catalogue, CampusEntry entry) {
    final String? id = entry.service?.id;
    if (id == null) return entry.name;
    return catalogue.names[id]?.resolve(
          Localizations.localeOf(context).languageCode,
        ) ??
        entry.name;
  }

  /// 服务可能带双语描述 / a service may carry a bilingual description.
  String _descriptionOf(_Catalogue catalogue, CampusEntry entry) {
    final String? id = entry.service?.id;
    if (id == null) return entry.description;
    return catalogue.descriptions[id]?.resolve(
          Localizations.localeOf(context).languageCode,
        ) ??
        entry.description;
  }

  /// 页首：两条来源各自标注 / the header: each of the two sources says where it came from.
  Widget _header(BuildContext context, AppLocalizations l10n) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: <Widget>[
        const DataSourceBadge(),
        SourceModeBadge(
          source: DataSourceSource.apps,
          onlineLabel: l10n.dataSourceAppsOnline,
          mockLabel: l10n.dataSourceAppsMock,
        ),
      ],
    );
  }

  /// 话题筛选（标签）/ the topic (tag) filter.
  Widget _topicFilter(BuildContext context, AppLocalizations l10n) {
    final List<String> topics = _surface == _AppsSurface.forge
        ? _collectTopics(
            _unfilteredEntries.where((x) => x.isStudentProject).toList(),
          )
        : _topics;
    if (topics.isEmpty) return const SizedBox.shrink();
    final ThemeData theme = Theme.of(context);
    final bool english = Localizations.localeOf(context).languageCode == 'en';
    final Map<int, List<String>> categories = <int, List<String>>{};
    for (final String topic in topics) {
      final List<CampusEntry> entries = _unfilteredEntries
          .where(
            (entry) =>
                entry.tags.contains(topic) &&
                (_surface != _AppsSurface.forge || entry.isStudentProject),
          )
          .toList();
      final ServiceCategory? category = entries
          .map((entry) => entry.category)
          .whereType<ServiceCategory>()
          .firstOrNull;
      final int group = entries.every((entry) => entry.isStudentProject)
          ? 2
          : switch (category) {
              ServiceCategory.academic || ServiceCategory.library => 0,
              ServiceCategory.campusCard ||
              ServiceCategory.venue ||
              ServiceCategory.network ||
              ServiceCategory.map => 1,
              ServiceCategory.officialHub ||
              ServiceCategory.administration => 3,
              _ => 4,
            };
      categories.putIfAbsent(group, () => <String>[]).add(topic);
    }
    final List<String> labels = english
        ? [
            'Learning',
            'Campus life',
            'Projects & tools',
            'Administration',
            'Other',
          ]
        : ['学习与课程', '校园生活', '作品与工具', '校务服务', '其他标签'];
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Card(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: .25),
        child: ExpansionTile(
          key: ValueKey<String>(
            'tag-filter-${_surface.name}-${_filtersExpanded ? "open" : "closed"}',
          ),
          initiallyExpanded: _filtersExpanded,
          onExpansionChanged: (bool value) => _filtersExpanded = value,
          expansionAnimationStyle: MediaQuery.disableAnimationsOf(context)
              ? AnimationStyle.noAnimation
              : null,
          leading: Icon(Icons.tune, color: theme.colorScheme.secondary),
          title: Text(l10n.storeTagFilter),
          subtitle: Text(_topic ?? '${l10n.storeTagAll} · ${topics.length}'),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: ChoiceChip(
                showCheckmark: false,
                label: Text(l10n.storeTagAll),
                selected: _topic == null,
                onSelected: (_) => _selectTopic(null),
              ),
            ),
            for (final int group in categories.keys.toList()..sort())
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      labels[group],
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: <Widget>[
                        for (final String topic in categories[group]!)
                          ChoiceChip(
                            showCheckmark: false,
                            label: Text(topic),
                            selected: _topic == topic,
                            onSelected: (bool selected) =>
                                _selectTopic(selected ? topic : null),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 子列表切换器（带条数）/ the sub-list switcher, with counts.
  Widget _subListSwitcher(
    BuildContext context,
    AppLocalizations l10n,
    Map<ServiceGroup, List<CampusEntry>> grouped,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (final ServiceGroup group
              in ServiceGrouping.orderedGroups) ...<Widget>[
            ChoiceChip(
              label: Text(
                l10n.appsSubListLabel(
                  _groupTitle(l10n, group),
                  grouped[group]!.length,
                ),
              ),
              selected: _group == group,
              onSelected: (bool _) => setState(() => _group = group),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  /// 当前子列表的搜索框 + 排序 / this sub-list's own search box and ordering.
  Widget _searchAndSort(
    BuildContext context,
    AppLocalizations l10n, {
    required bool hasHeat,
  }) {
    final ThemeData theme = Theme.of(context);
    final CampusEntrySort current = _sorts[_group]!;
    final TextEditingController controller = _controllers[_group]!;
    return Row(
      children: <Widget>[
        Expanded(
          child: TextField(
            // 换子列表时换 key，让输入框确实挂到那一个子列表的控制器上。
            // A new key per sub-list so the field really attaches to that sub-list's controller.
            key: ValueKey<ServiceGroup>(_group),
            controller: controller,
            textInputAction: TextInputAction.search,
            onChanged: (String value) =>
                setState(() => _queries[_group] = value),
            decoration: InputDecoration(
              isDense: true,
              hintText: l10n.appsSearchHint,
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: _queries[_group]!.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      tooltip: l10n.actionClear,
                      onPressed: () {
                        controller.clear();
                        setState(() => _queries[_group] = '');
                      },
                    ),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<CampusEntrySort>(
          tooltip: l10n.appsSortLabel,
          initialValue: current,
          onSelected: (CampusEntrySort value) =>
              setState(() => _sorts[_group] = value),
          itemBuilder: (BuildContext context) =>
              <PopupMenuEntry<CampusEntrySort>>[
                CheckedPopupMenuItem<CampusEntrySort>(
                  value: CampusEntrySort.name,
                  checked: current == CampusEntrySort.name,
                  child: Text(l10n.appsSortName),
                ),
                // 热度只在真的有计数时才给出来：全是 0 的时候点它，看到的是名称顺序——
                // 一个"看起来在工作、其实没有信息"的控件，本项目一贯拒绝这种东西。
                //
                // The heat option appears only once counts really exist: with every count at 0 it
                // would show name order under a heat label, a control that looks like it works and
                // carries nothing.
                if (hasHeat)
                  CheckedPopupMenuItem<CampusEntrySort>(
                    value: CampusEntrySort.heat,
                    checked: current == CampusEntrySort.heat,
                    child: Text(l10n.appsSortHeat),
                  ),
                CheckedPopupMenuItem<CampusEntrySort>(
                  value: CampusEntrySort.recentlyUpdated,
                  checked: current == CampusEntrySort.recentlyUpdated,
                  child: Text(l10n.appsSortRecent),
                ),
              ],
          child: Chip(
            avatar: const Icon(Icons.sort, size: 16),
            label: Text(_sortLabel(l10n, current)),
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }

  /// 排序口径的名称 / an ordering's label.
  String _sortLabel(AppLocalizations l10n, CampusEntrySort sort) {
    switch (sort) {
      case CampusEntrySort.name:
        return l10n.appsSortName;
      case CampusEntrySort.heat:
        return l10n.appsSortHeat;
      case CampusEntrySort.recentlyUpdated:
        return l10n.appsSortRecent;
    }
  }

  /// 子列表标题 / a sub-list's title.
  String _groupTitle(AppLocalizations l10n, ServiceGroup group) {
    switch (group) {
      case ServiceGroup.officialWorkbench:
        return l10n.appsGroupOfficialWorkbench;
      case ServiceGroup.web:
        return l10n.appsGroupWeb;
      case ServiceGroup.miniProgram:
        return l10n.appsGroupMiniProgram;
    }
  }

  /// 打开一条入口，并在**真的打开成功**之后记一次热度。
  ///
  /// 记热度放在成功之后：失败的一次点击不是一次使用；而且"打开"是主操作，绝不能因为记账
  /// 失败被挡住（`recordServiceOpen` / `recordAppOpen` 在上层吞掉异常）。
  ///
  /// Opens one entry and records heat **only after a real success**: a failed tap is not a use,
  /// and the primary action must never be blocked by bookkeeping.
  Future<void> _open(BuildContext context, CampusEntry entry) async {
    final CampusRepository repository = CampusRepositoryScope.read(context);
    final LaunchOutcome outcome = await launchServiceFrom(
      context,
      target: entry.launchTarget,
    );
    if (outcome != LaunchOutcome.handedOff &&
        outcome != LaunchOutcome.openedInApp) {
      return;
    }
    final CampusService? service = entry.service;
    final String? appId = entry.app?.id;
    if (service != null) {
      unawaited(repository.recordServiceOpen(service.id));
    } else if (appId != null) {
      unawaited(repository.recordAppOpen(appId));
    }
  }

  /// 详情：两类数据各走各的弹层 / details: each kind keeps its own sheet.
  void _showDetails(BuildContext context, CampusEntry entry) {
    final CampusApp? app = entry.app;
    if (app != null) {
      showAppDetails(context, app: app);
      return;
    }
    final CampusService? service = entry.service;
    if (service == null) return;
    showServiceDetails(
      context,
      service: service,
      contactGroupNumber:
          UniversityConfigs.defaultConfig.contactGroupNumbers[service.sourceId],
    );
  }
}

/// 一条入口 / one entry row.
///
/// 点一下**直接打开**，详情在长按与「更多」上，收藏在右侧星标上（在本子列表内置顶）。
/// A tap **opens directly**; details live on long-press and "More"; the star favorites the row
/// inside its own sub-list.
class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.name,
    required this.description,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onOpen,
    required this.onDetails,
  });

  final CampusEntry entry;
  final String name;
  final String description;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onOpen;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onOpen,
        onLongPress: onDetails,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _leadingIcon(entry),
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // 官方的"特殊标识"：校徽。学生与官方在列表里地位相同，这是唯一的界面差别。
                        // The one visual difference an official entry gets: the school mark.
                        if (entry.isOfficial) ...<Widget>[
                          const SizedBox(width: 6),
                          UniversityBrandMark(
                            assetPath:
                                UniversityConfigs.defaultConfig.brandMarkAsset,
                            height: 14,
                            semanticLabel: l10n.originOfficial,
                          ),
                        ],
                      ],
                    ),
                    if (description.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        TinyBadge(
                          label: l10n.serviceOrigin(entry.origin),
                          color: entry.isOfficial
                              ? theme.colorScheme.primary
                              : theme.statusColors.info,
                        ),
                        // 热度只在非零时显示：把 0 摆在每一条上，等于告诉用户这个数字没意义。
                        if (entry.openCount > 0)
                          Tooltip(
                            message: l10n.appsHeatTooltip(entry.openCount),
                            child: TinyBadge(
                              label: '${entry.openCount}',
                              icon: Icons.local_fire_department_outlined,
                              color: theme.statusColors.warning,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // 开源仓库入口：学生项目取信的主要凭据（用户明确要求"愿意开源可以给出 GitHub 链接"）。
              // 只有真的挂了仓库才出现——服务没有这个字段，因此这里不会有"空链接"。
              //
              // The repository affordance: how a student project earns trust. It appears only when
              // a repository really exists, so there is never an empty link.
              if (entry.hasRepository)
                IconButton(
                  icon: const Icon(Icons.code),
                  tooltip: l10n.storeRepository,
                  onPressed: () => unawaited(
                    openUrlExternally(Uri.parse(entry.repositoryUrl!)),
                  ),
                ),
              IconButton(
                icon: Icon(isFavorite ? Icons.star : Icons.star_border),
                color: isFavorite
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
                tooltip: isFavorite
                    ? l10n.appsFavoriteRemove
                    : l10n.appsFavoriteAdd,
                onPressed: onToggleFavorite,
              ),
              IconButton(
                icon: const Icon(Icons.more_horiz),
                tooltip: l10n.appsMore,
                onPressed: onDetails,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 图标：服务用分类，应用用启动方式。
  ///
  /// 两类的"它是什么"本来就不同——服务有分类（教务 / 图书馆 / 场馆），应用只有启动方式。
  /// 硬套同一套图标会给出错的暗示。
  ///
  /// Services get a category icon, apps a launch-kind icon: the two kinds differ in what "what
  /// is this" means, and forcing one icon set would imply otherwise.
  static IconData _leadingIcon(CampusEntry entry) {
    final ServiceCategory? category = entry.category;
    if (category != null) return _categoryIcon(category);
    switch (entry.launchTarget.type) {
      case LaunchTargetType.wechatMiniProgram:
        return Icons.qr_code_2;
      case LaunchTargetType.nativeApp:
        return Icons.phone_android;
      case LaunchTargetType.campusApp:
        return Icons.extension_outlined;
      case LaunchTargetType.web:
        return Icons.public;
    }
  }

  /// 分类 → 图标 / a category's icon.
  ///
  /// 后端目前不给 `iconUrl`，因此先用分类图标：它不带任何高校色彩，对任何学校都成立。
  static IconData _categoryIcon(ServiceCategory category) {
    switch (category) {
      case ServiceCategory.officialHub:
        return Icons.dashboard_customize_outlined;
      case ServiceCategory.academic:
        return Icons.school_outlined;
      case ServiceCategory.library:
        return Icons.local_library_outlined;
      case ServiceCategory.campusCard:
        return Icons.credit_card;
      case ServiceCategory.venue:
        return Icons.sports_tennis_outlined;
      case ServiceCategory.network:
        return Icons.wifi;
      case ServiceCategory.map:
        return Icons.map_outlined;
      case ServiceCategory.administration:
        return Icons.assignment_outlined;
      case ServiceCategory.other:
        return Icons.apps_outlined;
    }
  }
}
