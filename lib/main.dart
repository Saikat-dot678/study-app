import 'dart:async';

import 'package:flutter/material.dart';

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

class _StudyAppState extends State<StudyApp> {
  late DateTime now;
  Timer? refreshTimer;

  @override
  void initState() {
    super.initState();
    now = DateTime.now();
    refreshTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      if (mounted) setState(() => now = DateTime.now());
    });
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Study',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightFor(now),
      darkTheme: AppTheme.darkFor(now),
      themeMode: ThemeMode.system,
      themeAnimationDuration: const Duration(milliseconds: 700),
      themeAnimationCurve: Curves.easeInOutCubic,
      home: const StudyShell(),
    );
  }
}
