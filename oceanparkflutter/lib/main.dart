import 'package:flutter/material.dart';
import 'widgets/game_widget.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OceanParkSpectatorApp());
}

class OceanParkSpectatorApp extends StatelessWidget {
  const OceanParkSpectatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ocean Park - Espectador',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.cyanAccent,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF020208),
      ),
      home: const OceanParkLiveScreen(),
    );
  }
}

class OceanParkLiveScreen extends StatelessWidget {
  const OceanParkLiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: GameWidget(),
      ),
    );
  }
}
