import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// تخزين محلي أوفلاين أولًا (Hive) مع تشفير AES للمفاتيح الحساسة.
///
/// - مفتاح التشفير يُولَّد مرة واحدة ويُحفظ في Keychain / Keystore
///   عبر flutter_secure_storage.
/// - إذا لم يتوفر التخزين الآمن (مثلًا في بيئة الاختبار) يعمل التطبيق
///   بلا تشفير مع تسجيل الحالة، بدلًا من الانهيار.
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const String _keyName = 'basira.hive.key.v1';

  bool _ready = false;
  bool encrypted = false;

  late final Box<dynamic> settings;
  late final Box<dynamic> routes;
  late final Box<dynamic> obstacles;
  late final Box<dynamic> signals;
  late final Box<dynamic> universities;
  late final Box<dynamic> sosContacts;
  late final Box<dynamic> sosHistory;
  late final Box<dynamic> users;
  late final Box<dynamic> queue;
  late final Box<dynamic> meta;
  late final Box<dynamic> votes;

  bool get isReady => _ready;

  Future<void> init({String? path}) async {
    if (_ready) return;

    if (path != null) {
      Hive.init(path);
    } else {
      await Hive.initFlutter('basira');
    }

    final HiveAesCipher? cipher = await _cipher();

    settings = await _open('settings', cipher);
    routes = await _open('routes', cipher);
    obstacles = await _open('obstacles', cipher);
    signals = await _open('signals', cipher);
    universities = await _open('universities', cipher);
    sosContacts = await _open('sos_contacts', cipher);
    sosHistory = await _open('sos_history', cipher);
    users = await _open('users', cipher);
    queue = await _open('sync_queue', cipher);
    meta = await _open('meta', cipher);
    votes = await _open('votes', cipher);

    await _seed();
    _ready = true;
  }

  Future<Box<dynamic>> _open(String name, HiveAesCipher? cipher) {
    if (cipher == null) return Hive.openBox<dynamic>(name);
    return Hive.openBox<dynamic>(name, encryptionCipher: cipher);
  }

  Future<HiveAesCipher?> _cipher() async {
    try {
      String? encoded = await _secure.read(key: _keyName);
      if (encoded == null || encoded.isEmpty) {
        final List<int> key = List<int>.generate(32, (_) => Random.secure().nextInt(256));
        encoded = base64Encode(key);
        await _secure.write(key: _keyName, value: encoded);
      }
      final List<int> bytes = base64Decode(encoded);
      if (bytes.length != 32) return null;
      encrypted = true;
      return HiveAesCipher(bytes);
    } catch (_) {
      encrypted = false;
      return null;
    }
  }

  /// تعبئة البيانات الأولية (جامعات، مسارات، إشارات) مرة واحدة.
  Future<void> _seed() async {
    try {
      if (universities.isEmpty) {
        final List<dynamic> data =
            jsonDecode(await rootBundle.loadString('assets/data/universities.json')) as List<dynamic>;
        for (final dynamic item in data) {
          final Map<String, dynamic> map = Map<String, dynamic>.from(item as Map<dynamic, dynamic>);
          await universities.put(map['id'], map);
        }
      }
      if (routes.isEmpty) {
        final List<dynamic> data =
            jsonDecode(await rootBundle.loadString('assets/data/routes.json')) as List<dynamic>;
        for (final dynamic item in data) {
          final Map<String, dynamic> map = Map<String, dynamic>.from(item as Map<dynamic, dynamic>);
          await routes.put(map['id'], map);
        }
      }
      if (signals.isEmpty) {
        final List<dynamic> data = jsonDecode(
            await rootBundle.loadString('assets/data/traffic_signals.json')) as List<dynamic>;
        for (final dynamic item in data) {
          final Map<String, dynamic> map = Map<String, dynamic>.from(item as Map<dynamic, dynamic>);
          await signals.put(map['id'], map);
        }
      }
      if (obstacles.isEmpty) {
        final List<dynamic> data =
            jsonDecode(await rootBundle.loadString('assets/data/obstacles_seed.json')) as List<dynamic>;
        for (final dynamic item in data) {
          final Map<String, dynamic> map = Map<String, dynamic>.from(item as Map<dynamic, dynamic>);
          await obstacles.put(map['id'], <String, dynamic>{
            ...map,
            'reporterId': 'community_seed',
            'createdAt': DateTime.now().toIso8601String(),
            'status': 'verified',
            'synced': false,
          });
        }
      }
    } catch (_) {
      // البيانات الأولية اختيارية: التطبيق يعمل بدونها.
    }
  }

  /// حذف كل البيانات المحلية (من شاشة الخصوصية).
  Future<void> wipe() async {
    await settings.clear();
    await obstacles.clear();
    await sosContacts.clear();
    await sosHistory.clear();
    await users.clear();
    await queue.clear();
    await meta.clear();
    await votes.clear();
    await Hive.deleteBoxFromDisk('routes');
    await Hive.deleteBoxFromDisk('signals');
    await Hive.deleteBoxFromDisk('universities');
  }

  Future<void> close() async {
    await Hive.close();
    _ready = false;
  }
}
