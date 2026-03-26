import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

String rubles(int value) => '$value \u20BD';

bool useCompactLayout(BuildContext context) {
  final mediaQuery = MediaQuery.maybeOf(context);
  if (mediaQuery == null) {
    return false;
  }

  return mediaQuery.size.width < 700 || mediaQuery.size.shortestSide < 700;
}

bool useReducedEffects(BuildContext context) {
  final mediaQuery = MediaQuery.maybeOf(context);
  if (mediaQuery == null) {
    return kIsWeb;
  }

  return mediaQuery.disableAnimations || useCompactLayout(context);
}

bool useHoverEffects(BuildContext context) => !useCompactLayout(context);

Duration motionDuration(
  BuildContext context,
  Duration regular, {
  Duration reduced = const Duration(milliseconds: 110),
}) => useReducedEffects(context) ? reduced : regular;

Color parseHexColor(String hex) {
  final clean = hex.replaceAll('#', '');
  final normalized = clean.length == 6 ? 'FF$clean' : clean;
  return Color(int.parse(normalized, radix: 16));
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final reducedEffects = useReducedEffects(context);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.07),
            Colors.white.withValues(alpha: 0.03),
          ],
        ),
        border: Border.all(
          color: borderColor ?? AppPalette.peach.withValues(alpha: 0.14),
        ),
        boxShadow: reducedEffects
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 16,
                  offset: const Offset(0, 10),
                ),
              ]
            : [
                BoxShadow(
                  color: AppPalette.rose.withValues(alpha: 0.08),
                  blurRadius: 36,
                  offset: const Offset(0, 22),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 32,
                  offset: const Offset(0, 24),
                ),
              ],
      ),
      child: child,
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow.toUpperCase(),
                style: const TextStyle(
                  color: AppPalette.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class MetricChip extends StatelessWidget {
  const MetricChip({
    super.key,
    required this.label,
    required this.value,
    this.color = AppPalette.rose,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.64),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
        ],
      ),
    );
  }
}

class EmptyStatePanel extends StatelessWidget {
  const EmptyStatePanel({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.auto_awesome_rounded,
    this.action,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppPalette.rose.withValues(alpha: 0.26),
                  AppPalette.gold.withValues(alpha: 0.16),
                ],
              ),
            ),
            child: Icon(icon, color: AppPalette.text, size: 30),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.64),
              height: 1.5,
            ),
          ),
          if (action != null) const SizedBox(height: 18),
          ?action,
        ],
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: Colors.black.withValues(alpha: 0.76),
    builder: (context) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: builder(context),
        ),
      );
    },
  );
}

Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool useSafeArea = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.76),
    builder: builder,
  );
}

class AppSheetShell extends StatelessWidget {
  const AppSheetShell({
    super.key,
    required this.child,
    this.accentColor = AppPalette.rose,
    this.padding = const EdgeInsets.all(20),
    this.showHandle = true,
  });

  final Widget child;
  final Color accentColor;
  final EdgeInsetsGeometry padding;
  final bool showHandle;

  @override
  Widget build(BuildContext context) {
    final compact = useCompactLayout(context);
    final shellTint = Color.lerp(AppPalette.panelStrong, accentColor, 0.10)!;

    return GlassPanel(
      padding: EdgeInsets.zero,
      borderColor: accentColor.withValues(alpha: 0.18),
      child: Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              shellTint.withValues(alpha: compact ? 0.98 : 0.95),
              AppPalette.panel.withValues(alpha: compact ? 0.97 : 0.93),
            ],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHandle) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class AppDialogShell extends StatelessWidget {
  const AppDialogShell({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.child,
    this.subtitle,
    this.icon,
    this.accentColor = AppPalette.rose,
    this.actions = const [],
    this.padding = const EdgeInsets.all(22),
  });

  final String eyebrow;
  final String title;
  final String? subtitle;
  final Widget child;
  final IconData? icon;
  final Color accentColor;
  final List<Widget> actions;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final compact = useCompactLayout(context);
    final shellTint = Color.lerp(AppPalette.panelStrong, accentColor, 0.10)!;

    return GlassPanel(
      padding: EdgeInsets.zero,
      borderColor: accentColor.withValues(alpha: 0.18),
      child: Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              shellTint.withValues(alpha: compact ? 0.98 : 0.95),
              AppPalette.panel.withValues(alpha: compact ? 0.97 : 0.93),
            ],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(alpha: 0.12),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.24),
                  ),
                ),
                child: Icon(icon, color: accentColor),
              ),
              const SizedBox(height: 16),
            ],
            SectionHeading(eyebrow: eyebrow, title: title, subtitle: subtitle),
            const SizedBox(height: 18),
            child,
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 20),
              AppDialogActions(children: actions),
            ],
          ],
        ),
      ),
    );
  }
}

class AppDialogActions extends StatelessWidget {
  const AppDialogActions({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 12,
      runSpacing: 12,
      children: children,
    );
  }
}

class LoadingStatePanel extends StatelessWidget {
  const LoadingStatePanel({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.accentColor = AppPalette.rose,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.6,
                color: accentColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SectionHeading(
                eyebrow: eyebrow,
                title: title,
                subtitle: subtitle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const SkeletonLines(widths: [1.0, 0.86, 0.72]),
      ],
    );
  }
}

class SkeletonLines extends StatelessWidget {
  const SkeletonLines({
    super.key,
    required this.widths,
    this.height = 12,
    this.spacing = 10,
  });

  final List<double> widths;
  final double height;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < widths.length; index += 1) ...[
          FractionallySizedBox(
            widthFactor: widths[index],
            alignment: Alignment.centerLeft,
            child: SkeletonBar(height: height),
          ),
          if (index != widths.length - 1) SizedBox(height: spacing),
        ],
      ],
    );
  }
}

class SkeletonBar extends StatefulWidget {
  const SkeletonBar({super.key, this.height = 12, this.radius = 999});

  final double height;
  final double radius;

  @override
  State<SkeletonBar> createState() => _SkeletonBarState();
}

class _SkeletonBarState extends State<SkeletonBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (useReducedEffects(context)) {
      _controller.stop();
      _controller.value = 0.45;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.34,
        end: 0.82,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.08),
              Colors.white.withValues(alpha: 0.16),
              Colors.white.withValues(alpha: 0.08),
            ],
          ),
        ),
      ),
    );
  }
}

class RevealOnMount extends StatefulWidget {
  const RevealOnMount({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = const Offset(0, 18),
  });

  final Widget child;
  final Duration delay;
  final Offset offset;

  @override
  State<RevealOnMount> createState() => _RevealOnMountState();
}

class _RevealOnMountState extends State<RevealOnMount>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: widget.offset / 100,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    Future<void>.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (useReducedEffects(context)) {
      return RepaintBoundary(child: widget.child);
    }

    return FadeTransition(
      opacity: _fade,
      child: RepaintBoundary(
        child: SlideTransition(position: _slide, child: widget.child),
      ),
    );
  }
}

class HoverLift extends StatefulWidget {
  const HoverLift({
    super.key,
    required this.child,
    this.scale = 1.015,
    this.hoverOffset = 8,
    this.duration = const Duration(milliseconds: 180),
  });

  final Widget child;
  final double scale;
  final double hoverOffset;
  final Duration duration;

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    if (!useHoverEffects(context)) {
      return RepaintBoundary(child: widget.child);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: RepaintBoundary(
        child: AnimatedScale(
          scale: _hovered ? widget.scale : 1,
          duration: widget.duration,
          curve: Curves.easeOutCubic,
          child: AnimatedSlide(
            offset: _hovered
                ? Offset(0, -widget.hoverOffset / 100)
                : Offset.zero,
            duration: widget.duration,
            curve: Curves.easeOutCubic,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
