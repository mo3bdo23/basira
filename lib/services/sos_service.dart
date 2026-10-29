import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../models/sos_contact.dart';
import 'storage_service.dart';

/// زر SOS: إرسال الموقع لجهات الاتصال الطارئة مع اتصال هاتفي مباشر.
/// كل شيء يعمل أوفلاين عبر تطبيق الرسائل والهاتف في الجهاز.
class SosService {
  SosService({Box<dynamic>? contactsBox, Box<dynamic>? historyBox})
      : _contacts = contactsBox ?? StorageService.instance.sosContacts,
        _history = historyBox ?? StorageService.instance.sosHistory;

  final Box<dynamic> _contacts;
  final Box<dynamic> _history;
  final Uuid _uuid = const Uuid();

  List<SosContact> contacts() {
    final List<SosContact> list = <SosContact>[];
    for (final dynamic key in _contacts.keys) {
      final dynamic raw = _contacts.get(key);
      if (raw is Map) list.add(SosContact.fromMap(raw, key.toString()));
    }
    list.sort((SosContact a, SosContact b) {
      if (a.isPrimary != b.isPrimary) return a.isPrimary ? -1 : 1;
      return a.name.compareTo(b.name);
    });
    return list;
  }

  SosContact? get primary => contacts().isEmpty ? null : contacts().first;

  Future<SosContact> save({
    String? id,
    required String name,
    required String phone,
    String relation = '',
    bool isPrimary = false,
  }) async {
    final String contactId = id ?? _uuid.v4();
    if (isPrimary) {
      for (final SosContact c in contacts()) {
        if (c.id != contactId && c.isPrimary) {
          await _contacts.put(c.id, c.copyWith(isPrimary: false).toMap());
        }
      }
    }
    final SosContact contact = SosContact(
      id: contactId,
      name: name,
      phone: phone,
      relation: relation,
      isPrimary: isPrimary,
    );
    await _contacts.put(contact.id, contact.toMap());
    return contact;
  }

  Future<void> delete(String id) => _contacts.delete(id);

  /// رسالة SOS النهائية — قصيرة لتُرسل كرسالة نصية.
  String buildMessage({
    required String userName,
    required LatLng position,
    DateTime? at,
    String? note,
  }) {
    final String time = _formatTime(at ?? DateTime.now());
    final String maps =
        'https://www.google.com/maps/search/?api=1&query=${position.latitude.toStringAsFixed(6)},${position.longitude.toStringAsFixed(6)}';
    final StringBuffer sb = StringBuffer()
      ..writeln('🚨 نداء استغاثة من تطبيق بصيرة')
      ..writeln('الاسم: ${userName.trim().isEmpty ? 'مستخدم بصيرة' : userName}')
      ..writeln('الوقت: $time')
      ..writeln('الموقع: $maps')
      ..writeln('أنا من ذوي الإعاقة البصرية وأحتاج مساعدة الآن.');
    if (note != null && note.trim().isNotEmpty) {
      sb.writeln('ملاحظة: ${note.trim()}');
    }
    return sb.toString().trim();
  }

  /// يفتح تطبيق الرسائل مع النص جاهزًا (المستخدم يضغط إرسال).
  Future<bool> openSms(String phone, String message) async {
    try {
      final Uri uri = Uri(
        scheme: 'sms',
        path: phone,
        queryParameters: <String, String>{'body': message},
      );
      return launchUrl(uri);
    } catch (e) {
      debugPrint('SMS launch failed: $e');
      return false;
    }
  }

  /// اتصال هاتفي مباشر.
  Future<bool> call(String phone) async {
    try {
      return launchUrl(Uri(scheme: 'tel', path: phone));
    } catch (e) {
      debugPrint('Call failed: $e');
      return false;
    }
  }

  /// فتح خرائط جوجل على الموقع الحالي (يُستأنس به عند وجود مرافق).
  Future<bool> openMaps(LatLng position) async {
    try {
      return launchUrl(
        Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}',
        ),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> logEvent({
    required LatLng position,
    required int contactsNotified,
    bool cancelled = false,
    bool persist = true,
  }) async {
    if (!persist) return;
    final SosEvent event = SosEvent(
      id: _uuid.v4(),
      createdAt: DateTime.now(),
      lat: position.latitude,
      lng: position.longitude,
      contactsNotified: contactsNotified,
      cancelled: cancelled,
    );
    await _history.put(event.id, event.toMap());
    // الاحتفاظ بآخر 30 حدثًا فقط (تقليل البيانات — خصوصية).
    final List<dynamic> keys = _history.keys.toList();
    if (keys.length > 30) {
      for (final dynamic k in keys.take(keys.length - 30)) {
        await _history.delete(k);
      }
    }
  }

  List<SosEvent> history() {
    final List<SosEvent> list = <SosEvent>[];
    for (final dynamic key in _history.keys) {
      final dynamic raw = _history.get(key);
      if (raw is Map) list.add(SosEvent.fromMap(raw, key.toString()));
    }
    list.sort((SosEvent a, SosEvent b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> clearHistory() => _history.clear();

  static String _formatTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)} — ${two(t.day)}/${two(t.month)}/${t.year}';
  }
}
