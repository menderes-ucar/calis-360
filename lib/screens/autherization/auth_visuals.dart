import 'package:flutter/material.dart';

class AuthVisuals {
  AuthVisuals._();

  static const primary = Color(0xFF1685C8);
  static const secondary = Color(0xFF6C55E0);
  static const ink = Color(0xFF172033);
  static const muted = Color(0xFF667085);
  static const border = Color(0xFFD7E1EA);
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
          decoration: BoxDecoration(
            color: Color(0xFFF7FAFC),
          ),
        ),
        Positioned(
          top: -110,
          left: -95,
          child: _GlowBlob(
            size: 280,
            color: AuthVisuals.primary.withValues(alpha: 0.13),
          ),
        ),
        Positioned(
          top: 90,
          right: -135,
          child: _GlowBlob(
            size: 310,
            color: AuthVisuals.secondary.withValues(alpha: 0.10),
          ),
        ),
        Positioned(
          bottom: -145,
          left: 55,
          child: _GlowBlob(
            size: 300,
            color: const Color(0xFF16A36A).withValues(alpha: 0.07),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AuthVisuals.border, width: 1.6),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF172033).withValues(alpha: 0.09),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: AuthVisuals.primary.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
          width: 66,
          height: 66,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1FA8E8), Color(0xFF6E62E8)],
            ),
            borderRadius: BorderRadius.circular(21),
            boxShadow: [
              BoxShadow(
                color: AuthVisuals.primary.withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 32),
        ),
        const SizedBox(height: 16),
        Text(
          'Çalış 360',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AuthVisuals.primary,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AuthVisuals.ink,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.7,
              ),
        ),
        const SizedBox(height: 7),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AuthVisuals.muted,
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F7FB),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AuthVisuals.primary.withValues(alpha: 0.14),
                width: 1.1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.$1, size: 15, color: AuthVisuals.primary),
                const SizedBox(width: 5),
                Text(
                  item.$2,
                  style: const TextStyle(
                    color: AuthVisuals.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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
