import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/data_error_mapper.dart';
import '../../core/widgets/section_hero_card.dart';
import '../../features/study_data/presentation/providers/study_data_providers.dart';

class HomeHedefEkle extends ConsumerStatefulWidget {
  const HomeHedefEkle({super.key});

  @override
  ConsumerState<HomeHedefEkle> createState() => _HomeHedefEkleState();
}

class _HomeHedefEkleState extends ConsumerState<HomeHedefEkle> {
  final _formKey = GlobalKey<FormState>();
  final netController = TextEditingController();
  final uniController = TextEditingController();
  final bolumController = TextEditingController();

  bool _saving = false;
  bool _prefilled = false;

  @override
  void dispose() {
    netController.dispose();
    uniController.dispose();
    bolumController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(homeHedefRepositoryProvider)
          .addOrUpdateHedefForCurrentUser(
            net: int.parse(netController.text.trim()),
            uni: uniController.text.trim(),
            bolum: bolumController.text.trim(),
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Hedefin güncellendi')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(DataErrorMapper.message(error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hedefAsync = ref.watch(homeHedefProvider);
    final theme = Theme.of(context);

    final hedef = hedefAsync.valueOrNull;
    if (!_prefilled && hedef != null) {
      _prefilled = true;
      netController.text = hedef.net.toString();
      uniController.text = hedef.uni;
      bolumController.text = hedef.bolum;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Hedefini Düzenle')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
        children: [
          const SectionHeroCard(
            icon: Icons.flag_outlined,
            title: 'Nereye ulaşmak istiyorsun?',
            subtitle:
                'Hedef netini, üniversiteni ve bölümünü belirle; ana ekranda ilerlemeni sürekli görünür tut.',
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hedef bilgileri',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: netController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Hedef net',
                        hintText: 'Örn. 85',
                        prefixIcon: Icon(Icons.speed_rounded),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Hedef netini gir.';
                        }
                        final parsed = int.tryParse(value.trim());
                        if (parsed == null || parsed < 0) {
                          return 'Geçerli bir sayı gir.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: uniController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Hedef üniversite',
                        hintText: 'Örn. İstanbul Teknik Üniversitesi',
                        prefixIcon: Icon(Icons.account_balance_outlined),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Üniversite adını gir.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: bolumController,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _save(),
                      decoration: const InputDecoration(
                        labelText: 'Hedef bölüm',
                        hintText: 'Örn. Bilgisayar Mühendisliği',
                        prefixIcon: Icon(Icons.school_outlined),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Bölüm adını gir.'
                          : null,
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check_rounded),
                        label: Text(
                          _saving ? 'Kaydediliyor...' : 'Hedefi Kaydet',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          hedefAsync.when(
            loading: () => const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: LinearProgressIndicator(),
              ),
            ),
            error: (error, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(DataErrorMapper.message(error)),
              ),
            ),
            data: (current) {
              if (current == null) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Icon(
                          Icons.flag_outlined,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Henüz kayıtlı bir hedefin yok. Yukarıdaki alanları doldurarak başlayabilirsin.',
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.flag_rounded),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${current.net} net',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              current.uni,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              current.bolum,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Hedefi sil',
                        onPressed: () async {
                          try {
                            await ref
                                .read(homeHedefRepositoryProvider)
                                .deleteHomeHedefForCurrentUser();
                            if (!context.mounted) return;
                            netController.clear();
                            uniController.clear();
                            bolumController.clear();
                            _prefilled = false;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Hedef silindi')),
                            );
                          } catch (error) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(DataErrorMapper.message(error)),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
