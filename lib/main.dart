import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/app.dart';

void main() {
  runApp(const ProviderScope(child: NovelViewerApp()));
}
