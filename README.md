# بصيرة — Basira

> **طريقك الآمن.. بصوتك**
> تطبيق موبايل صوتي بالكامل يمكّن الطلاب ذوي الإعاقة البصرية في مصر (15–25 سنة)
> من التنقل داخل الجامعة وفي الشارع باستقلالية وأمان.

[![Flutter](https://img.shields.io/badge/Flutter-3.24%2B-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.3%2B-0175C2?logo=dart)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## 1. المشكلة

طلاب مدرسة النور للمكفوفين بشبين الكوم أرسلوا رسالة يطالبون فيها بـ:

1. تطوير العصا البيضاء.
2. مسارات إرشادية داخل الجامعات.
3. مسارات آمنة في الشوارع.
4. إشارات مرور صوتية.

النتيجة: الطالب الكفيف يعتمد على الآخرين للتنقل، فيفقد الاستقلالية ويتعرض للخطر.
**بصيرة** يحوّل هذه المطالب إلى تطبيق واحد يعمل بالصوت فقط.

## 2. الحل

| الميزة | الوصف |
|---|---|
| **إرشاد صوتي لحظي** | «امشِ ٤٠ مترًا ثم انعطف يمينًا» — يُنطق تلقائيًا عند كل تغيّر مسافة/اتجاه |
| **خريطة مسارات آمنة** | مسارات موثّقة بدرجة أمان، تُحمَّل محليًا وتعمل بدون إنترنت |
| **إشعار إشارات المرور** | تنبيه صوتي قبل الإشارة بحالتها وثوانيها المتبقية، وتنبيه إن كانت بلا منبّه صوتي |
| **بلاغات مجتمعية** | المستخدم يسجّل عائقًا (سلالم، حفرة، رصيف مسدود) بصوته، ويُرفع عند توفر الشبكة |
| **خرائط صوتية للجامعات** | خريطة تخطيطية للمبنى + دليل صوتي لكل مبنى + إرشاد من موقعك إليه |
| **زر SOS** | عدّ تنازلي قابل للإلغاء، ثم إرسال الموقع برسالة SMS لجهة اتصال طارئة + اتصال |
| **عمل أوفلاين كامل** | Hive محلي مشفّر + طابور مزامنة؛ كل الميزات الأساسية بلا إنترنت |
| **إتاحة كاملة** | TalkBack / VoiceOver، تسميات Semantics، تباين عالٍ، أهداف لمس ≥ 88dp |

## 3. الشاشات (7)

```
Splash → إخلاء المسؤولية → Onboarding صوتي → Home
                                                ├── Navigation (إرشاد)
                                                ├── Report Obstacle (بلاغ)
                                                ├── University Map (خرائط)
                                                └── Settings + SOS Contacts (إعدادات وطوارئ)
```

| # | الشاشة | الملف |
|---|---|---|
| 1 | Splash | `lib/main.dart` (SplashScreen) |
| 2 | إخلاء المسؤولية | `lib/screens/disclaimer_screen.dart` |
| 3 | Onboarding صوتي | `lib/screens/onboarding_screen.dart` |
| 4 | الرئيسية (3 أزرار كبيرة) | `lib/screens/home_screen.dart` |
| 5 | التنقل والإرشاد | `lib/screens/navigation_screen.dart` |
| 6 | بلاغ عن عائق | `lib/screens/report_obstacle_screen.dart` |
| 7 | خريطة الجامعة | `lib/screens/university_map_screen.dart` |
| 8 | الإعدادات | `lib/screens/settings_screen.dart` |
| 9 | جهات اتصال SOS | `lib/screens/sos_contacts_screen.dart` |
| 10 | شاشة الاستغاثة | `lib/screens/sos_active_screen.dart` |

## 4. التشغيل

```bash
# 1) متطلبات: Flutter 3.24+ و Android SDK (أو Xcode لـ iOS)
flutter --version

# 2) التبعيات
flutter pub get

# 3) تشغيل على جهاز/محاكي
flutter run

# 4) بناء APK للإصدار
flutter build apk --release --split-per-abi
# الناتج: build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

### بدون إعدادات Firebase (الوضع الافتراضي)

التطبيق يعمل **بالكامل** أوفلاين: التخزين في Hive، والبلاغات تُطابَر محليًا.
Firebase اختياري للتزامن السحابي فقط.

### تشغيل Firebase (اختياري)

```bash
dart pub global activate flutterfire_cli
flutterfire configure           # يولّد firebase_options.dart و google-services.json
```

ثم:
1. ضع `google-services.json` في `android/app/`.
2. أضف في `android/build.gradle`:
   ```gradle
   classpath 'com.google.gms:google-services:4.4.2'
   ```
   وفي `android/app/build.gradle`:
   ```gradle
   apply plugin: 'com.google.gms.google-services'
   ```
3. انشر قواعد Firestore من `firebase/firestore.rules`.

## 5. المعمارية

```
lib/
├── core/          ثوابت، ثيم، حسابات جغرافية نقية
├── models/        نماذج البيانات (User, Obstacle, SafeRoute, University, Signal…)
├── services/      TTS, STT, الموقع، محرك الإرشاد، SOS، Hive، Firebase، المزامنة
├── state/         AppState (ChangeNotifier) — المنسّق المركزي
├── screens/       الشاشات
└── widgets/       مكوّنات قابلة لإعادة الاستخدام (أزرار كبيرة، خرائط، كرة صوت)
```

**مبادئ التصميم**

1. **الصوت أولًا**: كل شاشة تُعلن نفسها، وكل إجراء له تأكيد صوتي.
2. **أوفلاين أولًا**: Hive هو مصدر الحقيقة، والسحابة مزامنة اختيارية.
3. **قابلية الاختبار**: منطق الإرشاد والأوامر الصوتية والحسابات الجغرافية دوال نقية.
4. **الأمان**: مفاتيح Hive في Keychain/Keystore، لا سجلات لبيانات الموقع.

التفاصيل في [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## 6. الأوامر الصوتية

| الأمر | الوظيفة |
|---|---|
| «ابدأ التنقل» | فتح قائمة المسارات الآمنة |
| «توقف» | إنهاء التنقل |
| «أين أنا» | وصف الموقع وأقرب مبنى وإشارة |
| «بلّغ عن عائق» | فتح شاشة البلاغ |
| «طوارئ» / «ساعدني» | شاشة SOS |
| «خريطة الجامعة» | فتح خريطة الحرم |
| «الإعدادات» | فتح الإعدادات |
| «كرر» | إعادة آخر إرشاد |
| «أسرع» / «أبطأ» | تعديل سرعة النطق |
| «إشارة المرور» | حالة أقرب إشارة |

## 7. الاختبارات

```bash
flutter test
```

| الملف | يغطي |
|---|---|
| `test/geo_test.dart` | هافرساين، الاتجاهات، الدوران، صياغة المسافات |
| `test/navigation_engine_test.dart` | التقدم، الوصول، الخروج عن المسار، تكرار التنبيهات |
| `test/voice_command_test.dart` | تطبيع العربية المصرية وتصنيف 13 نية |
| `test/models_test.dart` | تسلسل النماذج، تطبيع أرقام SOS، الإعدادات |
| `test/widget_test.dart` | شاشة الرئيسية + تسميات Semantics |

## 8. هيكل البيانات

| المجموعة | الحقول الأساسية |
|---|---|
| `users` | id, name, role, phone, universityId, createdAt |
| `routes` | id, name, city, points[], landmarks[], safetyScore, estimatedMinutes |
| `obstacles` | id, type, description, location{lat,lng}, reporterId, status, severity, createdAt |
| `traffic_signals` | id, name, geo, hasAudio, greenSeconds, redSeconds |
| `universities` | id, name, city, center, buildings[] (id, name, geo, audioGuide[]) |
| `sos_contacts` | id, name, phone, relation, isPrimary |
| `settings` | speechRate, verbosity, haptics, highContrast, locationConsent… |

## 9. الأدوار

| الدور | الصلاحيات |
|---|---|
| `blind` | كل ميزات التنقل والبلاغات و SOS |
| `low_vision` | نفس الميزات + التباين العالي افتراضيًا |
| `volunteer` | التحقق من البلاغات المجتمعية |
| `university_admin` | إدارة خرائط الحرم والبلاغات داخل الجامعة |
| `admin` | إدارة كل المحتوى والمستخدمين |

## 10. الخصوصية

- الموقع **لا يُستخدم إلا أثناء الاستخدام**.
- التخزين المحلي مشفّر (AES-256) والمفتاح في Keystore/Keychain.
- لا يُشارك الموقع مع أي طرف ثالث؛ يُرسل فقط لجهات اتصال SOS **بموافقتك**.
- يمكن حذف كل البيانات من: الإعدادات ← الخصوصية ← حذف كل بياناتي.

اقرأ [`docs/PRIVACY.md`](docs/PRIVACY.md) و[`docs/DISCLAIMER.md`](docs/DISCLAIMER.md).

## 11. الفريق والخطة

خطة 5 أسابيع لفريق 5 أشخاص: [`docs/PROJECT_PLAN.md`](docs/PROJECT_PLAN.md)
التحديات والحلول: [`docs/CHALLENGES.md`](docs/CHALLENGES.md)
أهداف التنمية المستدامة: [`docs/SDG.md`](docs/SDG.md)
سيناريو العرض: [`docs/DEMO_SCRIPT.md`](docs/DEMO_SCRIPT.md)

## 12. الترخيص

MIT — انظر [LICENSE](LICENSE).

---

**WE للتكنولوجيا التطبيقية** · مشروع Capstone — الرياضيات التطبيقية · مجموعة 40626123
