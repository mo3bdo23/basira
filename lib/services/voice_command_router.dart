/// نوايا الأوامر الصوتية.
enum VoiceIntent {
  navigate('ابدأ التنقل'),
  stopNavigation('إيقاف التنقل'),
  whereAmI('أين أنا'),
  reportObstacle('الإبلاغ عن عائق'),
  sos('طلب المساعدة'),
  openUniversity('خريطة الجامعة'),
  openSettings('الإعدادات'),
  goHome('الرئيسية'),
  repeat('إعادة آخر إرشاد'),
  faster('تسريع الصوت'),
  slower('إبطاء الصوت'),
  help('المساعدة'),
  trafficStatus('حالة إشارة المرور'),
  camera('وصف المشهد بالكاميرا'),
  unknown('غير مفهوم');

  const VoiceIntent(this.labelAr);
  final String labelAr;
}

class VoiceCommand {
  const VoiceCommand({
    required this.intent,
    required this.raw,
    this.confidence = 0,
    this.target,
  });

  final VoiceIntent intent;
  final String raw;
  final double confidence;
  final String? target;

  bool get isKnown => intent != VoiceIntent.unknown;

  @override
  String toString() => 'VoiceCommand(${intent.name}, conf=$confidence, target=$target)';
}

/// تحويل الكلام العربي (فصحى/عامية مصرية) إلى نوايا.
/// كل المنطق نقي وقابل للاختبار بلا أجهزة.
class VoiceCommandRouter {
  const VoiceCommandRouter._();

  /// تطبيع النص: إزالة التشكيل والتطويل، توحيد الألف/الياء/التاء، إزالة الترقيم.
  static String normalize(String input) {
    String s = input.trim().toLowerCase();
    s = s.replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '');
    s = s.replaceAll('أ', 'ا').replaceAll('إ', 'ا').replaceAll('آ', 'ا');
    s = s.replaceAll('ى', 'ي').replaceAll('ة', 'ه').replaceAll('ؤ', 'و').replaceAll('ئ', 'ي');
    // علامات الترقيم العربية داخل نطاق U+0600–U+06FF، فنستبعدها صراحةً.
    s = s.replaceAll(RegExp(r'[\u060C\u061B\u061F\u066A-\u066D\u06D4]'), ' ');
    s = s.replaceAll(RegExp(r'[^\u0600-\u06FFa-z0-9\s]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    return s.trim();
  }

  static const Map<VoiceIntent, List<String>> _keywords = <VoiceIntent, List<String>>{
    VoiceIntent.stopNavigation: <String>[
      'قف',
      'توقف',
      'اوقف',
      'ايقاف التنقل',
      'انهي',
      'الغاء التنقل',
      'اسكت',
      'بس كده',
    ],
    VoiceIntent.camera: <String>[
      'كاميرا',
      'صور',
      'صف لي',
      'ايه قدامي',
      'إيه اللي قدامي',
      'camera',
    ],
    VoiceIntent.sos: <String>[
      'طوارئ',
      'انقاذ',
      'ساعدني',
      'نجده',
      'اس او اس',
      'sos',
      'help me',
      'محتاج مساعده',
    ],
    VoiceIntent.reportObstacle: <String>[
      'بلغ',
      'بلاغ',
      'عائق',
      'حاجز',
      'في حاجه في الطريق',
      'رصيف مسدود',
      'report',
    ],
    VoiceIntent.navigate: <String>[
      'ابدأ التنقل',
      'ابدا التنقل',
      'التنقل',
      'ملاحه',
      'خذني',
      'امش',
      'بدء الرحله',
      'navigate',
      'start',
    ],
    VoiceIntent.openUniversity: <String>['جامعه', 'الجامعة', 'الجامعه', 'كليه', 'حرم جامعي'],
    VoiceIntent.openSettings: <String>['اعدادات', 'الاعدادات', 'ضبط', 'settings'],
    VoiceIntent.whereAmI: <String>['اين انا', 'مكاني', 'موقعي', 'فين انا', 'where am i'],
    VoiceIntent.repeat: <String>['كرر', 'اعاده', 'تاني', 'مره تانيه', 'repeat', 'قول تاني'],
    VoiceIntent.faster: <String>['اسرع', 'سرعه اعلي', 'بسرعه', 'faster'],
    VoiceIntent.slower: <String>['ابطي', 'ابطأ', 'بطيء', 'slower'],
    VoiceIntent.trafficStatus: <String>['اشاره', 'اشارات المرور', 'المرور', 'ضوء', 'signal'],
    VoiceIntent.goHome: <String>['الرئيسيه', 'رجوع', 'الرئيسية', 'home', 'القائمه الرئيسيه'],
    VoiceIntent.help: <String>['مساعده', 'المساعده', 'الاوامر', 'help'],
  };

  static VoiceCommand parse(String raw) {
    final String text = normalize(raw);
    if (text.isEmpty) {
      return VoiceCommand(intent: VoiceIntent.unknown, raw: raw);
    }

    VoiceIntent best = VoiceIntent.unknown;
    double bestScore = 0;

    _keywords.forEach((VoiceIntent intent, List<String> phrases) {
      for (final String phrase in phrases) {
        final String p = normalize(phrase);
        if (p.isEmpty) continue;
        if (text == p) {
          if (1.0 > bestScore) {
            bestScore = 1.0;
            best = intent;
          }
        } else if (text.contains(p)) {
          // الجمل الأطول أدق: نُرجّح طول العبارة المطابقة.
          final double score = 0.6 + (p.length / 100.0).clamp(0.0, 0.35);
          if (score > bestScore) {
            bestScore = score;
            best = intent;
          }
        }
      }
    });

    return VoiceCommand(
      intent: best,
      raw: raw,
      confidence: bestScore,
      target: _detectTarget(text),
    );
  }

  static String? _detectTarget(String normalized) {
    if (normalized.contains('جامعه') || normalized.contains('كليه')) return 'university';
    if (normalized.contains('مدرسه')) return 'school';
    if (normalized.contains('مستشفي')) return 'hospital';
    return null;
  }

  /// قائمة الأوامر المنطوقة التي يسمعها المستخدم في شاشة المساعدة.
  static const List<String> helpPhrases = <String>[
    'ابدأ التنقل',
    'توقف',
    'أين أنا',
    'بلّغ عن عائق',
    'طوارئ',
    'خريطة الجامعة',
    'الإعدادات',
    'كرر',
    'أسرع',
    'أبطأ',
  ];
}
