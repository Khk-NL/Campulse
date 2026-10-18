/// 我的 / Profile.
///
/// 身份与个性化放在页首；语言、外观、数据源归入设置，与关于分别折叠。
library;

import 'package:campus_mobile/core/app_state.dart';
import 'package:campus_mobile/core/config/universities/ecnu.dart';
import 'package:campus_mobile/core/i18n/app_i18n.dart';
import 'package:campus_mobile/core/locale_resolution.dart';
import 'package:campus_mobile/data/models/app_user.dart';
import 'package:campus_mobile/data/models/university.dart';
import 'package:campus_mobile/data/repositories/campus_repository.dart';
import 'package:campus_mobile/data/repositories/data_source_mode.dart';
import 'package:campus_mobile/data/repositories/pocketbase_campus_repository.dart';
import 'package:campus_mobile/core/pocketbase_session.dart';
import 'package:campus_mobile/l10n/app_localizations.dart';

import 'theme_color_settings.dart';

import 'package:campus_mobile/features/shared/widgets/workspace_layout.dart';
import 'package:campus_mobile/features/apps/apps_page.dart';
import 'package:campus_mobile/features/apps/forge_page.dart';
import 'package:campus_mobile/features/shell/shell_routes.dart';

import 'package:flutter/material.dart';

/// 我的 / the profile screen.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, this.onOpenRepositories});
  final VoidCallback? onOpenRepositories;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const List<IconData> _avatarIcons = [
    Icons.person_outline,
    Icons.school_outlined,
    Icons.auto_awesome_outlined,
    Icons.eco_outlined,
  ];

  Future<void> _personalize(AppState state) async {
    final TextEditingController name = TextEditingController(
      text: state.displayName,
    );
    int avatar = state.avatarStyle;
    String? error;
    bool saving = false;
    final route = DialogRoute<void>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter update) => AlertDialog(
          title: const Text('个性化'),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: name,
                maxLength: 24,
                decoration: const InputDecoration(
                  labelText: '昵称',
                  helperText: '保存在本机，按账号分别使用',
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: <Widget>[
                  for (int i = 0; i < _avatarIcons.length; i++)
                    ChoiceChip(
                      label: Icon(_avatarIcons[i]),
                      selected: avatar == i,
                      onSelected: saving
                          ? null
                          : (_) => update(() => avatar = i),
                      tooltip: '头像样式 ${i + 1}',
                      showCheckmark: false,
                    ),
                ],
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
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
                        await state.setPersonalization(name.text, avatar);
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      } catch (e) {
                        if (dialogContext.mounted) {
                          update(() {
                            saving = false;
                            error = '请填写 1–24 个字的昵称，并重试保存';
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
    await Navigator.of(context).push(route);
    await route.completed;
    name.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshIdentity());
  }

  /// 身份可能在远端可用之后才拿到，因此进入这一页时再拉一次。
  /// The identity may only become available once the backend answers, so this refreshes
  /// on entry.
  Future<void> _refreshIdentity() async {
    await AppScope.read(context).loadIdentity();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppState state = AppScope.of(context);
    // 只返回内容：顶部栏由 AppShell 统一提供（我的 Tab）。
    // Content only: the shell supplies the shared top bar for the Profile tab.
    return RefreshIndicator(
      onRefresh: _refreshIdentity,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: <Widget>[
          _identityCard(context, l10n, state),
          const SizedBox(height: 16),
          _workspace(context),
          const SizedBox(height: 20),
          // 「设置」把语言 / 外观 / 数据源三块收在一张卡片下，标题层级更清楚，
          // 也符合"我的"页面应有的信息架构。
          // "Settings" gathers language, appearance and data source under one card, which
          // reads better and matches what a profile screen is expected to hold.
          _settingsCard(context, l10n, state),
          const SizedBox(height: 16),
          _aboutCard(context, l10n, state),
        ],
      ),
    );
  }

  Widget _workspace(BuildContext context) {
    final english = Localizations.localeOf(context).languageCode == 'en';
    final scheme = Theme.of(context).colorScheme;
    void open(String title, Widget page, {bool scaffold = true}) {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => scaffold
              ? Scaffold(
                  appBar: AppBar(title: Text(title)),
                  body: page,
                )
              : page,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          english ? 'Projects & updates' : '我的项目与消息',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          english
              ? 'Manage projects, campus updates and saved services.'
              : '管理作品，查看校园通知与常用入口。',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
        WorkspaceGrid(
          children: [
            WorkspaceAction(
              title: english ? 'My repositories' : '个人仓库',
              subtitle: english
                  ? 'Projects, reviews & discussions'
                  : '自己的项目 · 审核 · 讨论',
              icon: Icons.source_outlined,
              color: scheme.tertiary,
              onTap:
                  widget.onOpenRepositories ??
                  () => open(
                    '',
                    ForgePage(
                      initialMine: true,
                      showViewSwitcher: false,
                      onOpenAccount: () => Navigator.of(context).pop(),
                    ),
                    scaffold: false,
                  ),
            ),
            WorkspaceAction(
              title: english ? 'Notifications' : '我的通知',
              subtitle: english ? 'Courses & campus updates' : '课程通知 · 校园消息',
              icon: Icons.notifications_outlined,
              color: scheme.secondary,
              onTap: () => openNotificationCenter(context),
            ),
            WorkspaceAction(
              title: english ? 'Saved services' : '收藏的入口',
              subtitle: english ? 'Services you use often' : '把常用校园服务放在手边',
              icon: Icons.bookmarks_outlined,
              color: scheme.primary,
              onTap: () => open(
                english ? 'Favorites' : '收藏',
                const AppsPage(initialFavorites: true, quickAccessOnly: true),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 身份与登录入口 / identity and the sign-in entry.
  Widget _identityCard(
    BuildContext context,
    AppLocalizations l10n,
    AppState state,
  ) {
    final ThemeData theme = Theme.of(context);
    final AppUser? user = state.user;
    final String name = state.displayName.isNotEmpty
        ? state.displayName
        : l10n.profileNotSignedIn;
    final String university = _universityName(context, l10n, state);
    final String roles = user == null || user.roles.isEmpty
        ? '—'
        : user.roles
              .map((dynamic role) => role.toString().split('.').last)
              .join(', ');

    return Card(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: .18),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 30,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(
                    _avatarIcons[state.avatarStyle],
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        name,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        university,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _personalize(state),
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: '个性化',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(label: l10n.profileUniversity, value: university),
            _InfoRow(label: l10n.profileRole, value: roles),
            const SizedBox(height: 12),
            // 登录入口：主按钮用标准色实色块（官方"反白应用"），当前是未登录 → 登录；
            // 已登录 → 退出登录。两种状态都有明确动作，不做只有文案的死按钮。
            // The sign-in entry: the primary button is a solid standard-colour block (the
            // official reversed application). Signed out offers sign-in, signed in offers
            // sign-out — never a dead button with only a caption.
            FilledButton.icon(
              onPressed: user == null
                  ? () => state.repository is CampusAccountRepository
                        ? _showPocketBaseSignInDialog(context, state)
                        : _showSignInDialog(context, l10n, state)
                  : () => state.signOut(),
              icon: Icon(user == null ? Icons.login : Icons.logout, size: 18),
              label: Text(
                user == null ? l10n.profileSignIn : l10n.profileSignOut,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 登录对话框：本阶段不碰任何学校密码（§19），只提供演示身份。
  /// The sign-in dialog: this phase touches no school password (§19) and offers only the
  /// demo identity.
  Future<void> _showSignInDialog(
    BuildContext context,
    AppLocalizations l10n,
    AppState state,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l10n.profileLoginDialogTitle),
        content: Text(l10n.profileLoginDialogBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.actionCancel),
          ),
        ],
      ),
    );
  }

  Future<void> _showPocketBaseSignInDialog(
    BuildContext context,
    AppState state,
  ) async {
    final TextEditingController email = TextEditingController();
    final TextEditingController password = TextEditingController();
    final ({String action, String email, String password})? choice =
        await showDialog<({String action, String email, String password})>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Campulse 账号登录'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: '邮箱'),
                ),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '密码'),
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop((
                  action: 'verify',
                  email: email.text.trim(),
                  password: '',
                )),
                child: const Text('重发验证邮件'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop((
                  action: 'reset',
                  email: email.text.trim(),
                  password: '',
                )),
                child: const Text('忘记密码'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop((
                  action: 'register',
                  email: email.text.trim(),
                  password: '',
                )),
                child: const Text('注册'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop((
                  action: 'login',
                  email: email.text.trim(),
                  password: password.text,
                )),
                child: const Text('登录'),
              ),
            ],
          ),
        );
    email.dispose();
    password.dispose();
    if (choice == null || !context.mounted) return;
    if (choice.action == 'register') {
      await _showPocketBaseRegisterDialog(context, state, choice.email);
      return;
    }
    if (choice.action == 'reset') {
      await _showPocketBaseResetDialog(context, state, choice.email);
      return;
    }
    if (choice.action == 'verify') {
      if (!choice.email.contains('@')) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('请先填写注册邮箱。')));
        return;
      }
      try {
        await state.requestVerification(choice.email);
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('如果该邮箱已注册，请查收验证邮件。')));
        }
      } on CampusAccountException catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(error.message)));
        }
      } on Exception {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('邮件发送失败，请稍后重试。')));
        }
      }
      return;
    }
    try {
      await state.signInWithPassword(choice.email, choice.password);
    } on Exception {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('登录失败，请检查账号、邮箱验证状态与服务连接。')),
        );
      }
    }
  }

  Future<void> _showPocketBaseRegisterDialog(
    BuildContext context,
    AppState state,
    String initialEmail,
  ) async {
    final TextEditingController email = TextEditingController(
      text: initialEmail,
    );
    final TextEditingController password = TextEditingController();
    final TextEditingController confirm = TextEditingController();
    final bool? submitted = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('注册 Campulse 账号'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('注册后请打开验证邮件完成确认，再返回登录。'),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: '邮箱'),
              ),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(labelText: '密码'),
              ),
              TextField(
                controller: confirm,
                obscureText: true,
                decoration: const InputDecoration(labelText: '确认密码'),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('提交注册'),
          ),
        ],
      ),
    );
    if (submitted != true || !context.mounted) {
      email.dispose();
      password.dispose();
      confirm.dispose();
      return;
    }
    final String address = email.text.trim();
    final String secret = password.text;
    final String confirmation = confirm.text;
    email.dispose();
    password.dispose();
    confirm.dispose();
    if (!address.contains('@') || secret.length < 8 || secret != confirmation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写有效邮箱、至少 8 位密码，并确认两次密码一致。')),
      );
      return;
    }
    try {
      await state.registerWithPassword(address, secret);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('账号已创建，验证邮件已请求发送；收到后请打开最新邮件完成验证，再返回登录。'),
          ),
        );
      }
    } on CampusAccountException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on StateError catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } on Exception {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('注册或验证邮件发送失败，请检查邮箱及服务配置。')),
        );
      }
    }
  }

  Future<void> _showPocketBaseResetDialog(
    BuildContext context,
    AppState state,
    String initialEmail,
  ) async {
    final TextEditingController email = TextEditingController(
      text: initialEmail,
    );
    final bool? submitted = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('重置密码'),
        content: TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: '注册邮箱'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('发送邮件'),
          ),
        ],
      ),
    );
    final String address = email.text.trim();
    email.dispose();
    if (submitted != true || !context.mounted) return;
    if (!address.contains('@')) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请填写注册邮箱。')));
      return;
    }
    try {
      await state.requestPasswordReset(address);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('如果该邮箱已注册，请查收密码重置邮件。')));
      }
    } on Exception {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('邮件发送失败，请稍后重试。')));
      }
    }
  }

  /// 设置：语言 / 外观 / 数据源 / the settings card.
  Widget _settingsCard(
    BuildContext context,
    AppLocalizations l10n,
    AppState state,
  ) {
    return Card(
      child: ExpansionTile(
        key: const PageStorageKey<String>('profile-settings'),
        expansionAnimationStyle: MediaQuery.disableAnimationsOf(context)
            ? AnimationStyle.noAnimation
            : null,
        leading: Icon(
          Icons.settings_outlined,
          color: Theme.of(context).colorScheme.secondary,
        ),
        title: Text(l10n.profileSettings),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: <Widget>[
          _languageBlock(l10n, state),
          const SizedBox(height: 12),
          _appearanceBlock(l10n, state),
          ThemeColorSettings(state: state),
          const SizedBox(height: 12),
          _dataSourceBlock(context, l10n, state),
        ],
      ),
    );
  }

  /// 语言切换（§0.8 的硬要求）/ the language switcher (§0.8's hard requirement).
  Widget _languageBlock(AppLocalizations l10n, AppState state) {
    final String selected =
        state.locale?.languageCode ?? LanguageOption.system.code;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.profileLanguage,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: <Widget>[
            for (final LanguageOption option in LanguageOption.all)
              ChoiceChip(
                label: Text(_languageLabel(l10n, option)),
                selected: selected == option.code,
                onSelected: (_) => state.setLocale(option.locale),
              ),
          ],
        ),
      ],
    );
  }

  static String _languageLabel(AppLocalizations l10n, LanguageOption option) {
    switch (option.code) {
      case 'zh':
        return l10n.profileLanguageChinese;
      case 'en':
        return l10n.profileLanguageEnglish;
      default:
        return l10n.profileLanguageSystem;
    }
  }

  /// 外观（浅色 / 深色 / 跟随系统）/ appearance.
  Widget _appearanceBlock(AppLocalizations l10n, AppState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.profileAppearance,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: <Widget>[
            for (final ThemeMode mode in ThemeMode.values)
              ChoiceChip(
                label: Text(_themeModeLabel(l10n, mode)),
                selected: state.themeMode == mode,
                onSelected: (_) => state.setThemeMode(mode),
              ),
          ],
        ),
      ],
    );
  }

  static String _themeModeLabel(AppLocalizations l10n, ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return l10n.profileThemeSystem;
      case ThemeMode.light:
        return l10n.profileThemeLight;
      case ThemeMode.dark:
        return l10n.profileThemeDark;
    }
  }

  /// 数据源说明 / the data source explanation.
  ///
  /// Phase 0 的验收标准要求客户端与后端解耦，用户因此必须能看出当前数据来自哪里。
  /// Phase 0 requires the client to be decoupled from the backend, so users must be able
  /// to tell where the data comes from.
  ///
  /// 这里必须**分来源**说明：服务目录可能已经连着后端，而课程 / 待办 / 活动 / 公告
  /// 还是演示数据（§13-Phase 2 才建表）。一句话概括会误导用户。
  /// It has to be **per source**: the catalogue may be live while courses, tasks, events
  /// and notices are still demo data (their tables arrive in Phase 2), and one summary
  /// line would mislead.
  Widget _dataSourceBlock(
    BuildContext context,
    AppLocalizations l10n,
    AppState state,
  ) {
    final DataSourceMode services = state.sourceMode(DataSourceSource.services);
    final Object backend = state.repository;
    final bool everythingIsDemo =
        <DataSourceSource>[
          DataSourceSource.courses,
          DataSourceSource.tasks,
          DataSourceSource.events,
          DataSourceSource.announcements,
        ].every(
          (DataSourceSource source) =>
              state.sourceMode(source) == DataSourceMode.mock,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (backend is PocketBaseCampusRepository) ...<Widget>[
          Text('PocketBase · ${PocketBaseSession.baseUrl}'),
          if (backend.lastConnectionError != null)
            Text(
              backend.lastConnectionError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
        Text(
          l10n.profileDataSource,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        _InfoRow(
          label: l10n.dataSourceLabelServices,
          value: services == DataSourceMode.remote
              ? l10n.dataSourceCatalogueOnline
              : state.dataSourceMode == DataSourceMode.remote
              ? '${l10n.profileDataSourceRemote} · ${l10n.dataSourceMode(services)}'
              : l10n.dataSourceMode(services),
        ),
        if (everythingIsDemo) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            l10n.dataSourceDemoExplanation,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (state.dataSourceMode != DataSourceMode.remote) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            l10n.stateOfflineBody,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonal(
              onPressed: () => state.retryConnection(),
              child: Text(l10n.actionRetry),
            ),
          ),
        ],
      ],
    );
  }

  /// 关于 / about.
  Widget _aboutCard(
    BuildContext context,
    AppLocalizations l10n,
    AppState state,
  ) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: ExpansionTile(
        key: const PageStorageKey<String>('profile-about'),
        expansionAnimationStyle: MediaQuery.disableAnimationsOf(context)
            ? AnimationStyle.noAnimation
            : null,
        leading: Icon(Icons.info_outline, color: theme.colorScheme.tertiary),
        title: Text(l10n.profileAbout),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: <Widget>[
          Text(l10n.profileAboutBody, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 10),
          _InfoRow(label: l10n.profileVersion, value: state.config.appVersion),
        ],
      ),
    );
  }

  /// 高校名：优先后端返回值，其次本地配置。/ the university name: backend first, config second.
  static String _universityName(
    BuildContext context,
    AppLocalizations l10n,
    AppState state,
  ) {
    final University? university = state.university;
    if (university != null) return university.name;
    // 兜底走配置目录，通用代码里不出现校名。
    // The fallback reads the config directory; generic code never names a school.
    return ecnuUniversityName.resolve(
      Localizations.localeOf(context).languageCode,
    );
  }
}

/// 一行"标签：值" / one label/value row.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
