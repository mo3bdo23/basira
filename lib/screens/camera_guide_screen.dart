import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/vision_service.dart';
import '../state/app_state.dart';
import '../widgets/app_scaffold.dart';

/// كاميرا الوصف: تصوّر المشهد، فيُوصف لك صوتيًا بالعربية.
class CameraGuideScreen extends StatefulWidget {
  const CameraGuideScreen({super.key});

  static const String route = '/camera';

  @override
  State<CameraGuideScreen> createState() => _CameraGuideScreenState();
}

class _CameraGuideScreenState extends State<CameraGuideScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  final VisionService _vision = VisionService();
  bool _busy = false;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final AppState app = context.read<AppState>();
    await app.speak(
      'كاميرا الوصف. وجّه الكاميرا للأمام واضغط الزر الكبير، وسأصف لك ما أمامك.',
      interrupt: true,
    );
    try {
      final List<CameraDescription> cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'لا توجد كاميرا متاحة على هذا الجهاز.');
        return;
      }
      final CameraDescription back = cameras.firstWhere(
        (CameraDescription c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final CameraController controller = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _controller = controller;
        _ready = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'تعذّر تشغيل الكاميرا: $e');
      await context.read<AppState>().speak('تعذّر تشغيل الكاميرا. تحقّق من الإذن.', interrupt: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      c.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _init();
    }
  }

  Future<void> _captureAndDescribe() async {
    final AppState app = context.read<AppState>();
    if (_busy) return;
    if (!_vision.isConfigured) {
      await _askForKey(app);
      return;
    }
    final CameraController? c = _controller;
    if (c == null || !c.value.isInitialized) {
      await app.speak('الكاميرا غير جاهزة.', interrupt: true);
      return;
    }

    setState(() => _busy = true);
    await app.speak('جارٍ الوصف، لحظة.', interrupt: true);
    try {
      final XFile file = await c.takePicture();
      final bytes = await file.readAsBytes();
      final String description = await _vision.describe(bytes);
      await app.speak(description, interrupt: true);
    } on VisionException catch (e) {
      await app.speak(e.message, interrupt: true);
    } catch (e) {
      await app.speak('تعذّر الوصف. جرّب مرة أخرى.', interrupt: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _askForKey(AppState app) async {
    final TextEditingController controller = TextEditingController();
    await app.speak(
      'أحتاج مفتاح خدمة الوصف مرة واحدة. الصقه في الحقل، أو اطلب ممن يساعدك.',
      interrupt: true,
    );
    if (!mounted) return;
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('مفتاح الوصف'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              'مفتاح Gemini المجاني. يُحفظ على جهازك فقط ولا يُرسل لأي طرف آخر.',
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'AIza...'),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (saved == true && controller.text.trim().isNotEmpty) {
      await _vision.saveKey(controller.text);
      await app.speak('تم حفظ المفتاح. اضغط الزر لوصف المشهد.', interrupt: true);
      setState(() {});
    }
    controller.dispose();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return AppScaffold(
      title: 'الكاميرا توصف لك',
      subtitle: 'وجّه الكاميرا ثم اضغط الزر الكبير',
      speakTitle: false,
      body: Column(
        children: <Widget>[
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Container(
                color: Colors.black,
                child: _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(_error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 18)),
                        ),
                      )
                    : (_ready && _controller != null)
                        ? CameraPreview(_controller!)
                        : const Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (!_vision.isConfigured)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.key_rounded, color: scheme.onSecondaryContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'أضف مفتاح الوصف مرة واحدة ليعمل.',
                      style: TextStyle(color: scheme.onSecondaryContainer, fontSize: 15),
                    ),
                  ),
                  TextButton(onPressed: () => _askForKey(context.read<AppState>()), child: const Text('إضافة')),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 84,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _captureAndDescribe,
              icon: _busy
                  ? const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 3))
                  : const Icon(Icons.camera_alt_rounded, size: 32),
              label: Text(_busy ? 'جارٍ الوصف…' : 'صف ما أمامي', style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'يعمل عبر الإنترنت. الصورة تُرسل مرة واحدة للوصف ولا تُحفظ.',
            style: TextStyle(fontSize: 14, color: scheme.onSurface.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }
}
