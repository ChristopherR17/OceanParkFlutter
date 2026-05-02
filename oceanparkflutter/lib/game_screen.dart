import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'game_state.dart';

// World constants matching the server/client
const double kMapY = 673.0;
const double kTileSize = 23.0;
const double kMapX = -75.0;

// Player colors
const _playerColors = [Colors.cyanAccent, Colors.pinkAccent, Colors.greenAccent, Colors.amberAccent];

class GameScreen extends StatefulWidget {
  final WebSocketChannel channel;
  final String playerId;

  const GameScreen({super.key, required this.channel, required this.playerId});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  GameState? _state;
  late AnimationController _animController;
  String _lastDir = 'NONE';
  bool _jumpWasPressed = false;

  // Touch state
  bool _touchLeft = false;
  bool _touchRight = false;
  bool _touchJump = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat();

    widget.channel.stream.listen((msg) {
      final json = jsonDecode(msg);
      if (json['type'] == 'STATE') {
        setState(() => _state = GameState.fromJson(json));
      }
    });
  }

  void _sendMove(String dir, bool jump) {
    if (dir != _lastDir || jump) {
      widget.channel.sink.add(jsonEncode({'type': 'MOVE', 'dir': dir, 'jump': jump}));
      _lastDir = dir;
    }
  }

  void _processInput() {
    String dir = 'NONE';
    if (_touchLeft) dir = 'LEFT';
    if (_touchRight) dir = 'RIGHT';
    bool jump = _touchJump && !_jumpWasPressed;
    _jumpWasPressed = _touchJump;
    _sendMove(dir, jump);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF547BAF),
      body: AnimatedBuilder(
        animation: _animController,
        builder: (context, _) {
          _processInput();
          return Stack(
            children: [
              // Game world
              CustomPaint(
                painter: _GamePainter(
                  state: _state,
                  playerId: widget.playerId,
                  animTime: _animController.value,
                ),
                child: const SizedBox.expand(),
              ),
              // HUD controls
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: _buildHUD(),
              ),
              // Level indicator
              if (_state != null)
                Positioned(
                  top: 12, left: 0, right: 0,
                  child: Center(
                    child: Text(
                      'Nivel ${_state!.level}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(blurRadius: 4, color: Colors.black)]),
                    ),
                  ),
                ),
              // Players HUD list
              if (_state != null)
                Positioned(
                  top: 12, right: 12,
                  child: _buildPlayersHUD(),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlayersHUD() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: _state!.players.asMap().entries.map((e) {
        final p = e.value;
        final color = _playerColors[e.key % _playerColors.length];
        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (p.hasKey) const Text('🗝️ ', style: TextStyle(fontSize: 12)),
            if (p.hasFinishedLevel) const Text('✅ ', style: TextStyle(fontSize: 12)),
            Text(p.name, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ]),
        );
      }).toList(),
    );
  }

  Widget _buildHUD() {
    const btnSize = 56.0;
    const margin = 20.0;
    return Padding(
      padding: const EdgeInsets.all(margin),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            _HudButton(
              label: '◀',
              onDown: () { _touchLeft = true; },
              onUp: () { _touchLeft = false; },
              size: btnSize,
            ),
            const SizedBox(width: 12),
            _HudButton(
              label: '▶',
              onDown: () { _touchRight = true; },
              onUp: () { _touchRight = false; },
              size: btnSize,
            ),
          ]),
          _HudButton(
            label: 'SALTAR',
            onDown: () { _touchJump = true; },
            onUp: () { _touchJump = false; },
            size: btnSize,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }
}

class _HudButton extends StatefulWidget {
  final String label;
  final VoidCallback onDown;
  final VoidCallback onUp;
  final double size;

  const _HudButton({required this.label, required this.onDown, required this.onUp, required this.size});

  @override
  State<_HudButton> createState() => _HudButtonState();
}

class _HudButtonState extends State<_HudButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) { setState(() => _pressed = true); widget.onDown(); },
      onTapUp: (_) { setState(() => _pressed = false); widget.onUp(); },
      onTapCancel: () { setState(() => _pressed = false); widget.onUp(); },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: _pressed ? Colors.white24 : Colors.black45,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white30),
        ),
        child: Center(
          child: Text(widget.label,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

// ─── Painter ────────────────────────────────────────────────────────────────

class _GamePainter extends CustomPainter {
  final GameState? state;
  final String playerId;
  final double animTime; // 0..1 repeating

  _GamePainter({required this.state, required this.playerId, required this.animTime});

  @override
  void paint(Canvas canvas, Size size) {
    if (state == null) return;

    // Find local player for camera
    PlayerState? localPlayer;
    for (final p in state!.players) {
      if (p.id == playerId) { localPlayer = p; break; }
    }

    // World height (approximate, matches server/client)
    const worldHeight = 30 * kTileSize + kMapY; // ~1363

    // Camera: center on local player
    double camX = size.width / 2;
    double camY = size.height / 2;
    double offsetX = 0, offsetY = 0;

    if (localPlayer != null) {
      final wx = localPlayer.x;
      final wy = worldHeight - localPlayer.y - 16;
      offsetX = camX - wx;
      offsetY = camY - wy;
    }

    canvas.save();
    canvas.translate(offsetX, offsetY);

    _drawGrid(canvas, worldHeight);
    _drawDoor(canvas, worldHeight);
    _drawKey(canvas, worldHeight);
    _drawPlayers(canvas, worldHeight);

    canvas.restore();
  }

  void _drawGrid(Canvas canvas, double worldHeight) {
    // Draw a simple ground/platform representation
    final paint = Paint()..color = const Color(0xFF3A5A3A);
    // Ground platform (approximate from server fallback)
    final platforms = [
      Rect.fromLTWH(kMapX + 1 * kTileSize, worldHeight - (kMapY + 26 * kTileSize) - kTileSize, 18 * kTileSize, kTileSize),
      Rect.fromLTWH(kMapX + 1 * kTileSize, worldHeight - (kMapY + 27 * kTileSize) - kTileSize, 18 * kTileSize, kTileSize),
      Rect.fromLTWH(kMapX + 1 * kTileSize, worldHeight - (kMapY + 26 * kTileSize) - kTileSize * 2, 7 * kTileSize, kTileSize),
    ];

    // Draw a simple background world rect
    canvas.drawRect(
      Rect.fromLTWH(kMapX, worldHeight - kMapY - 30 * kTileSize, 35 * kTileSize, 30 * kTileSize),
      Paint()..color = const Color(0xFF1A2A3A),
    );

    for (final r in platforms) {
      canvas.drawRect(r, paint);
      canvas.drawRect(r, Paint()..color = const Color(0xFF5A8A5A)..style = PaintingStyle.stroke..strokeWidth = 1);
    }
  }

  void _drawDoor(Canvas canvas, double worldHeight) {
    final door = state!.door;
    if (door == null) return;

    final drawY = worldHeight - door.y - 72 - (door.open ? 64 : 38);
    final w = door.open ? 64.0 : 54.0;
    final h = door.open ? 64.0 : 38.0;

    final paint = Paint()..color = door.open ? Colors.greenAccent : const Color(0xFF8B4513);
    canvas.drawRect(Rect.fromLTWH(door.x, drawY, w, h), paint);

    // Door frame
    canvas.drawRect(
      Rect.fromLTWH(door.x, drawY, w, h),
      Paint()..color = Colors.brown..style = PaintingStyle.stroke..strokeWidth = 3,
    );

    if (door.open) {
      final tp = TextPainter(
        text: const TextSpan(text: '🚪', style: TextStyle(fontSize: 28)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(door.x + w / 2 - 14, drawY + h / 2 - 14));
    }
  }

  void _drawKey(Canvas canvas, double worldHeight) {
    final key = state!.leafKey;
    if (key == null || key.picked) return;

    final kx = key.x;
    final ky = worldHeight - key.y - 32;

    // Animated bob
    final bob = sin(animTime * 2 * pi) * 3;

    final paint = Paint()..color = Colors.yellowAccent;
    canvas.drawCircle(Offset(kx + 16, ky + 16 + bob), 10, paint);
    canvas.drawRect(Rect.fromLTWH(kx + 22, ky + 12 + bob, 10, 6), paint);
    canvas.drawRect(Rect.fromLTWH(kx + 28, ky + 18 + bob, 4, 4), paint);
  }

  void _drawPlayers(Canvas canvas, double worldHeight) {
    final players = state!.players;
    for (int i = 0; i < players.length; i++) {
      final p = players[i];
      final color = _playerColors[i % _playerColors.length];
      final px = p.x;
      final py = worldHeight - p.y - 32;

      final paint = Paint()..color = color;

      // Body
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(px + 4, py + 8, 24, 22), const Radius.circular(4)),
        paint,
      );

      // Head
      canvas.drawCircle(Offset(px + 16, py + 8), 10, paint);

      // Eyes
      final eyeX = p.facingRight ? px + 20 : px + 12;
      canvas.drawCircle(Offset(eyeX, py + 6), 3, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(eyeX + (p.facingRight ? 1 : -1), py + 6), 1.5, Paint()..color = Colors.black);

      // Key indicator
      if (p.hasKey) {
        final tp = TextPainter(
          text: const TextSpan(text: '🗝️', style: TextStyle(fontSize: 14)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(px + 8, py - 18));
      }

      // Name tag
      final tp = TextPainter(
        text: TextSpan(
          text: p.name,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold,
              shadows: const [Shadow(blurRadius: 3, color: Colors.black)]),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(px + 16 - tp.width / 2, py - 14));

      // Finished indicator
      if (p.hasFinishedLevel) {
        canvas.drawCircle(Offset(px + 16, py + 19), 14,
            Paint()..color = Colors.greenAccent.withOpacity(0.3));
      }
    }
  }

  @override
  bool shouldRepaint(_GamePainter old) => true;
}
