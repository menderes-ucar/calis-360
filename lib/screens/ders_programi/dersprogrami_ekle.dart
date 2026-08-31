import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/dersProgrami.dart';
import '../../core/errors/data_error_mapper.dart';
import '../../core/widgets/section_hero_card.dart';
import '../../features/study_data/presentation/providers/study_data_providers.dart';

class DersprogramiEkle extends ConsumerStatefulWidget {
  const DersprogramiEkle({super.key, this.initialWeekNumber = 1});

  final int initialWeekNumber;

  @override
  ConsumerState<DersprogramiEkle> createState() => _DersprogramiEkleState();
}

class _DersprogramiEkleState extends ConsumerState<DersprogramiEkle> {
  final List<String> dersler = [
    "Türkçe",
    "Tarih",
    "Coğrafya",
    "Felsefe",
    "Din",
    "Matematik",
    "Geometri",
    "Fizik",
    "Kimya",
    "Biyoloji",
  ];
  final List<String> gunler = [
    "Pazartesi",
    "Salı",
    "Çarşamba",
    "Perşembe",
    "Cuma",
    "Cumartesi",
    "Pazar",
  ];
  final List<String> sinavTurleri = ["TYT", "AYT"];
  final TextEditingController saatText = TextEditingController();

  String? secilenSinav;
  String? secilenDers;
  String? secilenKonu;
  String? secilenGun;

  Map<String, List<String>> tytKonular = {
    "Matematik": [
      "Gerçel Sayılar",
      "Faktöriyel Kavramı",
      "Basamak Kavramı",
      "Görsel Zeka",
      "Sayısal Sözel Mantık",
      "Örüntülü Sayı Grupları",
      "Bir ve İki Bilinmeyenli Denklemler",
      "Bir ve İki Bilinmenli Eşitsizlikler",
      "Mutlak Değer",
      "Üslü Sayılar",
      "Köklü Sayılar",
      "Tanım ve Formül Kullanabilme",
      "Oran Orantı",
      "Çarpanlara Ayırma",
      "Sayı Problemleri",
      "Kesir Problemleri",
      "Yaş Problemleri",
      "Yüzde Problemleri",
      "Karışım Porblemleri",
      "Hız Problemleri",
      "Grafik Yorumlama ",
      "Emek Problemleri",
      "Asal Çarpanlar",
      "Bölme Bölünebilme",
      "EBOB-EKOK",
      "Mantık",
      "Kümeler-Kartezyen Çarpım",
      "Fonsksiyonlar",
      "Sayma Olasılık",
      "İkinci Dereceden Denklemler",
      " Polinomlar",
    ],
    "Geometri": [
      "Açılar",
      "Özel Üçgenler",
      "Benzerlik",
      "Üçgende Yardımcı Elemalar",
      "Üçgende Alan",
      "Genel Dörtgenler-Yamuk",
      "Paralelkenar-Eşkenar-Dörtgen-Deltoid",
      "Dikdörtgen-Kare",
      "Çokgenler",
      "Çember-Daire",
      "Analitik Geometri",
      "Katı Cisimler",
      "Çember Analitiği",
    ],
    "Fizik": [
      "Fizik Bilimine Giriş",
      "Kuvvet ",
      " Hareket",
      "Enerji ",
      "Elektrostatik",
      "Elektrik Akımı",
      "Manyetizma",
      "Optik",
      "Madde ve Özellikleri",
      "Basınç",
      "Kaldrıma Kuvveti",
      "Isı ve Sıcaklık",
      "Yay Dalgaları",
      "Su Dalgaları",
      "Ses ve Deprem Dalgası",
    ],
    "Kimya": [
      "Kimya Bilimi",
      "Atom ve Periyodik Sistemi",
      "Kimyasal Türler Arası Etkileşimler",
      "Maddenin Halleri",
      "Doğa ve Kimya",
      "Kimyanın Temel Kanunları Ve Kimyasal Hesaplamalar",
      "Karışımlar",
      "Asit-Bazlar Ve Tuzlar",
      "Kimya Her Yerde",
    ],
    "Biyoloji": [
      "Biyolojik ve Canlıların Ortak Özellikleri",
      "Canlı Yapısındaki Bileşikler",
      "Hücre",
      "Canlıların Sınıflandırılması",
      "Hücre Bölünmeleri ve Üreme",
      "Kalıtım",
      "Ekoloji",
    ],
    "Türkçe": [
      "Anlam Bilgisi",
      "Sözcükte Anlam",
      "Deyim ve Atasözü",
      "Cümlede Kavramlar",
      "Cümle yorumu",
      "Anlatım Teknikleri",
      "Paragraf Yorumu",
      "Paragrafta Yardımcı Düşünce",
      "Paragraf Yapısı",
      "Ses-Yazım-Noktalama",
      "Ses Bilgisi",
      "Yazım Kuralları",
      "Noktalama İşaretleri",
      "Sözcük Yapısı",
      "İsim Soylu Sözcükler",
      "İsim(Ad)",
      "Sıfat(Ön Ad)",
      "Zamir",
      "Zarf",
      "Edat-Bağlaç-Ünlem",
      "Fiiller",
      "Fiil Çekimi",
      "Ek Fiil",
      "Fiilde Yapı",
      "Fiilimsiler",
      "Fiilde Çatı",
      "Cümle Bilgisi",
      "Söz Öbekleri",
      "Cümlenin Ögeleri",
      "Cümlenin Çeşitleri",
      "Anlatım Bozukluğu",
      "Anlama Dayalı Anlatım Bozuklukları",
      "Dil Bilgisine Dayalı Anlatım Bozuklukları",
    ],
    "Tarih": [
      "Tarih ve Zaman",
      "İnsanlığın İlk Dönemleri",
      "İlk ve Orta Çağlarda Türk Dünyası",
      "İslam Medeniyetinin Doğuşu ve İlk İslam Devletleri",
      "Türklerin İslamiyet’i Kabulü ve İlk Türk İslam Devletleri",
      "Orta Çağ’da Dünya, Yerleşme ve Devletleşme Sürecinde Selçuklu Türkiyesi",
      "Beylikten Devlete Osmanlı Siyaseti",
      "Devletleşme Sürecinde Savaşçılar ve Askerler",
      "Beylikten Devlete Osmanlı Medeniyeti",
      "Dünya Gücü Osmanlı",
      "Sultan ve Osmanlı Merkez Teşkilatı",
      "Klasik Çağda Osmanlı Toplum Düzeni",
      "Değişen Dünya Dengeleri Karşısında Osmanlı Siyaseti",
      "Değişim Çağında Avrupa ve Osmanlı",
      "Uluslararası İlişkilerde Denge Stratejisi (1774-1914)",
      "Devrimler Çağında Değişen Devlet-Toplum İlişkileri",
      "Sermaye ve Emek",
      "XIX. ve XX. Yüzyılda Değişen Gündelik Hayat",
      "XX. Yüzyıl Başlarında Osmanlı Devleti ve Dünya",
      "Milli Mücadele",
      "Atatürkçülük ve Türk İnkılabı",
    ],
    "Coğrafya": [
      "Doğa , İnsan ve Coğrafya",
      "Dünyanın Şekli ve Hareketleri",
      "Coğrafi Koordinat Sistemi",
      "Harita Bilgisi",
      "İklim Bilgisi",
      "Toprak-Su-Bitki",
      "Yer Yuvarlağının Oluşumu-İç ve Idş Kuvvetler",
      "Nüfus-Yerleşme ve Göç",
      "Türkiye'de Nüfus,Yerleşme ve Göç",
      "Ekonomik Faaliyetler",
      "Bölge Kavramı",
      "Bölgeler ve Ülkeler",
      "İnsan ve Çevre",
    ],
    "Felsefe": [
      "Felsefeyi Tanıma",
      "Varlık Felsefesi",
      "Bilgi Felsefesi",
      "Ahlak Felsefesi",
      "Siyaset Felsefesi",
      "Din Felsefesi",
      "Sanat Felsefesi",
      "Bilim Felsefesi",
      "Felsefe Tarihi",
    ],
    "Din": [
      "İnsan Ve Din",
      "İbadet ve Temizlik",
      "Hz.Muhammed(S.A.V.)",
      "Kur'an ve Ana Konuları",
      "Değerler",
      "İslam ve Bilim",
      "Türkler ve Müslümanlık",
      "Allah İnsan İlişkisi",
      "Din ve Hayat",
      "Dünya Ve Ahiret",
      "Kur'an'da Bazı Kavramlar",
      "İnançla İlgili Meseleler",
      "Dinler",
      "Tasavvufi Yorumlar",
      "Güncel Dini Meseleler",
    ],
  };
  Map<String, List<String>> aytKonular = {
    "Matematik": [
      "Türev",
      "İntegral",
      "Eşitsizlikler",
      "Fonksiyonlar",
      "Polinomlar",
      "İkinci Dereceden Denklemler",
      "Parabol",
      "Trigonometri",
      "Diziler",
      "Limit-Süreklilik",
      "Logaritma",
      "Sayma-Olasılık",
    ],
    "Geometri": [
      "Açılar",
      "Özel Üçgenler",
      "Benzerlik",
      "Üçgende Yardımcı Elemalar",
      "Üçgende Alan",
      "Genel Dörtgenler-Yamuk",
      "Paralelkenar-Eşkenar-Dörtgen-Deltoid",
      "Dikdörtgen-Kare",
      "Çokgenler",
      "Çember-Daire",
      "Analitik Geometri",
      "Katı Cisimler",
      "Çember Analitiği",
    ],
    "Fizik": [
      "Vektörler",
      "Kuvvet, Tork ve Denge",
      "Kütle Merkezi",
      "Basit Makineler",
      "Hareket",
      "Newton’un Hareket Yasaları",
      "İş, Güç ve Enerji",
      "Atışlar",
      "İtme ve Momentum",
      "Elektrik Alan ve Potansiyel",
      "Paralel Levhalar ve Sığa",
      "Manyetik Alan ve Manyetik Kuvvet",
      "İndüksiyon, Alternatif Akım ve Transformatörler",
      "Düzgün Çembersel Hareket",
      "Dönme, Yuvarlanma ve Açısal Momentum",
      "Kütle Çekim ve Kepler Yasaları",
      "Basit Harmonik Hareket",
      "Dalga Mekaniği",
      "Atom Fiziğine Giriş ve Radyoaktivite",
      "Modern Fizik",
      "Modern Fiziğin Teknolojideki Uygulamaları",
    ],
    "Kimya": [
      "Kimya Bilimi",
      "Atom ve Periyodik Sistem",
      "Kimyasal Türler Arası Etkileşimler",
      "Kimyasal Hesaplamalar",
      "Kimyanın Temel Kanunları",
      "Asit, Baz ve Tuz",
      "Maddenin Halleri",
      "Karışımlar",
      "Doğa ve Kimya",
      "Kimya Her Yerde",
      "Modern Atom Teorisi",
      "Gazlar",
      "Sıvı Çözeltiler ve Çözünürlük",
      "Kimyasal Tepkimelerde Enerji",
      "Kimyasal Tepkimelerde Hız",
      "Kimyasal Tepkimelerde Denge",
      "Asit-Baz Dengesi",
      "Çözünürlük Dengesi",
      "Kimya ve Elektrik",
      "Karbon Kimyasına Giriş",
      "Organik Kimya",
      "Enerji Kaynakları ve Bilimsel Gelişmeler",
    ],
    "Biyoloji": [
      "Sinir Sistemi",
      "Endokrin Sistem",
      "Duyu Organları",
      "Destek ve Hareket Sistemi",
      "Sindirim Sistemi",
      "Dolaşım Sistemi",
      "Solunum Sistemi",
      "Üriner Sistem (Boşaltım Sistemi)",
      "Üreme Sistemi ve Embriyonik Gelişim",
      "Komünite Ekolojisi",
      "Popülasyon Ekolojisi",
      "Genden Proteine",
      "Nükleik Asitler",
      "Genetik Şifre ve Protein Sentezi",
      "Canlılarda Enerji Dönüşümleri",
      "Canlılık ve Enerji",
      "Fotosentez",
      "Kemosentez",
      "Hücresel Solunum",
      "Bitki Biyolojisi",
      "Canlılar ve Çevre",
    ],
    "Türkçe": [
      "Anlam Bilgisi",
      "Şiir Bilgisi",
      "Edebi Sanatlar",
      "İslamiyet Öncesi Türk Edebiyatı ve Geçiş Dönemi",
      "Halk Edebiyatı",
      "Divan Edebiyatı",
      "Tanzimat Edebiyatı",
      "Servet-i Fünun ve Fecr-i Ati Edebiyatı",
      "Milli Edebiyat",
      "Cumhuriyet Dönemi Edebiyatı",
      "Edebi Akımlar",
      "Roman Özetleri",
    ],
    "Tarih": [
      "Bütün TYT Konuları",
      "İki Küresel Savaş Arasında Dünya",
      "II.Dünya Savaşı",
      "Soğuk Savaş Dönemi",
      "Yumuşama Dönemi ve Sonrası",
      "Küreselleşen Dünya",
    ],
    "Coğrafya": [
      "Ekosistemlerin Özellikleri ve İşleyişi",
      "Nüfus Politikaları",
      "Yerleşmelerin Özellikleri",
      "Ekonomik Faaliyetler ve Doğal Kaynaklar",
      "Türkiye’de Ekonomi",
      "Geçmişten Geleceğe Şehir ve Ekonomi",
      "Türkiye’nin İşlevsel Bölgeleri ve Kalkınma Projeleri",
      "Hizmet Sektörünün Ekonomideki Yeri",
      "Küresel Ticaret",
      "Türkiye Turizmi",
      "Kültür Bölgeleri",
      "Jeopolitik Konum",
      "Ülkeler Arası Etkileşim",
      "Çevre ve Toplum",
    ],
    "Felsefe": [
      "Felsefe’nin Konusu",
      "Bilgi Felsefesi",
      "Varlık Felsefesi",
      "Ahlak Felsefesi",
      "Sanat Felsefesi",
      "Din Felsefesi",
      "Siyaset Felsefesi",
      "Bilim Felsefesi",
      "İlk Çağ Felsefesi",
      "MÖ 6. Yüzyıl – MS 2. Yüzyıl Felsefesi",
      "MS 2. Yüzyıl – MS 15. Yüzyıl Felsefesi",
      "15. Yüzyıl – 17. Yüzyıl Felsefesi",
      "18. Yüzyıl – 19. Yüzyıl Felsefesi",
      "20. Yüzyıl Felsefesi",
      "Mantığa Giriş",
      "Klasik Mantık",
      "Mantık ve Dil",
      "Sembolik Mantık",
      "Psikoloji Bilimini Tanıyalım",
      "Psikolojinin Temel Süreçleri",
      "Öğrenme Bellek Düşünme",
      "Ruh Sağlığının Temelleri",
      "Sosyolojiye Giriş",
      "Birey ve Toplum",
      "Toplumsal Yapı",
      "Toplumsal Değişme ve Gelişme",
      "Toplum ve Kültür",
      "Toplumsal Kurumlar",
    ],
    "Din": [
      "İnsan Ve Din",
      "İbadet ve Temizlik",
      "Hz.Muhammed(S.A.V.)",
      "Kur'an ve Ana Konuları",
      "Değerler",
      "İslam ve Bilim",
      "Türkler ve Müslümanlık",
      "Allah İnsan İlişkisi",
      "Din ve Hayat",
      "Dünya Ve Ahiret",
      "Kur'an'da Bazı Kavramlar",
      "İnançla İlgili Meseleler",
      "Dinler",
      "Tasavvufi Yorumlar",
      "Güncel Dini Meseleler",
    ],
  };

  bool _saving = false;

  @override
  void dispose() {
    saatText.dispose();
    super.dispose();
  }

  Future<void> programEkle() async {
    if (secilenSinav == null ||
        secilenDers == null ||
        secilenGun == null ||
        saatText.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Boş bırakılan yerleri doldurmalısın!")),
      );
      return;
    }

    final saat = int.tryParse(saatText.text.trim());
    if (saat == null || saat < 0 || saat > 23) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Çalışma saati 0 ile 23 arasında olmalı."),
        ),
      );
      return;
    }

    if (_saving) return;
    setState(() => _saving = true);
    final repository = ref.read(dersProgramiRepositoryProvider);
    final yeni = DersProgram(
      dersProgramId: repository.createId(),
      dersProgramDersAd: secilenDers!,
      dersProgramKonuAd: secilenKonu ?? '',
      dersProgramGun: secilenGun!,
      dersProgramSaat: saat,
      dersProgramSinavTur: secilenSinav!,
      weekNumber: widget.initialWeekNumber,
    );

    try {
      await repository.addDersProgram(yeni);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Plan kaydedildi ✅")));
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(DataErrorMapper.message(error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final secilenKonularMap = secilenSinav == 'AYT' ? aytKonular : tytKonular;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Çalışma Ekle')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
        children: [
          SectionHeroCard(
            icon: Icons.event_note_outlined,
            title: '${widget.initialWeekNumber}. haftaya çalışma ekle',
            subtitle:
                'Sınav türünü, dersi, konuyu ve zamanı seç; çalışma ${widget.initialWeekNumber}. haftaya eklensin.',
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Çalışma içeriği',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: secilenSinav,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Sınav türü',
                      prefixIcon: Icon(Icons.assignment_outlined),
                    ),
                    items: sinavTurleri
                        .map(
                          (tur) =>
                              DropdownMenuItem(value: tur, child: Text(tur)),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) {
                            setState(() {
                              secilenSinav = value;
                              secilenDers = null;
                              secilenKonu = null;
                            });
                          },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: secilenDers,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Ders',
                      prefixIcon: Icon(Icons.menu_book_outlined),
                    ),
                    items: dersler
                        .map(
                          (ders) =>
                              DropdownMenuItem(value: ders, child: Text(ders)),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) {
                            setState(() {
                              secilenDers = value;
                              secilenKonu = null;
                            });
                          },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: secilenKonu,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Konu (isteğe bağlı)',
                      prefixIcon: Icon(Icons.topic_outlined),
                    ),
                    items:
                        (secilenDers != null &&
                            secilenKonularMap.containsKey(secilenDers))
                        ? secilenKonularMap[secilenDers]!
                              .map(
                                (konu) => DropdownMenuItem(
                                  value: konu,
                                  child: Text(
                                    konu,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList()
                        : const <DropdownMenuItem<String>>[],
                    onChanged: _saving || secilenDers == null
                        ? null
                        : (value) => setState(() => secilenKonu = value),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Zamanlama',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: secilenGun,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Çalışma günü',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    items: gunler
                        .map(
                          (gun) =>
                              DropdownMenuItem(value: gun, child: Text(gun)),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => secilenGun = value),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: saatText,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Başlangıç saati',
                      hintText: 'Örn. 19',
                      helperText: '0–23 arasında saat gir.',
                      prefixIcon: Icon(Icons.schedule_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : programEkle,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(_saving ? 'Kaydediliyor...' : 'Planı Kaydet'),
            ),
          ),
        ],
      ),
    );
  }
}
