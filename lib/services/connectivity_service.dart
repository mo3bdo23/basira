import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// كشف الاتصال بالإنترنت بلا أي حزمة إضافية (DNS lookup).
/// الوضع الافتراضي "غير متصل" حتى نتأكد، لأن التطبيق أوفلاين أولًا.
class ConnectivityService {
  ConnectivityService();

  final ValueNotifier<bool> online = ValueNotifier<bool>(false);
  final ValueNotifier<DateTime?> lastCheck = ValueNotifier<DateTime?>(null);
  Timer? _timer;
  bool _checking = false;

  bool get isOnline => online.value;

  Future<bool> check() async {
    if (_checking) return online.value;
    _checking = true;
    try {
      final List<InternetAddress> result =
          await InternetAddress.lookup('one.one.one.one').timeout(const Duration(seconds: 3));
      final bool ok = result.isNotEmpty && result.first.rawAddress.isNotEmpty;
      online.value = ok;
      lastCheck.value = DateTime.now();
      return ok;
    } catch (_) {
      online.value = false;
      lastCheck.value = DateTime.now();
      return false;
    } finally {
      _checking = false;
    }
  }

  void start({Duration interval = const Duration(seconds: 20)}) {
    _timer?.cancel();
    unawaited(check());
    _timer = Timer.periodic(interval, (_) => unawaited(check()));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();
    online.dispose();
    lastCheck.dispose();
  }
}
