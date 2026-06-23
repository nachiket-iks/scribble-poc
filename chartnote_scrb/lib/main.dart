import 'package:flutter/material.dart';

import 'chartnote_screen.dart'; // for jsonDecode + base64Decode + utf8

void main() {
  runApp(const ChartNoteApp());
}

// ── App Root ────────────────────────────────────────────────
class ChartNoteApp extends StatelessWidget {
  const ChartNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BP Chart Note Viewer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFC0392B), brightness: Brightness.light),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF1A1F2E), foregroundColor: Colors.white, elevation: 0),
      ),
      home: const ChartNoteScreen(),
    );
  }
}
