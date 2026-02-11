import 'package:flutter/material.dart';
import 'package:novel_viewer/home_screen.dart';

class NovelViewerApp extends StatelessWidget {
  const NovelViewerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NovelViewer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
