import 'package:flutter/material.dart';
import 'main_menu.dart';

void main() {
  runApp(const OceanParkApp());
}

class OceanParkApp extends StatelessWidget {
  const OceanParkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ocean Park',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const MainMenu(),
    );
  }
}
