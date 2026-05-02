import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'game_state.dart';
import 'game_screen.dart';

class MainMenu extends StatefulWidget {
  const MainMenu({super.key});
  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  final _nameController = TextEditingController();
  WebSocketChannel? _channel;
  List<Map<String, dynamic>> _onlinePlayers = [];
  String _error = '';
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    _connectWs();
  }

  void _connectWs() {
    setState(() => _connecting = true);
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('wss://pico3.ieti.site'),
      );
      _channel!.stream.listen(
        (msg) {
          final json = jsonDecode(msg);
          if (json['type'] == 'STATE') {
            setState(() {
              _onlinePlayers = List<Map<String, dynamic>>.from(json['players'] ?? []);
              _connecting = false;
            });
          } else if (json['type'] == 'JOINED') {
            final playerId = json['playerId'] as String;
            Navigator.of(context).pushReplacement(MaterialPageRoute(
              builder: (_) => GameScreen(
                channel: _channel!,
                playerId: playerId,
              ),
            ));
          } else if (json['type'] == 'ERROR') {
            setState(() => _error = json['message'] ?? 'Error');
          }
        },
        onError: (_) => setState(() {
          _error = 'Error de conexión';
          _connecting = false;
        }),
        onDone: () => setState(() {
          _error = 'Conexión cerrada';
          _connecting = false;
        }),
      );
    } catch (e) {
      setState(() {
        _error = 'No se pudo conectar';
        _connecting = false;
      });
    }
  }

  void _join() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Introduce un nombre.');
      return;
    }
    if (_channel == null) {
      setState(() => _error = 'Sin conexión al servidor.');
      return;
    }
    setState(() => _error = '');
    _channel!.sink.add(jsonEncode({'type': 'JOIN', 'name': name}));
  }

  @override
  Widget build(BuildContext context) {
    final colors = [Colors.cyanAccent, Colors.pinkAccent, Colors.greenAccent, Colors.amberAccent];
    return Scaffold(
      backgroundColor: const Color(0xFF050514),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('OCEAN PARK',
                          style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.cyanAccent,
                              letterSpacing: 4)),
                      const SizedBox(height: 8),
                      const Text('Introduce tu nombre para jugar',
                          style: TextStyle(color: Color(0xFF99DDDD))),
                      const SizedBox(height: 30),
                      TextField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Nombre del jugador...',
                          hintStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: const Color(0xFF111133),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none),
                        ),
                        onSubmitted: (_) => _join(),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _connecting ? null : _join,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyanAccent,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('▶  ENTRAR AL JUEGO',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      if (_error.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(_error, style: const TextStyle(color: Colors.redAccent)),
                      ],
                      if (_connecting) ...[
                        const SizedBox(height: 10),
                        const Row(children: [
                          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 8),
                          Text('Conectando...', style: TextStyle(color: Colors.grey)),
                        ]),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 40),
                SizedBox(
                  width: 200,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      Text('EN LÍNEA',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.cyanAccent,
                              letterSpacing: 2)),
                      const SizedBox(height: 14),
                      if (_onlinePlayers.isEmpty)
                        const Text('Nadie conectado aún',
                            style: TextStyle(color: Colors.grey))
                      else
                        ..._onlinePlayers.asMap().entries.map((e) {
                          final color = colors[e.key % colors.length];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(children: [
                              Text('● ', style: TextStyle(color: color)),
                              Text(e.value['name'] ?? '',
                                  style: TextStyle(color: color)),
                            ]),
                          );
                        }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
