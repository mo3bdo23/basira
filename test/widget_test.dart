import 'dart:io';

import 'package:basira/screens/home_screen.dart';
import 'package:basira/services/storage_service.dart';
import 'package:basira/state/app_state.dart';
import 'package:basira/widgets/big_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppState state;
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('basira_test_');
    await StorageService.instance.init(path: tempDir.path);
    state = AppState();
  });

  tearDownAll(() async {
    await StorageService.instance.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  testWidgets('الرئيسية تعرض الأزرار الثلاثة الأساسية', (WidgetTester tester) async {
    // شاشة طويلة (Pixel 6) حتى يبني ListView كل الأزرار الأساسية.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const Directionality(
          textDirection: TextDirection.rtl,
          child: MaterialApp(home: HomeScreen()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 60));

    expect(find.text('ابدأ المشي'), findsOneWidget);
    expect(find.text('بلّغ عن عائق'), findsOneWidget);

    // زر خرائط الجامعات قد يكون أسفل الشاشة — نمرّر إليه ثم نتحقق.
    await tester.scrollUntilVisible(
      find.text('خرائط الجامعات'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.text('خرائط الجامعات'), findsOneWidget);
  });

  testWidgets('BigActionButton له تسمية وصفية في Semantics', (WidgetTester tester) async {
    bool tapped = false;
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: MaterialApp(
            home: Scaffold(
              body: BigActionButton(
                icon: Icons.navigation_rounded,
                label: 'ابدأ المشي',
                hint: 'مسارات آمنة',
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('ابدأ المشي'), findsWidgets);
    expect(find.text('مسارات آمنة'), findsOneWidget);

    await tester.tap(find.text('ابدأ المشي'));
    await tester.pump();
    expect(tapped, isTrue);
  });
}
