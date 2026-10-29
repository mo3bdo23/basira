import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'storage_service.dart';

class VisionException implements Exception {
  VisionException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// وصف المشهد من صورة الكاميرا عبر Gemini (مزود قابل للتهيئة بمفتاح المستخدم).
///
/// المفتاح يُخزَّن مشفّرًا داخل Hive على الجهاز فقط، ويُطلب مرة واحدة.
class VisionService {
  VisionService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const String _keyName = 'vision_api_key';
  static const String _model = 'gemini-2.0-flash';

  String? get key {
    final dynamic v = StorageService.instance.meta.get(_keyName);
    return (v is String && v.trim().isNotEmpty) ? v.trim() : null;
  }

  bool get isConfigured => key != null;

  Future<void> saveKey(String value) async {
    await StorageService.instance.meta.put(_keyName, value.trim());
  }

  Future<void> clearKey() => StorageService.instance.meta.delete(_keyName);

  static const String _prompt = '''
أنت مساعد لشخص كفيف تمامًا. صف الصورة بجملتين إلى أربع جمل بالعربية المصرية المبسطة.
اذكر بالترتيب: أهم العوائق أمامه، اتجاهها (يمين/يسار/أمام)، المسافة التقريبية،
وأي خطر مباشر. إن كانت الصورة غير واضحة قل ذلك بصراحة.
لا تستخدم مصطلحات تقنية، ولا تذكر أنك نموذج ذكاء اصطناعي.
''';

  /// يوصف الصورة ويعيد نصًا عربيًا جاهزًا للنطق.
  Future<String> describe(Uint8List jpegBytes) async {
    final String? apiKey = key;
    if (apiKey == null) {
      throw VisionException('لم يُضبط مفتاح الوصف. أضفه من شاشة الكاميرا.');
    }

    final Uri uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$apiKey',
    );

    final Map<String, dynamic> body = <String, dynamic>{
      'contents': <Map<String, dynamic>>[
        <String, dynamic>{
          'parts': <Map<String, dynamic>>[
            <String, dynamic>{'text': _prompt},
            <String, dynamic>{
              'inline_data': <String, String>{
                'mime_type': 'image/jpeg',
                'data': base64Encode(jpegBytes),
              },
            },
          ],
        },
      ],
      'generationConfig': <String, dynamic>{
        'temperature': 0.2,
        'maxOutputTokens': 300,
      },
    };

    late http.Response response;
    try {
      response = await _client
          .post(uri, headers: <String, String>{'Content-Type': 'application/json'}, body: jsonEncode(body))
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      debugPrint('vision network error: $e');
      throw VisionException('تعذّر الاتصال بخدمة الوصف. تحقّق من الإنترنت.');
    }

    if (response.statusCode == 400 || response.statusCode == 403) {
      throw VisionException('المفتاح غير صالح. تحقّق منه في شاشة الكاميرا.');
    }
    if (response.statusCode != 200) {
      throw VisionException('خدمة الوصف غير متاحة الآن (${response.statusCode}).');
    }

    final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
    final List<dynamic>? candidates = data['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw VisionException('لم يصل وصف. جرّب صورة أوضح.');
    }
    final Map<String, dynamic> content =
        (candidates.first as Map<String, dynamic>)['content'] as Map<String, dynamic>;
    final List<dynamic> parts = content['parts'] as List<dynamic>;
    final StringBuffer sb = StringBuffer();
    for (final dynamic p in parts) {
      final String? t = (p as Map<String, dynamic>)['text'] as String?;
      if (t != null) sb.write(t);
    }
    final String text = sb.toString().trim();
    if (text.isEmpty) throw VisionException('لم يصل وصف. جرّب صورة أوضح.');
    return text;
  }
}
