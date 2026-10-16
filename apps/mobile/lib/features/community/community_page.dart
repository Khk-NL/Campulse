import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:campus_mobile/core/app_state.dart';
import 'package:campus_mobile/core/pocketbase_session.dart';
import 'package:campus_mobile/features/profile/profile_page.dart';
import 'package:campus_mobile/features/shared/widgets/workspace_layout.dart';

import 'community_repository.dart';

const communityKinds = {
  'competition': '竞赛组队',
  'sport': '运动约局',
  'study': '学习搭子',
  'social': '校园扩列',
};
const communityCampuses = {
  'minhang': '闵行校区',
  'putuo': '普陀校区',
  'online': '线上',
  'other': '其他地点',
};
const _kindIcons = {
  'competition': Icons.emoji_events_outlined,
  'sport': Icons.sports_tennis_outlined,
  'study': Icons.local_library_outlined,
  'social': Icons.people_outline,
};

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key, this.repository, this.refreshToken = 0});
  final CommunityRepository? repository;
  final int refreshToken;
  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  CommunityRepository? get repo =>
      widget.repository ??
      (PocketBaseSession.instance == null
          ? null
          : CommunityRepository(PocketBaseSession.instance!.client));
  bool people = false;
  String scope = 'all';
  String? kind, campus;
  String query = '';
  int page = 1;
  final search = TextEditingController();
  Timer? debounce;
  Future<ResultList<RecordModel>>? rows;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(CommunityPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) setState(load);
  }

  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    super.dispose();
  }

  void load() {
    if (repo?.canParticipate != true) return;
    rows = people
        ? repo!.profiles(page: page, query: query)
        : repo!.posts(
            page: page,
            kind: kind,
            campus: campus,
            query: query,
            scope: scope,
          );
  }

  void change(VoidCallback action) {
    debounce?.cancel();
    setState(() {
      action();
      page = 1;
      load();
    });
  }

  Future<void> edit() async {
    try {
      final existing = people ? await repo!.myProfile() : null;
      if (!mounted) return;
      final saved = await _editCommunity(
        context,
        repo!,
        profile: people,
        existing: existing,
      );
      if (saved && mounted) change(() {});
    } catch (_) {
      if (mounted) _message(context, '资料读取失败，请刷新后重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (repo?.canParticipate != true) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.groups_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              const Text('登录并验证邮箱，加入校园广场'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  await Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('账号')),
                        body: const ProfilePage(),
                      ),
                    ),
                  );
                  if (mounted) setState(load);
                },
                child: const Text('前往账号'),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        setState(load);
        await rows;
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          WorkspaceBanner(
            eyebrow: 'CAMPUS TOGETHER',
            title: '把同频的人聚在一起',
            subtitle: '组一支竞赛队，约一场羽毛球，或从共同兴趣开始认识。',
            icon: Icons.groups_2_outlined,
            actions: [
              FilledButton.icon(
                onPressed: edit,
                icon: Icon(people ? Icons.badge_outlined : Icons.add),
                label: Text(people ? '编辑我的名片' : '发布召集'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: false,
                label: Text('活动与组队'),
                icon: Icon(Icons.diversity_3_outlined),
              ),
              ButtonSegment(
                value: true,
                label: Text('兴趣名片'),
                icon: Icon(Icons.badge_outlined),
              ),
            ],
            selected: {people},
            onSelectionChanged: (values) => change(() => people = values.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: search,
            onChanged: (value) {
              debounce?.cancel();
              debounce = Timer(
                const Duration(milliseconds: 300),
                () => change(() => query = value.trim()),
              );
            },
            onSubmitted: (value) => change(() => query = value.trim()),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: people ? '搜索兴趣、技能或昵称' : '搜索活动、技能或话题',
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '清空搜索',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        search.clear();
                        change(() => query = '');
                      },
                    ),
            ),
          ),
          const SizedBox(height: 12),
          if (!people) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('全部类型'),
                  selected: kind == null,
                  showCheckmark: false,
                  onSelected: (_) => change(() => kind = null),
                ),
                for (final entry in communityKinds.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    avatar: Icon(_kindIcons[entry.key], size: 18),
                    selected: kind == entry.key,
                    showCheckmark: false,
                    onSelected: (_) => change(() => kind = entry.key),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                DropdownButton<String>(
                  value: scope,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('全部召集')),
                    DropdownMenuItem(value: 'mine', child: Text('我发布的')),
                    DropdownMenuItem(value: 'joined', child: Text('我报名的')),
                  ],
                  onChanged: (v) => change(() => scope = v ?? 'all'),
                ),
                DropdownButton<String>(
                  value: campus ?? '',
                  items: [
                    const DropdownMenuItem(value: '', child: Text('全部校区')),
                    for (final e in communityCampuses.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => change(() => campus = v == '' ? null : v),
                ),
              ],
            ),
          ],
          FutureBuilder<ResultList<RecordModel>>(
            future: rows,
            builder: (context, snapshot) {
              if (snapshot.hasError) return _retry(() => setState(load));
              if (!snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              final result = snapshot.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (result.items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('分享你的计划或兴趣，让同学更容易找到你。'),
                    ),
                  WorkspaceGrid(
                    minWidth: 330,
                    children: [
                      for (final item in result.items)
                        people ? _profileCard(item) : _postCard(item),
                    ],
                  ),
                  if (result.totalPages > 1)
                    _pager(
                      page,
                      result.totalPages,
                      (value) => setState(() {
                        page = value;
                        load();
                      }),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _postCard(RecordModel item) {
    final color = Theme.of(context).colorScheme;
    final kind = item.getStringValue('kind');
    final date = _date(item.getStringValue('startsAt'));
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => CommunityPostPage(repository: repo!, id: item.id),
            ),
          );
          if (mounted) setState(load);
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.secondaryContainer,
                    foregroundColor: color.onSecondaryContainer,
                    child: Icon(_kindIcons[kind] ?? Icons.groups_outlined),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(communityKinds[kind] ?? kind)),
                  Text(
                    item.getStringValue('status') == 'open' ? '召集中' : '已结束',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                item.getStringValue('title'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                item.getStringValue('body'),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 14),
              Text(
                [
                  communityCampuses[item.getStringValue('campus')] ?? '',
                  item.getStringValue('location'),
                ].where((part) => part.isNotEmpty).join(' · '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (date.isNotEmpty)
                Text(date, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              Text(
                [
                  item.getStringValue('displayName'),
                  item.getStringValue('tags'),
                ].where((part) => part.isNotEmpty).join(' · '),
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: color.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileCard(RecordModel item) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(child: Icon(Icons.person_outline)),
            title: Text(item.getStringValue('displayName')),
            subtitle: Text(
              communityCampuses[item.getStringValue('campus')] ?? '',
            ),
          ),
          SelectableText(item.getStringValue('bio')),
          const SizedBox(height: 10),
          Text(
            item.getStringValue('interests'),
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => change(() {
              people = false;
              kind = 'social';
              campus = item.getStringValue('campus');
              query = '';
              search.clear();
              scope = 'all';
            }),
            icon: const Icon(Icons.people_outline),
            label: const Text('看看同校区的扩列召集'),
          ),
        ],
      ),
    ),
  );
}

class CommunityPostPage extends StatefulWidget {
  const CommunityPostPage({
    super.key,
    required this.repository,
    required this.id,
  });
  final CommunityRepository repository;
  final String id;
  @override
  State<CommunityPostPage> createState() => _CommunityPostPageState();
}

typedef _Detail = ({
  RecordModel post,
  List<RecordModel> interests,
  ResultList<RecordModel> replies,
});

class _CommunityPostPageState extends State<CommunityPostPage> {
  int page = 1;
  bool busy = false;
  late Future<_Detail> detail = load();
  Future<_Detail> load() async {
    final results = await Future.wait<Object>([
      widget.repository.post(widget.id),
      widget.repository.interests(widget.id),
      widget.repository.replies(widget.id, page: page),
    ]);
    return (
      post: results[0] as RecordModel,
      interests: results[1] as List<RecordModel>,
      replies: results[2] as ResultList<RecordModel>,
    );
  }

  Future<void> act(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
      if (mounted) setState(() => detail = load());
    } catch (_) {
      if (mounted) _message(context, '操作保存失败，请刷新后重试');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> write({required bool join}) async {
    final result = await _writeMessage(context, join: join);
    if (result == null || !mounted) return;
    await act(() async {
      if (join) {
        await widget.repository.join(widget.id, result.name, result.body);
      } else {
        await widget.repository.reply(widget.id, result.name, result.body);
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('校园召集')),
    body: FutureBuilder<_Detail>(
      future: detail,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _retry(() => setState(() => detail = load()));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!, item = data.post;
        final owner = item.getStringValue('owner') == widget.repository.userId;
        final open = item.getStringValue('status') == 'open';
        final mine = data.interests
            .where((r) => r.getStringValue('owner') == widget.repository.userId)
            .firstOrNull;
        return RefreshIndicator(
          onRefresh: () async {
            setState(() => detail = load());
            await detail;
          },
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              WorkspaceBanner(
                eyebrow: communityKinds[item.getStringValue('kind')] ?? '',
                title: item.getStringValue('title'),
                subtitle:
                    '${item.getStringValue('displayName')} · ${open ? '召集中' : '已结束'}',
                icon:
                    _kindIcons[item.getStringValue('kind')] ??
                    Icons.groups_outlined,
              ),
              const SizedBox(height: 16),
              SelectableText(item.getStringValue('body')),
              const SizedBox(height: 16),
              Text(
                [
                  communityCampuses[item.getStringValue('campus')] ?? '',
                  item.getStringValue('location'),
                ].where((part) => part.isNotEmpty).join(' · '),
              ),
              if (item.getStringValue('startsAt').isNotEmpty)
                Text(_date(item.getStringValue('startsAt'))),
              if (item.getStringValue('tags').isNotEmpty)
                Text(item.getStringValue('tags')),
              const SizedBox(height: 12),
              const Text('相互确认时间与活动安排，优先选择校内公共场所。'),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (owner)
                    OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () => act(() async {
                              await _editCommunity(
                                context,
                                widget.repository,
                                profile: false,
                                existing: item,
                              );
                            }),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('编辑召集'),
                    ),
                  if (owner)
                    OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () => act(
                              () => widget.repository.setStatus(
                                widget.id,
                                open ? 'closed' : 'open',
                              ),
                            ),
                      icon: Icon(open ? Icons.task_alt : Icons.refresh),
                      label: Text(open ? '结束召集' : '重新开放'),
                    ),
                  if (!owner)
                    FilledButton.icon(
                      onPressed: busy || (!open && mine == null)
                          ? null
                          : () => mine == null
                                ? write(join: true)
                                : act(() => widget.repository.leave(mine.id)),
                      icon: Icon(
                        mine == null ? Icons.person_add_alt : Icons.logout,
                      ),
                      label: Text(mine == null ? '我想参加' : '退出报名'),
                    ),
                  if (open)
                    OutlinedButton.icon(
                      onPressed: busy ? null : () => write(join: false),
                      icon: const Icon(Icons.forum_outlined),
                      label: const Text('参与讨论'),
                    ),
                ],
              ),
              if (owner) ...[
                const SizedBox(height: 24),
                Text(
                  '报名意向 · ${data.interests.length}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Text('报名留言由发起人与报名者查看。'),
                for (final person in data.interests)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(person.getStringValue('displayName')),
                      subtitle: Text(person.getStringValue('message')),
                    ),
                  ),
              ],
              const SizedBox(height: 24),
              Text(
                '活动讨论 · ${data.replies.totalItems}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final reply in data.replies.items)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.chat_bubble_outline),
                    title: Text(reply.getStringValue('displayName')),
                    subtitle: SelectableText(reply.getStringValue('body')),
                  ),
                ),
              if (data.replies.totalPages > 1)
                _pager(
                  page,
                  data.replies.totalPages,
                  (next) => setState(() {
                    page = next;
                    detail = load();
                  }),
                ),
            ],
          ),
        );
      },
    ),
  );
}

Future<bool> _editCommunity(
  BuildContext context,
  CommunityRepository repo, {
  required bool profile,
  RecordModel? existing,
}) async {
  final form = GlobalKey<FormState>();
  final fields = <String, dynamic>{
    'displayName': existing?.getStringValue('displayName') ?? _name(context),
    'campus': existing?.getStringValue('campus') ?? 'minhang',
    if (profile) ...{
      'bio': existing?.getStringValue('bio') ?? '',
      'interests': existing?.getStringValue('interests') ?? '',
      'published': existing?.getBoolValue('published') ?? false,
    } else ...{
      'title': existing?.getStringValue('title') ?? '',
      'body': existing?.getStringValue('body') ?? '',
      'kind': existing?.getStringValue('kind') ?? 'competition',
      'location': existing?.getStringValue('location') ?? '',
      'tags': existing?.getStringValue('tags') ?? '',
    },
  };
  DateTime? startsAt = DateTime.tryParse(
    existing?.getStringValue('startsAt') ?? '',
  )?.toLocal();
  String? error;
  bool busy = false;
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: Text(profile ? '我的兴趣名片' : '发布校园召集'),
            scrollable: true,
            content: SizedBox(
              width: 520,
              child: Form(
                key: form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      initialValue: fields['displayName'],
                      maxLength: 40,
                      decoration: const InputDecoration(labelText: '展示昵称'),
                      validator: _required,
                      onChanged: (value) =>
                          fields['displayName'] = value.trim(),
                    ),
                    if (!profile) ...[
                      TextFormField(
                        initialValue: fields['title'],
                        maxLength: 120,
                        decoration: const InputDecoration(labelText: '标题'),
                        validator: _required,
                        onChanged: (value) => fields['title'] = value.trim(),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: fields['kind'],
                        decoration: const InputDecoration(labelText: '类型'),
                        items: [
                          for (final e in communityKinds.entries)
                            DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                        ],
                        onChanged: (v) => fields['kind'] = v,
                      ),
                    ],
                    DropdownButtonFormField<String>(
                      initialValue: fields['campus'],
                      decoration: const InputDecoration(labelText: '校区与地点'),
                      items: [
                        for (final e in communityCampuses.entries)
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                      ],
                      onChanged: (v) => fields['campus'] = v,
                    ),
                    TextFormField(
                      initialValue: profile ? fields['bio'] : fields['body'],
                      maxLength: profile ? 1000 : 10000,
                      minLines: 3,
                      maxLines: 7,
                      decoration: InputDecoration(
                        labelText: profile ? '关于自己' : '介绍、分工与参加方式',
                      ),
                      validator: profile ? null : _required,
                      onChanged: (v) =>
                          fields[profile ? 'bio' : 'body'] = v.trim(),
                    ),
                    TextFormField(
                      initialValue: profile
                          ? fields['interests']
                          : fields['tags'],
                      maxLength: 200,
                      decoration: InputDecoration(
                        labelText: profile ? '兴趣与技能' : '话题与技能',
                      ),
                      onChanged: (v) =>
                          fields[profile ? 'interests' : 'tags'] = v.trim(),
                    ),
                    if (profile)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('在兴趣名片中展示'),
                        subtitle: const Text('向已验证邮箱的 Campulse 用户展示以上内容'),
                        value: fields['published'],
                        onChanged: (v) => update(() => fields['published'] = v),
                      )
                    else ...[
                      TextFormField(
                        initialValue: fields['location'],
                        maxLength: 160,
                        decoration: const InputDecoration(labelText: '具体地点'),
                        onChanged: (v) => fields['location'] = v.trim(),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.event_outlined),
                        label: Text(
                          startsAt == null
                              ? '设置活动时间（可选）'
                              : _date(startsAt!.toIso8601String()),
                        ),
                        onPressed: () async {
                          final day = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 1),
                            ),
                            lastDate: DateTime.now().add(
                              const Duration(days: 730),
                            ),
                          );
                          if (day == null || !context.mounted) return;
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (time != null && context.mounted) {
                            update(
                              () => startsAt = DateTime(
                                day.year,
                                day.month,
                                day.day,
                                time.hour,
                                time.minute,
                              ),
                            );
                          }
                        },
                      ),
                    ],
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
                onPressed: busy
                    ? null
                    : () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (!form.currentState!.validate()) return;
                        update(() {
                          busy = true;
                          error = null;
                        });
                        try {
                          if (profile) {
                            await repo.saveProfile(existing?.id, fields);
                          } else {
                            final payload = {
                              ...fields,
                              'startsAt':
                                  startsAt?.toUtc().toIso8601String() ?? '',
                            };
                            if (existing == null) {
                              await repo.publish(payload);
                            } else {
                              await repo.updatePost(existing.id, payload);
                            }
                          }
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext, true);
                          }
                        } catch (_) {
                          if (context.mounted) {
                            update(() {
                              busy = false;
                              error = '保存失败，请检查连接后重试';
                            });
                          }
                        }
                      },
                child: Text(busy ? '保存中…' : '保存'),
              ),
            ],
          ),
        ),
      ) ??
      false;
}

String? _required(String? value) =>
    value?.trim().isNotEmpty == true ? null : '请填写此项';
String _name(BuildContext context) {
  final name = AppScope.read(context).displayName;
  return name.isEmpty ? '同学' : name;
}

String _date(String value) {
  final date = DateTime.tryParse(value)?.toLocal();
  return date == null
      ? ''
      : '${date.month}月${date.day}日 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

Future<({String name, String body})?> _writeMessage(
  BuildContext context, {
  required bool join,
}) {
  String name = _name(context), body = '';
  final form = GlobalKey<FormState>();
  return showDialog<({String name, String body})>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: Text(join ? '报名意向' : '参与讨论'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: name,
                maxLength: 40,
                decoration: const InputDecoration(labelText: '展示昵称'),
                validator: _required,
                onChanged: (v) => name = v.trim(),
              ),
              TextFormField(
                minLines: 3,
                maxLines: 6,
                maxLength: join ? 1000 : 3000,
                decoration: InputDecoration(
                  labelText: join ? '给发起人的留言' : '讨论内容',
                ),
                validator: join ? null : _required,
                onChanged: (v) => body = v.trim(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            if (form.currentState!.validate()) {
              Navigator.pop(context, (name: name, body: body));
            }
          },
          child: const Text('提交'),
        ),
      ],
    ),
  );
}

void _message(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
Widget _retry(VoidCallback retry) => Padding(
  padding: const EdgeInsets.all(24),
  child: Column(
    children: [
      const Text('广场加载失败，请检查连接后重试'),
      TextButton(onPressed: retry, child: const Text('重新加载')),
    ],
  ),
);
Widget _pager(int page, int total, ValueChanged<int> change) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 16),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      IconButton(
        tooltip: '上一页',
        onPressed: page > 1 ? () => change(page - 1) : null,
        icon: const Icon(Icons.chevron_left),
      ),
      Text('$page / $total'),
      IconButton(
        tooltip: '下一页',
        onPressed: page < total ? () => change(page + 1) : null,
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  ),
);
