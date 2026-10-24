import 'dart:ui';
import 'package:flutter/material.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/models/category.dart';
import '../../domain/models/reminder.dart';
import '../state/app_controller.dart';
import '../theme/glass_theme.dart';

class GlassScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final ThemeSettings themeSettings;

  const GlassScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
    required this.themeSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: GlassTheme.backgroundDecoration(
        context: context,
        settings: themeSettings,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: appBar,
        body: SafeArea(child: body),
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: bottomNavigationBar,
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Gradient? gradient;
  final double borderRadius;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.borderColor,
    this.gradient,
    this.borderRadius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBorder = borderColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.15)
            : Theme.of(context).colorScheme.primary.withValues(alpha: 0.20));
    final defaultGradient = gradient ??
        LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? <Color>[
                  Colors.white.withValues(alpha: 0.11),
                  Colors.white.withValues(alpha: 0.05),
                ]
              : <Color>[
                  Colors.white.withValues(alpha: 0.88),
                  Colors.white.withValues(alpha: 0.72),
                ],
        );

    final content = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(borderRadius),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                gradient: defaultGradient,
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(color: defaultBorder, width: 1.1),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );

    if (margin != null) {
      return Padding(padding: margin!, child: content);
    }
    return content;
  }
}

class PriorityBadge extends StatelessWidget {
  final ReminderPriority priority;

  const PriorityBadge({super.key, required this.priority});

  Color _colorForPriority() {
    switch (priority) {
      case ReminderPriority.low:
        return const Color(0xFF38BDF8);
      case ReminderPriority.medium:
        return const Color(0xFF10B981);
      case ReminderPriority.high:
        return const Color(0xFFF59E0B);
      case ReminderPriority.critical:
        return const Color(0xFFEF4444);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForPriority();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.flag_rounded, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            priority.label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class CategoryPill extends StatelessWidget {
  final ReminderCategory category;

  const CategoryPill({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final color = category.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(category.icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            category.name,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class TierStatusBadge extends StatelessWidget {
  final bool isPremium;
  final VoidCallback? onTap;

  const TierStatusBadge({
    super.key,
    required this.isPremium,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        isPremium ? const Color(0xFFF59E0B) : Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isPremium
                ? const <Color>[Color(0xFFF59E0B), Color(0xFFEC4899)]
                : <Color>[
                    color.withValues(alpha: 0.25),
                    color.withValues(alpha: 0.15),
                  ],
          ),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isPremium
                ? Colors.amberAccent.withValues(alpha: 0.8)
                : color.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              isPremium ? Icons.workspace_premium : Icons.lock_open_rounded,
              size: 15,
              color: isPremium ? Colors.white : color,
            ),
            const SizedBox(width: 5),
            Text(
              isPremium ? 'PRO ACTIVE' : 'FREE TIER',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: isPremium ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyStateGlassCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyStateGlassCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: primary),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.72),
                ),
          ),
          if (actionLabel != null && onAction != null) ...<Widget>[
            const SizedBox(height: 14),
            FilledButton.tonalIcon(
              onPressed: onAction,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class SafeTestAdBannerWidget extends StatelessWidget {
  final AppController controller;
  final VoidCallback onUpgradeTap;

  const SafeTestAdBannerWidget({
    super.key,
    required this.controller,
    required this.onUpgradeTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = controller.advertisingService.resolveBannerStatus(
      config: controller.adConfig,
      isPremiumActive: controller.isPremiumActive,
    );
    if (!status.visible) {
      return const SizedBox.shrink();
    }

    return GlassCard(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.6)),
            ),
            child: const Text(
              'AD • TEST',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.amber,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${status.networkLabel} — Safe Test Placement',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Unit: ${status.unitIdentifier}',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.65),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onUpgradeTap,
            child: const Text('Remove Ads'),
          ),
        ],
      ),
    );
  }
}
