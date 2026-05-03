import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/game_models.dart';

class WebSocketService extends ChangeNotifier {
  WebSocketService({this.serverUrl = 'wss://pico3.ieti.site'});

  final String serverUrl;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;

  bool _connected = false;
  String _status = 'Desconectado';
  GameState? _latestState;

  bool get connected => _connected;
  String get status => _status;
  GameState? get latestState => _latestState;

  void connect() {
    _reconnectTimer?.cancel();
    _openSocket();
  }

  void _openSocket() {
    _status = 'Conectando...';
    notifyListeners();

    try {
      _channel = WebSocketChannel.connect(Uri.parse(serverUrl));
      _connected = true;
      _status = 'Conectado';
      notifyListeners();

      // El servidor actual emite STATE a todos los sockets abiertos.
      // No enviamos JOIN para no crear un jugador fantasma.
      _channel!.sink.add(jsonEncode({'type': 'SPECTATE'}));

      _subscription = _channel!.stream.listen(
        (data) => _handleMessage(data),
        onError: (error) {
          debugPrint('[WS] Error: $error');
          _disconnectAndRetry();
        },
        onDone: _disconnectAndRetry,
        cancelOnError: true,
      );
    } catch (error) {
      debugPrint('[WS] No se pudo conectar: $error');
      _disconnectAndRetry();
    }
  }

  void _handleMessage(dynamic data) {
    try {
      final decoded = jsonDecode(data.toString());
      if (decoded is! Map<String, dynamic>) return;

      final type = decoded['type']?.toString();
      if (type == 'STATE') {
        _latestState = GameState.fromJson(decoded);
        _status = 'En vivo';
        notifyListeners();
      } else if (type == 'ERROR') {
        _status = decoded['message']?.toString() ?? 'Error del servidor';
        notifyListeners();
      }
    } catch (error) {
      debugPrint('[WS] Mensaje ignorado: $error');
    }
  }

  void _disconnectAndRetry() {
    _connected = false;
    _status = 'Reconectando...';
    notifyListeners();

    _subscription?.cancel();
    _subscription = null;
    _channel = null;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), _openSocket);
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}
