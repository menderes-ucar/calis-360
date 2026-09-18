import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/billing_models.dart';
import '../providers/billing_providers.dart';

class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({super.key});

  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(billingControllerProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<BillingState>(billingControllerProvider, (previous, next) {
      final message = next.error ?? next.message;
      final previousMessage = previous?.error ?? previous?.message;
      if (message == null || message == previousMessage || !mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));

      ref.read(billingControllerProvider.notifier).clearFeedback();
    });

    final state = ref.watch(billingControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Premium & Krediler'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: state.loading
                ? null
                : () =>
                      ref.read(billingControllerProvider.notifier).initialize(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(billingControllerProvider.notifier).initialize(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            if (state.loading) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
            ],
            const _BillingHero(),
            const SizedBox(height: 14),
            _StatusCard(status: state.status),
            const SizedBox(height: 16),
            if (!storePurchasesEnabled)
              Card(
                color: theme.colorScheme.secondaryContainer,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.verified_user_outlined),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Mağaza ürünleri ve fiyatlar okunuyor. Gerçek ödeme, Google Play / App Store makbuz doğrulaması backend tarafında tamamlandıktan sonra açılacak. Bu aşamada kullanıcıdan para çekilmez.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            const _PremiumBenefitsCard(),
            const SizedBox(height: 20),
            Text(
              'Premium Planlar',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            ...state.products
                .where(
                  (item) =>
                      item.catalogProduct.type ==
                      BillingProductType.subscription,
                )
                .map((item) => _ProductCard(item: item)),
            if (state.products
                .where(
                  (item) =>
                      item.catalogProduct.type ==
                      BillingProductType.subscription,
                )
                .isEmpty)
              const _EmptyProductsCard(
                label: 'Premium mağaza ürünleri henüz bulunamadı.',
              ),
            const SizedBox(height: 20),
            Text(
              'AI Kredi Paketleri',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            ...state.products
                .where(
                  (item) =>
                      item.catalogProduct.type == BillingProductType.credits,
                )
                .map((item) => _ProductCard(item: item)),
            if (state.products
                .where(
                  (item) =>
                      item.catalogProduct.type == BillingProductType.credits,
                )
                .isEmpty)
              const _EmptyProductsCard(
                label: 'Kredi paketleri mağazada henüz bulunamadı.',
              ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: state.storeAvailable
                  ? () => ref
                        .read(billingControllerProvider.notifier)
                        .restorePurchases()
                  : null,
              icon: const Icon(Icons.restore_rounded),
              label: const Text('Satın Almaları Geri Yükle'),
            ),
            if (!state.storeAvailable) ...[
              const SizedBox(height: 12),
              const Text(
                'Google Play / App Store bağlantısı bu cihazda kullanılamıyor. Ürünleri test etmek için mağazaya bağlı gerçek veya uygun test cihazı kullanın.',
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}


class _BillingHero extends StatelessWidget {
  const _BillingHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A1F2C), Color(0xFF1F4A3D)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x241685C8),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: const Row(
        children: [
          _HeroIcon(),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daha fazla çalışma gücü',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Premium avantajlarını ve AI kredi bakiyeni tek ekrandan yönet.',
                  style: TextStyle(color: Color(0xE6FFFFFF), height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroIcon extends StatelessWidget {
  const _HeroIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 29),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});

  final BillingStatus? status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subscription = status?.subscription;
    final premium = subscription?.active == true;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFD6C5BB), width: 1.7),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: premium
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHighest,
                  child: Icon(
                    premium
                        ? Icons.workspace_premium_rounded
                        : Icons.person_outline_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        premium ? 'Premium aktif' : 'Ücretsiz plan',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Plan: ${(subscription?.plan ?? 'free').toUpperCase()}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                Chip(
                  avatar: const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: Text('AI kredisi: ${status?.creditBalance ?? 0}'),
                ),
                Chip(
                  avatar: const Icon(Icons.verified_outlined, size: 18),
                  label: Text(
                    'Durum: ${(subscription?.status ?? 'inactive').toUpperCase()}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  const _ProductCard({required this.item});

  final BillingStoreProduct item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final catalog = item.catalogProduct;
    final product = item.storeProduct;
    final isSubscription = catalog.type == BillingProductType.subscription;

    final title = isSubscription
        ? (catalog.period == 'P1Y' ? 'Premium Yıllık' : 'Premium Aylık')
        : '${catalog.credits ?? 0} AI Kredisi';

    final subtitle = isSubscription
        ? (catalog.period == 'P1Y'
              ? '12 aylık Premium erişim.'
              : 'Aylık Premium erişim.')
        : 'AI soru çözümünde kullanılacak ${catalog.credits ?? 0} ek kredi.';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFD6C5BB), width: 1.7),
      ),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isSubscription
                    ? Icons.workspace_premium_rounded
                    : Icons.bolt_rounded,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle),
                  const SizedBox(height: 5),
                  Text(
                    product.price,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () =>
                  ref.read(billingControllerProvider.notifier).buy(item),
              child: Text(storePurchasesEnabled ? 'Satın Al' : 'Hazır'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyProductsCard extends StatelessWidget {
  const _EmptyProductsCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFD6C5BB), width: 1.7),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.storefront_outlined),
            const SizedBox(width: 12),
            Expanded(child: Text(label)),
          ],
        ),
      ),
    );
  }
}

class _PremiumBenefitsCard extends StatelessWidget {
  const _PremiumBenefitsCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const benefits = <(IconData, String, String)>[
      (
        Icons.auto_awesome_rounded,
        'Günde 25 AI soru çözümü',
        'Premium günlük hakkın kredi harcamadan kullanılır.',
      ),
      (
        Icons.headphones_rounded,
        'Sınırsız ders dinleme',
        'Aboneliğin aktif olduğu sürece sesli dersleri tekrar tekrar dinle.',
      ),
      (
        Icons.insights_rounded,
        'Gelişmiş Analiz Merkezi',
        'Ders, konu, sınav, yanlış soru, hedef ve çalışma verilerini birlikte incele.',
      ),
      (
        Icons.bolt_rounded,
        'Kredi avantajı',
        'Ücretsiz planda AI çözümü 10 kredi, ders dinleme 3 kredidir.',
      ),
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFD6C5BB), width: 1.7),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.workspace_premium_rounded,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Premium ayrıcalıkları',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Daha fazla AI, sınırsız sesli ders ve ayrıntılı gelişim analizi.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            for (final benefit in benefits) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(benefit.$1, size: 21),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          benefit.$2,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          benefit.$3,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (benefit != benefits.last) const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }
}
