import 'package:flutter/material.dart';

/// Shared visual language for the mobile dashboard and desktop workspace.
class WorkspaceBanner extends StatelessWidget {
  const WorkspaceBanner({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.actions = const [],
    this.vivid = false,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> actions;
  final bool vivid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 8),
          child: child,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: CustomPaint(
          foregroundPainter: vivid
              ? _OrbitPainter(colors.primary, colors.tertiary)
              : null,
          child: Container(
            padding: EdgeInsets.all(
              MediaQuery.sizeOf(context).height < 600 ? 14 : 20,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: .6),
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  vivid
                      ? Color.alphaBlend(
                          colors.primaryContainer.withValues(alpha: .55),
                          colors.surface,
                        )
                      : colors.surface,
                  Color.alphaBlend(
                    colors.secondaryContainer.withValues(alpha: .35),
                    colors.surface,
                  ),
                ],
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eyebrow,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.primary,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      if (actions.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Wrap(spacing: 8, runSpacing: 8, children: actions),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.primaryContainer.withValues(alpha: .5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(icon, color: colors.primary, size: 28),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Static geometry gets repainted only when the theme changes.
class _OrbitPainter extends CustomPainter {
  const _OrbitPainter(this.primary, this.secondary);
  final Color primary, secondary;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final center = Offset(size.width + 18, size.height + 30);
    final radius = size.height * .95;
    final paint = Paint()
      ..color = secondary.withValues(alpha: .13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final factor in [.65, 1.0, 1.35]) {
      canvas.drawCircle(center, radius * factor, paint);
    }
    final halo = Paint()
      ..shader = RadialGradient(
        colors: [primary.withValues(alpha: .12), primary.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.8));
    canvas.drawCircle(center, radius * 1.8, halo);
    for (var i = 0; i < 5; i++) {
      canvas.drawCircle(
        Offset(size.width - 18 - i * 13, size.height - 15),
        1.5,
        Paint()..color = primary.withValues(alpha: .25),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OrbitPainter oldDelegate) =>
      oldDelegate.primary != primary || oldDelegate.secondary != secondary;
}

/// A real action, with one shared hover/focus treatment across entry points.
class WorkspaceAction extends StatefulWidget {
  const WorkspaceAction({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.color,
    this.selected = false,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final bool selected;

  @override
  State<WorkspaceAction> createState() => _WorkspaceActionState();
}

class _WorkspaceActionState extends State<WorkspaceAction> {
  bool _hovered = false, _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = widget.color ?? theme.colorScheme.primary;
    final highlighted = _hovered || _focused || widget.selected;
    return AnimatedContainer(
      transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          accent.withValues(alpha: highlighted ? .09 : .035),
          theme.colorScheme.surface,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlighted
              ? accent.withValues(alpha: .65)
              : theme.colorScheme.outlineVariant.withValues(alpha: .6),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onHover: (value) => setState(() => _hovered = value),
          onFocusChange: (value) => setState(() => _focused = value),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: accent.withValues(alpha: .12),
                  foregroundColor: accent,
                  child: Icon(widget.icon),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title, style: theme.textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(
                        widget.subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Semantics(
                  selected: widget.selected ? true : null,
                  child: Icon(
                    widget.selected
                        ? Icons.radio_button_checked
                        : Icons.arrow_forward_rounded,
                    size: 18,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A measured value with a label; callers supply actual record counts.
class WorkspaceMetric extends StatelessWidget {
  const WorkspaceMetric({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    this.color,
  });
  final String value, label;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = color ?? theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          accent.withValues(alpha: .06),
          theme.colorScheme.surface,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: .14)),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(color: accent),
                ),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class WorkspacePanel extends StatelessWidget {
  const WorkspacePanel({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.count,
  });
  final String title;
  final IconData icon;
  final Widget child;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .65)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 19, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (count != null)
                  Text(
                    '$count',
                    style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Wrap rather than a nested scroll view; supports large text and short windows.
class WorkspaceGrid extends StatelessWidget {
  const WorkspaceGrid({super.key, required this.children, this.minWidth = 290});
  final List<Widget> children;
  final double minWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = (constraints.maxWidth / minWidth).floor().clamp(
        1,
        children.length.clamp(1, 3),
      );
      final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}
