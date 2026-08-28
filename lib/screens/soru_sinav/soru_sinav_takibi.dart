import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/errors/auth_error_mapper.dart';
import '../../core/errors/data_error_mapper.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/study_data/presentation/providers/study_data_providers.dart';
import '../../models/sinav.dart';
import '../../models/soru.dart';
import 'sinav_ekle.dart';
import 'soru_ekle.dart';

class SoruSinavTakibi extends ConsumerStatefulWidget {
  const SoruSinavTakibi({super.key});

  @override
  ConsumerState<SoruSinavTakibi> createState() => _SoruSinavTakibiState();
}

class _SoruSinavTakibiState extends ConsumerState<SoruSinavTakibi> {
  double _averageForType(List<Sinav> sinavlar, String type) {
    final totals = sinavlar
        .where((sinav) => sinav.sinavTuru.trim().toUpperCase() == type)
        .map(
          (sinav) =>
              sinav.netler.values.fold<double>(0, (sum, value) => sum + value),
        )
        .toList();

    if (totals.isEmpty) return 0;
    return totals.fold<double>(0, (sum, value) => sum + value) / totals.length;
  }

  Future<void> _showUpdateSoruDialog(BuildContext context, Soru soru) async {
    final adController = TextEditingController(text: soru.soruAd);
    final dersController = TextEditingController(text: soru.soruDers);
    final konuController = TextEditingController(text: soru.soruKonu);
    final cevapController = TextEditingController(text: soru.soruCevap);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Soruyu Güncelle'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: adController,
                decoration: const InputDecoration(labelText: 'Soru Adı'),
              ),
              TextField(
                controller: dersController,
                decoration: const InputDecoration(labelText: 'Ders'),
              ),
              TextField(
                controller: konuController,
                decoration: const InputDecoration(labelText: 'Konu'),
              ),
              TextField(
                controller: cevapController,
                decoration: const InputDecoration(labelText: 'Cevap'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updated = Soru(
                soruId: soru.soruId,
                soruAd: adController.text.trim(),
                soruDers: dersController.text.trim(),
                soruKonu: konuController.text.trim(),
                soruCevap: cevapController.text.trim(),
                soruDurum: soru.soruDurum,
                source: soru.source,
                aiRequestId: soru.aiRequestId,
                createdAt: soru.createdAt,
                updatedAt: soru.updatedAt,
              );
              try {
                await ref.read(soruRepositoryProvider).updateSoru(updated);
                if (!dialogContext.mounted || !context.mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Soru başarıyla güncellendi')),
                );
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(DataErrorMapper.message(error))),
                );
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );

    adController.dispose();
    dersController.dispose();
    konuController.dispose();
    cevapController.dispose();
  }

  Future<void> _showUpdateSinavDialog(BuildContext context, Sinav sinav) async {
    final adController = TextEditingController(text: sinav.sinavAd);
    final turuController = TextEditingController(text: sinav.sinavTuru);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sınavı Güncelle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: adController,
              decoration: const InputDecoration(labelText: 'Sınav Adı'),
            ),
            TextField(
              controller: turuController,
              decoration: const InputDecoration(labelText: 'Türü'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updated = Sinav(
                sinavId: sinav.sinavId,
                sinavAd: adController.text.trim(),
                sinavTuru: turuController.text.trim(),
                netler: sinav.netler,
                sinavBrans: sinav.sinavBrans,
                dersDetaylari: sinav.dersDetaylari,
                createdAt: sinav.createdAt,
                updatedAt: sinav.updatedAt,
              );
              try {
                await ref.read(sinavRepositoryProvider).updateSinav(updated);
                if (!dialogContext.mounted || !context.mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sınav başarıyla güncellendi')),
                );
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(DataErrorMapper.message(error))),
                );
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );

    adController.dispose();
    turuController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sorularAsync = ref.watch(sorularProvider);
    final sinavlarAsync = ref.watch(sinavlarProvider);
    final sorular = sorularAsync.valueOrNull ?? const <Soru>[];
    final sinavlar = sinavlarAsync.valueOrNull ?? const <Sinav>[];
    final tytOrtalama = _averageForType(sinavlar, 'TYT');
    final aytOrtalama = _averageForType(sinavlar, 'AYT');
    final aiQuestionCount = sorular.where((soru) => soru.isAiSaved).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kayıtlar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: logout,
            tooltip: 'Çıkış Yap',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(sorularProvider);
          ref.invalidate(sinavlarProvider);
          await Future<void>.delayed(const Duration(milliseconds: 250));
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
          children: [
            _RecordsHero(
              questionCount: sorular.length,
              examCount: sinavlar.length,
              aiQuestionCount: aiQuestionCount,
            ),
            const SizedBox(height: 18),
            Text(
              'Hızlı işlemler',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ActionCard(
                    icon: Icons.add_chart_rounded,
                    title: 'Sınav Ekle',
                    subtitle: 'Net ve konu kırılımı',
                    color: const Color(0xFF1685C8),
                    background: const Color(0xFFEAF6FF),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SinavEkle()),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionCard(
                    icon: Icons.add_circle_outline_rounded,
                    title: 'Soru Ekle',
                    subtitle: 'Çözdüğün soruyu kaydet',
                    color: const Color(0xFF6C55E0),
                    background: const Color(0xFFF0ECFF),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SoruEkle()),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _CompactLink(
                    icon: Icons.auto_awesome_rounded,
                    title: 'AI ile Soru Çöz',
                    color: const Color(0xFF17895C),
                    onTap: () => context.push(AppRoutes.aiSolver),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CompactLink(
                    icon: Icons.insights_rounded,
                    title: 'Analiz Merkezi',
                    color: const Color(0xFFE6653C),
                    onTap: () => context.push(AppRoutes.analytics),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _ExamAverageCard(
              tytAverage: tytOrtalama,
              aytAverage: aytOrtalama,
              hasError: sinavlarAsync.hasError,
              errorText: sinavlarAsync.hasError
                  ? DataErrorMapper.message(sinavlarAsync.error!)
                  : null,
            ),
            const SizedBox(height: 24),
            _SectionTitle(
              icon: Icons.quiz_outlined,
              title: 'Sorular',
              count: sorular.length,
              color: const Color(0xFF6C55E0),
            ),
            const SizedBox(height: 10),
            _buildSorularCard(sorularAsync),
            const SizedBox(height: 24),
            _SectionTitle(
              icon: Icons.assignment_outlined,
              title: 'Sınavlar',
              count: sinavlar.length,
              color: const Color(0xFF1685C8),
            ),
            const SizedBox(height: 10),
            _buildSinavlarCard(sinavlarAsync),
          ],
        ),
      ),
    );
  }

  Widget _buildSorularCard(AsyncValue<List<Soru>> sorularAsync) {
    return sorularAsync.when(
      loading: () => const _LoadingCard(),
      error: (error, _) => _StateCard(
        icon: Icons.error_outline_rounded,
        title: 'Sorular yüklenemedi',
        message: DataErrorMapper.message(error),
      ),
      data: (sorular) {
        if (sorular.isEmpty) {
          return const _StateCard(
            icon: Icons.quiz_outlined,
            title: 'Henüz soru yok',
            message: 'Manuel soru ekleyebilir veya AI ile çözdüğün soruları kaydedebilirsin.',
          );
        }

        return Column(
          children: [
            for (var i = 0; i < sorular.length; i++) ...[
              _QuestionCard(
                soru: sorular[i],
                onEdit: () => _showUpdateSoruDialog(context, sorular[i]),
                onDelete: () => _confirmDeleteSoru(sorular[i]),
              ),
              if (i != sorular.length - 1) const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSinavlarCard(AsyncValue<List<Sinav>> sinavlarAsync) {
    return sinavlarAsync.when(
      loading: () => const _LoadingCard(),
      error: (error, _) => _StateCard(
        icon: Icons.error_outline_rounded,
        title: 'Sınavlar yüklenemedi',
        message: DataErrorMapper.message(error),
      ),
      data: (sinavlar) {
        if (sinavlar.isEmpty) {
          return const _StateCard(
            icon: Icons.assignment_outlined,
            title: 'Henüz sınav yok',
            message: 'İlk denemeni eklediğinde TYT/AYT ortalamaların burada görünür.',
          );
        }

        return Column(
          children: [
            for (var i = 0; i < sinavlar.length; i++) ...[
              _ExamCard(
                sinav: sinavlar[i],
                onEdit: () => _showUpdateSinavDialog(context, sinavlar[i]),
                onDelete: () => _confirmDeleteSinav(sinavlar[i]),
              ),
              if (i != sinavlar.length - 1) const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteSoru(Soru soru) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Soruyu sil'),
        content: Text('"${soru.soruAd}" kaydını silmek istediğine emin misin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (approved == true) await _deleteSoru(soru.soruId);
  }

  Future<void> _confirmDeleteSinav(Sinav sinav) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sınavı sil'),
        content: Text('"${sinav.sinavAd}" kaydını silmek istediğine emin misin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (approved == true) await _deleteSinav(sinav.sinavId);
  }

  Future<void> _deleteSoru(String id) async {
    try {
      await ref.read(soruRepositoryProvider).deleteSoru(id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Soru silindi')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(DataErrorMapper.message(error))));
    }
  }

  Future<void> _deleteSinav(String id) async {
    try {
      await ref.read(sinavRepositoryProvider).deleteSinav(id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sınav silindi')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(DataErrorMapper.message(error))));
    }
  }

  Future<void> logout() async {
    final success = await ref.read(authControllerProvider.notifier).signOut();
    if (!mounted) return;

    if (success) {
      context.go(AppRoutes.login);
      return;
    }

    final state = ref.read(authControllerProvider);
    if (state.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AuthErrorMapper.message(state.error!))),
      );
    }
  }
}

class _RecordsHero extends StatelessWidget {
  const _RecordsHero({
    required this.questionCount,
    required this.examCount,
    required this.aiQuestionCount,
  });

  final int questionCount;
  final int examCount;
  final int aiQuestionCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1685C8), Color(0xFF6C55E0)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1685C8).withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.folder_copy_outlined, color: Colors.white, size: 25),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Çalışma Arşivin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Sınavlarını ve çözdüğün soruları düzenli tut; analizlerin bu gerçek kayıtlardan beslensin.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 17),
          Row(
            children: [
              Expanded(child: _HeroMetric(value: '$questionCount', label: 'Soru')),
              const SizedBox(width: 8),
              Expanded(child: _HeroMetric(value: '$examCount', label: 'Sınav')),
              const SizedBox(width: 8),
              Expanded(child: _HeroMetric(value: '$aiQuestionCount', label: 'AI kayıt')),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 1.2),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.82), fontSize: 11.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.background,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.28), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 25),
              const SizedBox(height: 14),
              Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 3),
              Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactLink extends StatelessWidget {
  const _CompactLink({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExamAverageCard extends StatelessWidget {
  const _ExamAverageCard({required this.tytAverage, required this.aytAverage, required this.hasError, this.errorText});
  final double tytAverage;
  final double aytAverage;
  final bool hasError;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(child: Text('Deneme ortalamaları', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
                Icon(Icons.show_chart_rounded, color: Theme.of(context).colorScheme.primary),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _Metric(label: 'TYT Ortalama', value: tytAverage == 0 ? '—' : tytAverage.toStringAsFixed(2), color: const Color(0xFF1685C8))),
                Container(height: 48, width: 1.2, color: Theme.of(context).colorScheme.outlineVariant),
                Expanded(child: _Metric(label: 'AYT Ortalama', value: aytAverage == 0 ? '—' : aytAverage.toStringAsFixed(2), color: const Color(0xFF6C55E0))),
              ],
            ),
            if (hasError && errorText != null) ...[
              const SizedBox(height: 10),
              Text(errorText!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 3),
        Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title, required this.count, required this.color});
  final IconData icon;
  final String title;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)), child: Icon(icon, size: 20, color: color)),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
        Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(999)), child: Text('$count kayıt', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12))),
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.soru, required this.onEdit, required this.onDelete});
  final Soru soru;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isAi = soru.isAiSaved;
    final accent = isAi ? const Color(0xFF6C55E0) : const Color(0xFF1685C8);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 40, height: 40, decoration: BoxDecoration(color: accent.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(13)), child: Icon(isAi ? Icons.auto_awesome_rounded : Icons.quiz_outlined, color: accent, size: 20)),
                const SizedBox(width: 11),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(soru.soruAd, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5)),
                  const SizedBox(height: 5),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    _Tag(text: soru.soruDers.isEmpty ? 'Ders belirtilmedi' : soru.soruDers, color: accent),
                    if (soru.soruKonu.trim().isNotEmpty) _Tag(text: soru.soruKonu, color: const Color(0xFF17895C)),
                    if (isAi) const _Tag(text: 'AI', color: Color(0xFF6C55E0)),
                  ]),
                ])),
                PopupMenuButton<String>(
                  tooltip: 'İşlemler',
                  onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Düzenle'), contentPadding: EdgeInsets.zero)),
                    PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline_rounded), title: Text('Sil'), contentPadding: EdgeInsets.zero)),
                  ],
                ),
              ],
            ),
            if (soru.soruCevap.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(13)), child: Text('Cevap: ${soru.soruCevap}', maxLines: 3, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExamCard extends StatelessWidget {
  const _ExamCard({required this.sinav, required this.onEdit, required this.onDelete});
  final Sinav sinav;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final totalNet = sinav.netler.values.fold<double>(0, (sum, value) => sum + value);
    final accent = sinav.sinavTuru.trim().toUpperCase() == 'AYT' ? const Color(0xFF6C55E0) : const Color(0xFF1685C8);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(15, 7, 8, 7),
        childrenPadding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
        leading: Container(width: 42, height: 42, decoration: BoxDecoration(color: accent.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(13)), child: Icon(Icons.assignment_turned_in_outlined, color: accent, size: 21)),
        title: Text(sinav.sinavAd, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Padding(padding: const EdgeInsets.only(top: 3), child: Text('${sinav.sinavTuru}${sinav.sinavBrans == null ? '' : ' • ${sinav.sinavBrans}'} • ${totalNet.toStringAsFixed(2)} net')),
        children: [
          const Divider(),
          for (final entry in sinav.netler.entries) _SubjectResultRow(name: entry.key, net: entry.value, detail: sinav.dersDetaylari[entry.key]),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Düzenle')),
            const SizedBox(width: 4),
            TextButton.icon(onPressed: onDelete, icon: const Icon(Icons.delete_outline_rounded, size: 18), label: const Text('Sil')),
          ]),
        ],
      ),
    );
  }
}

class _SubjectResultRow extends StatelessWidget {
  const _SubjectResultRow({required this.name, required this.net, required this.detail});
  final String name;
  final double net;
  final SinavDersDetay? detail;

  @override
  Widget build(BuildContext context) {
    final d = detail;
    final success = d?.basariOrani;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w800))),
          Text('${net.toStringAsFixed(2)} net', style: TextStyle(fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary)),
        ]),
        if (d != null && d.hasQuestionBreakdown) ...[
          const SizedBox(height: 3),
          Text('${d.dogru}D  ${d.yanlis}Y  ${d.bos}B${success == null ? '' : '  •  %${(success * 100).round()} başarı'}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          if (d.konular.isNotEmpty) ...[
            const SizedBox(height: 5),
            Wrap(spacing: 6, runSpacing: 6, children: d.konular.entries.map((entry) {
              final topicSuccess = entry.value.basariOrani;
              return _Tag(text: '${entry.key}${topicSuccess == null ? '' : ' %${(topicSuccess * 100).round()}'}', color: const Color(0xFF17895C));
            }).toList(growable: false)),
          ],
        ],
      ]),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withValues(alpha: 0.17))),
    child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11.5)),
  );
}

class _StateCard extends StatelessWidget {
  const _StateCard({required this.icon, required this.title, required this.message});
  final IconData icon;
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(children: [
        Icon(icon, size: 34, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(height: 9),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ]),
    ),
  );
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) => const Card(child: Padding(padding: EdgeInsets.all(22), child: Center(child: CircularProgressIndicator())));
}
