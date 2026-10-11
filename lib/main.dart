import 'dart:async';

import 'package:flutter/material.dart';

import 'appearance/appearance_controller.dart';
import 'theme.dart';
import 'ui/study_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StudyApp());
}

class StudyApp extends StatefulWidget {
  const StudyApp({super.key});
  @override
  State<StudyApp> createState() => _StudyAppState();
}

class _StudyAppState extends State<StudyApp> with WidgetsBindingObserver {
  final appearance = AppearanceController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(appearance.initialize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      appearance.setActive(state == AppLifecycleState.resumed);
  @override
  void didChangePlatformBrightness() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAccessibilityFeatures() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    appearance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppearanceScope(
      controller: appearance,
      child: ListenableBuilder(
        listenable: appearance,
        builder: (context, _) {
          final scene = appearance.scene(
            systemBrightness:
                WidgetsBinding.instance.platformDispatcher.platformBrightness,
          );
          final systemReduced = WidgetsBinding
              .instance
              .platformDispatcher
              .accessibilityFeatures
              .disableAnimations;
          return MaterialApp(
            title: 'Study App',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.sunset(scene),
            themeAnimationDuration: appearance.reduceMotion || systemReduced
                ? Duration.zero
                : const Duration(milliseconds: 700),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations:
                    appearance.reduceMotion ||
                    MediaQuery.disableAnimationsOf(context),
              ),
              child: child!,
            ),
            home: const StudyShell(),
          );
        },
      ),
    );
  }
}
