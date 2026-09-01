import 'package:flutter/material.dart';

import '../../theme/theme.dart';

class AuthVisuals {
  AuthVisuals._();

  static const primary = AppTheme.burgundy;
  static const secondary = AppTheme.forest;
  static const ink = AppTheme.ink;
  static const muted = AppTheme.inkSoft;
  static const border = AppTheme.border;
}

class AuthBackground extends StatelessWidget {
  const AuthBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(color: AppTheme.ivory),
        ),
        Positioned(
          top: -125,
          left: -110,
          child: _GlowBlob(
            size: 290,
            color: AppTheme.burgundy.withValues(alpha: .09),
          ),
        ),
        Positioned(
          top: 90,
          right: -140,
          child: _GlowBlob(
            size: 320,
            color: AppTheme.forest.withValues(alpha: .10),
          ),
        ),
        SafeArea(child: child),
      ],
    );
  }
}

class AuthCard extends StatelessWidget {
  const AuthCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.border, width: 1.3),
        boxShadow: [
          BoxShadow(
            color: AppTheme.burgundy.withValues(alpha: .09),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

class AuthBrand extends StatelessWidget {
  const AuthBrand({
    required this.title,
    required this.subtitle,
    this.icon = Icons.school_rounded,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: AppTheme.forest,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppTheme.burgundy.withValues(alpha: .22),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.forest.withValues(alpha: .18),
                blurRadius: 20,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Icon(icon, color: AppTheme.ivory, size: 32),
        ),
        const SizedBox(height: 16),
        Text(
          'Çalış 360',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.burgundy,
                fontWeight: FontWeight.w900,
                letterSpacing: .2,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppTheme.ink,
                fontWeight: FontWeight.w900,
                letterSpacing: -.7,
              ),
        ),
        const SizedBox(height: 7),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.inkSoft,
                height: 1.4,
              ),
        ),
      ],
    );
  }
}

class AuthFeaturePills extends StatelessWidget {
  const AuthFeaturePills({super.key});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.bolt_rounded, 'AI Çözüm'),
      (Icons.insights_rounded, 'Analiz'),
      (Icons.calendar_month_rounded, 'Plan'),
    ];

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceStrong,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppTheme.border, width: 1.1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.$1, size: 15, color: AppTheme.forest),
                const SizedBox(width: 5),
                Text(
                  item.$2,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
