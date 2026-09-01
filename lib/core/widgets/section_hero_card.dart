import 'package:flutter/material.dart';

import '../../theme/theme.dart';

class SectionHeroCard extends StatelessWidget {
  const SectionHeroCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.forest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.burgundy.withValues(alpha: .28),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.forest.withValues(alpha: .16),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.ivory.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.ivory.withValues(alpha: .22),
                width: 1.1,
              ),
            ),
            child: Icon(icon, color: AppTheme.ivory, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.ivory,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.35,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.ivory.withValues(alpha: .82),
                        height: 1.4,
                      ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing!,
          ],
        ],
      ),
    );
  }
}
