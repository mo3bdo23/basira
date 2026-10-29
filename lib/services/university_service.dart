import 'package:hive/hive.dart';

import '../models/university.dart';
import 'storage_service.dart';

/// الجامعات والخرائط الصوتية للأحرام الجامعية (تعمل أوفلاين من Hive).
class UniversityService {
  UniversityService({Box<dynamic>? box}) : _box = box ?? StorageService.instance.universities;

  final Box<dynamic> _box;

  List<University> all() {
    final List<University> list = <University>[];
    for (final dynamic key in _box.keys) {
      final dynamic raw = _box.get(key);
      if (raw is Map) {
        try {
          list.add(University.fromMap(raw));
        } catch (_) {
          // تجاهل سجلًا تالفًا بدلًا من إسقاط الشاشة.
        }
      }
    }
    return list;
  }

  University? byId(String id) {
    final dynamic raw = _box.get(id);
    if (raw is! Map) return null;
    return University.fromMap(raw);
  }

  University? get defaultUniversity {
    final List<University> list = all();
    return list.isEmpty ? null : list.first;
  }
}
