/// 通用展示组件 / shared presentation widgets.
///
/// 这些组件不认识任何业务：它们只回答"加载中长什么样""空状态长什么样"。因此将来
/// 新增一个 Tab 不需要再写一遍空状态。
///
/// These widgets know no business logic; they only answer "what does loading look like"
/// and "what does empty look like", so a new tab never re-implements an empty state.
library;

import 'package:campus_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// 页面级加载指示 / a page-level loading indicator.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label});

  /// 可选文案，默认用 ARB 的 `stateLoading`。
  /// Optional label; defaults to ARB's `stateLoading`.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(height: 12),
          Text(
            label ?? l10n.stateLoading,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

/// 空状态 / an empty state.
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
    super.key,
  });

  /// 说明文案（必须来自 ARB）/ the message, always sourced from ARB.
  final String message;

  /// 图标 / the icon.
  final IconData icon;

  /// 可选操作按钮 / an optional action button.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 40, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (action != null) ...<Widget>[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// 错误 + 重试 / an error with a retry affordance.
class ErrorRetryView extends StatelessWidget {
  const ErrorRetryView({required this.onRetry, this.details, super.key});

  /// 重试回调 / the retry callback.
  final VoidCallback onRetry;

  /// 开发期可读的细节，展示在副标题里。/ developer-readable details.
  final String? details;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.error_outline, size: 40, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(l10n.stateError, style: theme.textTheme.titleMedium),
            if (details != null && details!.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                details!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onRetry,
              child: Text(l10n.actionRetry),
            ),
          ],
        ),
      ),
    );
  }
}

/// 首页/详情共用的分区标题 / a section header shared by Home and detail screens.
class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.title, this.trailing, super.key});

  /// 标题文案 / the section title.
  final String title;

  /// 右侧附加内容（例如计数）/ optional trailing content such as a count.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// 小徽标（分类 / 来源 / 状态）/ a small badge for category, provenance or status.
class TinyBadge extends StatelessWidget {
  const TinyBadge({required this.label, this.color, this.icon, super.key});

  /// 徽标文案 / the badge label.
  final String label;

  /// 主色，默认取主题的次级色 / the accent colour, defaulting to the theme's secondary.
  final Color? color;

  /// 可选前置图标 / an optional leading icon.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = color ?? theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 12, color: accent),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
