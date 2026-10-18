import 'package:campus_mobile/features/apps/apps_page.dart';
import 'package:campus_mobile/features/community/community_page.dart';
import 'package:campus_mobile/features/study/course_hub_page.dart';
import 'package:flutter/material.dart';

/// Campus utilities support the project community from one secondary workspace.
class CampusPage extends StatefulWidget {
  const CampusPage({super.key, this.active = true, this.refreshToken = 0});
  final bool active;
  final int refreshToken;

  @override
  State<CampusPage> createState() => _CampusPageState();
}

class _CampusPageState extends State<CampusPage> {
  int _tab = 0;
  final _visited = <int>{0};

  @override
  Widget build(BuildContext context) {
    final english = Localizations.localeOf(context).languageCode == 'en';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (index, zh, en, icon) in [
                  (
                    0,
                    '课程与课表',
                    'Courses & timetable',
                    Icons.calendar_month_outlined,
                  ),
                  (1, '快速访问', 'Quick access', Icons.apps_outlined),
                  (2, '校园广场', 'Campus square', Icons.groups_outlined),
                ])
                  ChoiceChip(
                    showCheckmark: false,
                    selected: _tab == index,
                    avatar: Icon(icon, size: 18),
                    label: Text(english ? en : zh),
                    onSelected: (_) => setState(() {
                      _tab = index;
                      _visited.add(index);
                    }),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _tab,
            children: [
              CourseHubPage(
                active: widget.active && _tab == 0,
                refreshToken: widget.refreshToken,
              ),
              if (_visited.contains(1))
                AppsPage(
                  quickAccessOnly: true,
                  refreshToken: widget.refreshToken,
                )
              else
                const SizedBox.shrink(),
              if (_visited.contains(2))
                CommunityPage(refreshToken: widget.refreshToken)
              else
                const SizedBox.shrink(),
            ],
          ),
        ),
      ],
    );
  }
}
