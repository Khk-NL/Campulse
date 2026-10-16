/// 首页内容分区 / a Home content section.
///
/// 每个分区自己处理加载态、错误态与空态，因此某一分区出问题不会影响其它分区——
/// §12 的首页有四块内容，整页一起失败是不能接受的。
///
/// Every section owns its loading, error and empty states, so one failing section cannot
/// take down the others — §12's home has four blocks, and a page-wide failure there is
/// not acceptable.
library;

import 'package:campus_mobile/features/shared/widgets/state_views.dart';
import 'package:flutter/material.dart';

/// 带标题的一张卡片 / a titled card holding one section.
class HomeSection<T> extends StatelessWidget {
  const HomeSection({
    required this.title,
    required this.icon,
    required this.future,
    required this.emptyMessage,
    required this.builder,
    this.trailing,
    super.key,
  });

  /// 分区标题 / the section title.
  final String title;

  /// 分区图标 / the section icon.
  final IconData icon;

  /// 分区数据 / the section's data.
  final Future<T> future;

  /// 数据为空时的提示 / the message shown when the data is empty.
  final String emptyMessage;

  /// 渲染成功数据 / renders the loaded data.
  final Widget Function(BuildContext context, T value) builder;

  /// 标题右侧附加内容 / optional trailing content beside the title.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SectionHeader(
              title: title,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ?trailing,
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: theme.colorScheme.tertiaryContainer,
                    foregroundColor: theme.colorScheme.onTertiaryContainer,
                    child: Icon(icon, size: 18),
                  ),
                ],
              ),
            ),
            FutureBuilder<T>(
              future: future,
              builder: (BuildContext context, AsyncSnapshot<T> snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: LoadingView(),
                  );
                }
                if (snapshot.hasError) {
                  return _InlineError(message: snapshot.error.toString());
                }
                final T? value = snapshot.data;
                if (value == null) {
                  return _InlineEmpty(message: emptyMessage);
                }
                final Widget content = builder(context, value);
                // 分区内容为空时，由 builder 返回零尺寸；这里给一个显式空态更友好。
                // When the builder renders nothing we show the empty message instead.
                return _maybeEmpty(content, emptyMessage);
              },
            ),
          ],
        ),
      ),
    );
  }

  static Widget _maybeEmpty(Widget content, String message) {
    if (content is SizedBox &&
        content.width == null &&
        content.height == null) {
      return _InlineEmpty(message: message);
    }
    return content;
  }
}

/// 分区内的空态 / an in-section empty state.
class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// 分区内的错误态 / an in-section error state.
///
/// 分区粒度下不给重试按钮：整页顶部已经有下拉刷新与离线横幅，这里只需说明情况。
/// No retry button at section granularity: pull-to-refresh and the offline banner
/// already cover that, so this only needs to explain itself.
class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.error_outline, size: 16, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
