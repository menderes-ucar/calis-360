import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

import '../domain/content_models.dart';

abstract class ContentRepository {
  Future<List<StudySubject>> getSubjects();
  Future<List<StudyUnit>> getUnits(String subjectId);
  Future<List<StudyTopic>> getTopics(String subjectId, String unitId);
  Future<StudyTopic?> getTopic(String subjectId, String unitId, String topicId);

  Future<String?> getPersonalSummary({
    required String uid,
    required String subjectId,
    required String unitId,
    required String topicId,
  });

  Future<void> savePersonalSummary({
    required String uid,
    required String subjectId,
    required String unitId,
    required String topicId,
    required String summary,
  });

  Future<void> deletePersonalSummary({
    required String uid,
    required String subjectId,
    required String unitId,
    required String topicId,
  });
}

class HybridContentRepository implements ContentRepository {
  HybridContentRepository({
    required FirebaseFirestore firestore,
    AssetBundle? assetBundle,
  }) : _firestore = firestore,
       _assetBundle = assetBundle ?? rootBundle;

  final FirebaseFirestore _firestore;
  final AssetBundle _assetBundle;

  Map<String, dynamic>? _localCatalog;

  @override
  Future<List<StudySubject>> getSubjects() async {
    try {
      final snapshot = await _firestore
          .collection('contentSubjects')
          .orderBy('order')
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs
            .map((doc) => StudySubject.fromMap(doc.id, doc.data()))
            .toList(growable: false);
      }
    } catch (_) {
      // Ağ / yetki sorunu olduğunda uygulamayla gelen starter katalog kullanılır.
    }

    final catalog = await _loadLocalCatalog();
    final subjects =
        (catalog['subjects'] as List? ?? const [])
            .whereType<Map>()
            .map((item) {
              final map = Map<String, dynamic>.from(item);
              return StudySubject.fromMap((map['id'] ?? '').toString(), map);
            })
            .toList(growable: false)
          ..sort((a, b) => a.order.compareTo(b.order));
    return subjects;
  }

  @override
  Future<List<StudyUnit>> getUnits(String subjectId) async {
    try {
      final snapshot = await _firestore
          .collection('contentSubjects')
          .doc(subjectId)
          .collection('units')
          .orderBy('order')
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs
            .map((doc) => StudyUnit.fromMap(doc.id, subjectId, doc.data()))
            .toList(growable: false);
      }
    } catch (_) {}

    final subject = await _findLocalSubject(subjectId);
    final units =
        (subject?['units'] as List? ?? const [])
            .whereType<Map>()
            .map((item) {
              final map = Map<String, dynamic>.from(item);
              return StudyUnit.fromMap(
                (map['id'] ?? '').toString(),
                subjectId,
                map,
              );
            })
            .toList(growable: false)
          ..sort((a, b) => a.order.compareTo(b.order));
    return units;
  }

  @override
  Future<List<StudyTopic>> getTopics(String subjectId, String unitId) async {
    try {
      final snapshot = await _firestore
          .collection('contentSubjects')
          .doc(subjectId)
          .collection('units')
          .doc(unitId)
          .collection('topics')
          .orderBy('order')
          .get();

      if (snapshot.docs.isNotEmpty) {
        final localUnit = await _findLocalUnit(subjectId, unitId);
        final localTopics = <String, Map<String, dynamic>>{};
        for (final item
            in (localUnit?['topics'] as List? ?? const []).whereType<Map>()) {
          final map = Map<String, dynamic>.from(item);
          localTopics[(map['id'] ?? '').toString()] = map;
        }

        return snapshot.docs
            .map((doc) {
              final merged = _mergeTopicMaps(localTopics[doc.id], doc.data());
              return StudyTopic.fromMap(doc.id, subjectId, unitId, merged);
            })
            .toList(growable: false)
          ..sort((a, b) => a.order.compareTo(b.order));
      }
    } catch (_) {}

    final unit = await _findLocalUnit(subjectId, unitId);
    final topics =
        (unit?['topics'] as List? ?? const [])
            .whereType<Map>()
            .map((item) {
              final map = Map<String, dynamic>.from(item);
              return StudyTopic.fromMap(
                (map['id'] ?? '').toString(),
                subjectId,
                unitId,
                map,
              );
            })
            .toList(growable: false)
          ..sort((a, b) => a.order.compareTo(b.order));
    return topics;
  }

  @override
  Future<StudyTopic?> getTopic(
    String subjectId,
    String unitId,
    String topicId,
  ) async {
    try {
      final doc = await _firestore
          .collection('contentSubjects')
          .doc(subjectId)
          .collection('units')
          .doc(unitId)
          .collection('topics')
          .doc(topicId)
          .get();

      if (doc.exists && doc.data() != null) {
        final local = await _findLocalTopicMap(subjectId, unitId, topicId);
        final merged = _mergeTopicMaps(local, doc.data()!);
        return StudyTopic.fromMap(doc.id, subjectId, unitId, merged);
      }
    } catch (_) {}

    final unit = await _findLocalUnit(subjectId, unitId);
    final topics = (unit?['topics'] as List? ?? const []).whereType<Map>();
    for (final item in topics) {
      final map = Map<String, dynamic>.from(item);
      if ((map['id'] ?? '').toString() == topicId) {
        return StudyTopic.fromMap(topicId, subjectId, unitId, map);
      }
    }
    return null;
  }

  DocumentReference<Map<String, dynamic>> _personalTopicRef({
    required String uid,
    required String subjectId,
    required String unitId,
    required String topicId,
  }) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('contentNotes')
        .doc('${subjectId}__${unitId}__$topicId');
  }

  @override
  Future<String?> getPersonalSummary({
    required String uid,
    required String subjectId,
    required String unitId,
    required String topicId,
  }) async {
    final doc = await _personalTopicRef(
      uid: uid,
      subjectId: subjectId,
      unitId: unitId,
      topicId: topicId,
    ).get();
    final value = doc.data()?['personalSummary']?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  @override
  Future<void> savePersonalSummary({
    required String uid,
    required String subjectId,
    required String unitId,
    required String topicId,
    required String summary,
  }) async {
    final value = summary.trim();
    if (value.isEmpty) {
      return deletePersonalSummary(
        uid: uid,
        subjectId: subjectId,
        unitId: unitId,
        topicId: topicId,
      );
    }
    await _personalTopicRef(
      uid: uid,
      subjectId: subjectId,
      unitId: unitId,
      topicId: topicId,
    ).set({
      'subjectId': subjectId,
      'unitId': unitId,
      'topicId': topicId,
      'personalSummary': value,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> deletePersonalSummary({
    required String uid,
    required String subjectId,
    required String unitId,
    required String topicId,
  }) async {
    await _personalTopicRef(
      uid: uid,
      subjectId: subjectId,
      unitId: unitId,
      topicId: topicId,
    ).delete();
  }

  Future<Map<String, dynamic>?> _findLocalTopicMap(
    String subjectId,
    String unitId,
    String topicId,
  ) async {
    final unit = await _findLocalUnit(subjectId, unitId);
    for (final item
        in (unit?['topics'] as List? ?? const []).whereType<Map>()) {
      final map = Map<String, dynamic>.from(item);
      if ((map['id'] ?? '').toString() == topicId) return map;
    }
    return null;
  }

  Map<String, dynamic> _mergeTopicMaps(
    Map<String, dynamic>? local,
    Map<String, dynamic> remote,
  ) {
    if (local == null) return Map<String, dynamic>.from(remote);

    final merged = Map<String, dynamic>.from(local);
    for (final entry in remote.entries) {
      final value = entry.value;
      final isEmptyString = value is String && value.trim().isEmpty;
      final isEmptyList = value is List && value.isEmpty;
      final isNull = value == null;

      // Firestore yalnızca dolu bir değer taşıyorsa local içeriğin üzerine yazsın.
      // Böylece eski/yarım Firestore belgeleri formül, kritik nokta,
      // sık hata ve örnek gibi paketlenmiş alanları görünmez yapmaz.
      if (!isNull && !isEmptyString && !isEmptyList) {
        merged[entry.key] = value;
      }
    }
    return merged;
  }

  Future<Map<String, dynamic>> _loadLocalCatalog() async {
    final cached = _localCatalog;
    if (cached != null) return cached;

    final raw = await _assetBundle.loadString(
      'assets/content/starter_content.json',
    );
    final decoded = jsonDecode(raw);
    final catalog = decoded is Map<String, dynamic>
        ? decoded
        : Map<String, dynamic>.from(decoded as Map);
    _localCatalog = catalog;
    return catalog;
  }

  Future<Map<String, dynamic>?> _findLocalSubject(String subjectId) async {
    final catalog = await _loadLocalCatalog();
    for (final item
        in (catalog['subjects'] as List? ?? const []).whereType<Map>()) {
      final map = Map<String, dynamic>.from(item);
      if ((map['id'] ?? '').toString() == subjectId) return map;
    }
    return null;
  }

  Future<Map<String, dynamic>?> _findLocalUnit(
    String subjectId,
    String unitId,
  ) async {
    final subject = await _findLocalSubject(subjectId);
    for (final item
        in (subject?['units'] as List? ?? const []).whereType<Map>()) {
      final map = Map<String, dynamic>.from(item);
      if ((map['id'] ?? '').toString() == unitId) return map;
    }
    return null;
  }
}
