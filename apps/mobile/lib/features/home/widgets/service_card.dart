/// 网格中的一个服务入口 / one service entry inside the quick access grid.
library;

import 'package:campus_mobile/data/models/campus_service.dart';
import 'package:campus_mobile/data/models/service_enums.dart';
import 'package:flutter/material.dart';

/// 紧凑的服务卡片 / a compact service card.
class ServiceCard extends StatelessWidget {
  const ServiceCard({
    required this.service,
    required this.label,
    required this.onOpen,
    super.key,
  });

  /// 服务 / the service.
  final CampusService service;

  /// 已按当前语言解析好的名称 / the name already resolved for the current language.
  final String label;

  /// 打开回调 / the open callback.
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _iconFor(service),
                  size: 20,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 用分类挑图标：通用 widget 只依赖分类，不依赖具体是哪所学校。
  /// Icons keyed by category: the shared widget depends on a category, never on a
  /// specific school.
  static IconData _iconFor(CampusService service) {
    switch (service.category) {
      case ServiceCategory.officialHub:
        return Icons.hub_outlined;
      case ServiceCategory.academic:
        return Icons.menu_book_outlined;
      case ServiceCategory.library:
        return Icons.local_library_outlined;
      case ServiceCategory.campusCard:
        return Icons.credit_card_outlined;
      case ServiceCategory.venue:
        return Icons.sports_tennis_outlined;
      case ServiceCategory.network:
        return Icons.wifi_outlined;
      case ServiceCategory.map:
        return Icons.map_outlined;
      case ServiceCategory.administration:
        return Icons.assignment_outlined;
      case ServiceCategory.other:
        return Icons.apps_outlined;
    }
  }
}
