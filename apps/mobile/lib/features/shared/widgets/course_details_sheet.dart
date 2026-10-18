/// 课程详情弹层 / the course details sheet (§9).
///
/// §9 把教学周当成一等概念（单双周、自定义周、调课都建立在它之上），因此详情里显式
/// 展示起止周，而不是只显示"上课时间"。
///
/// §9 treats teaching weeks as a first-class concept (odd/even weeks, custom weeks and
/// schedule changes all build on it), so the sheet shows the week range explicitly rather
/// than just a time slot.
library;

import 'package:campus_mobile/data/models/course.dart';
import 'package:campus_mobile/features/shared/widgets/state_views.dart';
import 'package:campus_mobile/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// 打开课程详情 / open the course details sheet.
Future<void> showCourseDetails(BuildContext context, {required Course course}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) => _CourseDetailsSheet(course: course),
  );
}

class _CourseDetailsSheet extends StatelessWidget {
  const _CourseDetailsSheet({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                course.name,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  TinyBadge(
                    label: l10n.searchSectionCourses,
                    color: theme.colorScheme.primary,
                    icon: Icons.school_outlined,
                  ),
                  if (course.scheduleRule != null)
                    TinyBadge(label: course.scheduleRule!),
                ],
              ),
              const SizedBox(height: 12),
              if (course.teacher.isNotEmpty)
                _row(context, l10n.courseTeacherLabel, course.teacher),
              if (course.location.isNotEmpty)
                _row(context, l10n.inboxLocationLabel, course.location),
              _row(
                context,
                l10n.courseWeeksLabel,
                l10n.courseWeeksRange(course.startWeek, course.endWeek),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _row(BuildContext context, String label, String value) {
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
