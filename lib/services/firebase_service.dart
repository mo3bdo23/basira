import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models/obstacle.dart';

/// طبقة Firebase **اختيارية تمامًا**: كل استدعاء محاط بحماية،
/// والتطبيق يظل يعمل كاملًا أوفلاين إن لم تُضبط إعدادات Firebase.
///
/// لتشغيلها: أضف google-services.json / GoogleService-Info.plist
/// ثم شغّل `flutterfire configure`.
class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  bool ready = false;
  String? lastError;
  fb.FirebaseAuth? _auth;
  FirebaseFirestore? _db;

  FirebaseFirestore? get db => _db;
  fb.User? get user => _auth?.currentUser;

  Future<void> init() async {
    try {
      await Firebase.initializeApp();
      _auth = fb.FirebaseAuth.instance;
      _db = FirebaseFirestore.instance;
      try {
        if (_auth!.currentUser == null) {
          await _auth!.signInAnonymously();
        }
      } catch (e) {
        // تسجيل مجهول معطّل في المشروع — نكمل بلا مصادقة.
        lastError = 'anonymous auth: $e';
      }
      ready = true;
    } catch (e) {
      ready = false;
      lastError = e.toString();
      debugPrint('Firebase unavailable (offline mode): $e');
    }
  }

  /// رفع بلاغ عائق إلى Firestore.
  Future<void> uploadObstacle(Obstacle obstacle) async {
    final FirebaseFirestore? db = _db;
    if (!ready || db == null) throw StateError('Firebase not ready');
    await db
        .collection('obstacles')
        .doc(obstacle.id)
        .set(obstacle.toFirestore(), SetOptions(merge: true));
  }

  /// تحديث حالة بلاغ (من مسؤول جامعي/متطوع).
  Future<void> updateObstacleStatus(String id, String status) async {
    final FirebaseFirestore? db = _db;
    if (!ready || db == null) throw StateError('Firebase not ready');
    await db.collection('obstacles').doc(id).update(<String, dynamic>{'status': status});
  }

  /// جلب إشارات المرور المحدّثة (حالتها قد تتغير لحظيًا في المدن الذكية).
  Future<List<Map<String, dynamic>>> fetchSignals() async {
    final FirebaseFirestore? db = _db;
    if (!ready || db == null) return <Map<String, dynamic>>[];
    final QuerySnapshot<Map<String, dynamic>> snap = await db.collection('traffic_signals').get();
    return snap.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> d) {
      return <String, dynamic>{...d.data(), 'id': d.id};
    }).toList();
  }

  /// حفظ جهة اتصال SOS في حساب المستخدم (اختياري — الأصل محلي).
  Future<void> uploadSosContacts(List<Map<String, dynamic>> contacts) async {
    final FirebaseFirestore? db = _db;
    final fb.User? u = user;
    if (!ready || db == null || u == null) return;
    await db.collection('users').doc(u.uid).set(<String, dynamic>{
      'sos_contacts': contacts,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
