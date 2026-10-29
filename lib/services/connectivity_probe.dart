/// واجهة فحص الاتصال متعددة المنصات.
///
/// - على الأجهزة (IO): استعلام DNS مباشر.
/// - على الويب: مؤشر المتصفح `navigator.onLine`.
///
/// يُختار التنفيذ وقت الترجمة عبر conditional import.
library;

export 'connectivity_probe_io.dart' if (dart.library.html) 'connectivity_probe_web.dart';
