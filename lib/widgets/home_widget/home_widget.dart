import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../features/content/presentation/providers/content_providers.dart';
import 'home_card_style.dart';

const bannerItems = [
  'Türkçe',
  'Matematik',
  'Tarih',
  'Coğrafya',
  'Felsefe',
  'Din',
  'Fizik',
  'Kimya',
  'Biyoloji',
];

const bannerImage = [
  'images/turkce.jpg',
  'images/matematik.jpg',
  'images/tarih.jpg',
  'images/cografya.jpg',
  'images/felsefe.jpg',
  'images/din.jpg',
  'images/fizik.jpg',
  'images/kimya.jpg',
  'images/biyoloji.jpg',
];

class BannerWidgetArea extends ConsumerWidget {
  const BannerWidgetArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = ref.watch(subjectsProvider).valueOrNull ?? const [];
    final theme = Theme.of(context);

    return SizedBox(
      height: 184,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: bannerItems.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final name = bannerItems[index];
          final normalized = _normalize(name);
          final matches = subjects.where(
            (subject) => _normalize(subject.name) == normalized,
          );
          final subject = matches.isEmpty ? null : matches.first;

          return SizedBox(
            width: 158,
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: HomeCardStyle.borderColor,
                  width: HomeCardStyle.borderWidth,
                ),
                boxShadow: HomeCardStyle.shadows(
                  accent: theme.colorScheme.primary,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    if (subject == null) {
                      context.push(AppRoutes.content);
                      return;
                    }
                    context.push(
                      AppRoutes.contentUnitsPath(subject.id),
                      extra: subject.name,
                    );
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(bannerImage[index], fit: BoxFit.cover),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x08000000), Color(0xD9000000)],
                            stops: [0.25, 1],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 14,
                        right: 12,
                        bottom: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            const Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Konu özetlerini aç',
                                    style: TextStyle(
                                      color: Color(0xFFE7E7E7),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c');
  }
}
