// ============================================================
// BP ChartNote Viewer — Flutter Demo App
// ============================================================
// Dependencies to add in pubspec.yaml:
//   flutter_html: ^3.0.0
//   http: ^1.2.1
// ============================================================

import 'dart:async';
import 'dart:convert'; // for jsonDecode + base64Decode + utf8

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:http/http.dart' as http;

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
