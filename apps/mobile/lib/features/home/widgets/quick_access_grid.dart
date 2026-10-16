/// 首页快捷入口网格 / Home's quick access grid (§12).
///
/// §12 把 Quick Access 写成一组高频服务入口（课表、校园卡、图书馆…）。
/// 通用 widget 不知道具体是哪几个——它只渲染传进来的服务列表，因此同一个组件对任何
/// 高校都成立。
///
/// §12 lists Quick Access as a small set of high-frequency entries. This widget knows
/// nothing about which ones they are; it renders whatever services it is handed, which
/// keeps it valid for any university.
library;

import 'package:campus_mobile/core/launcher/campus_launcher.dart';
import 'package:campus_mobile/core/text/localized_text.dart';
import 'package:campus_mobile/data/models/campus_service.dart';
import 'package:campus_mobile/data/repositories/campus_repository.dart';
import 'package:campus_mobile/features/home/widgets/service_card.dart';
import 'package:flutter/material.dart';

/// 快捷入口网格 / the quick access grid.
class QuickAccessGrid extends StatefulWidget {
  const QuickAccessGrid({
    required this.services,
    required this.repository,
    super.key,
  });

  /// 要展示的服务 / the services to show.
  final List<CampusService> services;

  /// 双语名称的来源 / where the bilingual names come from.
  ///
  /// 显式传入而不是自己去 widget 树里取：这个 widget 因此可以在测试里独立构造。
  /// Passed in rather than read from the tree, so the widget can be built in a test on
  /// its own.
  final CampusRepository repository;

  @override
  State<QuickAccessGrid> createState() => _QuickAccessGridState();
}

class _QuickAccessGridState extends State<QuickAccessGrid> {
  late Future<Map<String, LocalizedText>> _names;

  @override
  void initState() {
    super.initState();
    _names = widget.repository.fetchServiceNames();
  }

  @override
  void didUpdateWidget(covariant QuickAccessGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository ||
        !identical(oldWidget.services, widget.services)) {
      _names = widget.repository.fetchServiceNames();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, LocalizedText>>(
      // 双语名称来自 repository：远端模式回退到后端的中文名，演示模式自带英文。
      // Bilingual names come from the repository: remote falls back to the Chinese name,
      // demo data carries English.
      future: _names,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<Map<String, LocalizedText>> snapshot,
          ) {
            final Map<String, LocalizedText> names =
                snapshot.data ?? const <String, LocalizedText>{};
            final String languageCode = Localizations.localeOf(context)
                .languageCode;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.services.length,
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 320,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                mainAxisExtent: MediaQuery.textScalerOf(context).scale(52) + 24,
              ),
              itemBuilder: (BuildContext context, int index) {
                final CampusService service = widget.services[index];
                final LocalizedText? localized = names[service.id];
                final String label =
                    localized?.resolve(languageCode) ?? service.name;
                return ServiceCard(
                  service: service,
                  label: label,
                  onOpen: () =>
                      CampusLauncher.of(context)
                          .launch(context, service.launchTarget),
                );
              },
            );
          },
    );
  }
}
