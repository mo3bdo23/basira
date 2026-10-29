import 'dart:io';

/// فحص الاتصال على الأجهزة: استعلام DNS سريع.
Future<bool> probeOnline() async {
  try {
    final List<InternetAddress> result =
        await InternetAddress.lookup('one.one.one.one').timeout(const Duration(seconds: 3));
    return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
  } catch (_) {
    return false;
  }
}
