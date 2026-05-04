import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// ─── Constantes del mundo ────────────────────────────────────────────────────
// Servidor: Y-down, kLayerY=673 sumado en todas las coordenadas de objetos.
// Cliente Java (LibGDX Y-up):
//   jx = serverX - kLayerX
//   jy = kWorldH - serverY - spriteH
//   kWorldH = 64*23 + 673 = 2145
//
// Tilemap real: 64 filas × 100 cols
//   Nivel 1 tiles activos: rows 10-34, cols 0-37
//   Nivel 2 tiles activos: rows  0-20, cols 0-33
//
// Viewport por nivel (en coordenadas Java Y-up):
//   L1: jTop=1219, jBot=690,  vW=874 (38 cols), vH=529 (23 rows)
//   L2: jTop=1449, jBot=1012, vW=782 (34 cols), vH=437 (19 rows)

const double kLayerX  = -75.0;
const double kLayerY  = 673.0;
const double kTileSize = 23.0;
const double kWorldH  = 64 * kTileSize + kLayerY; // 2145

// Nivel 1
const double kL1_jTop  = kWorldH - (kLayerY + 10 * kTileSize) - kTileSize; // 1219
const double kL1_jBot  = kWorldH - (kLayerY + 35 * kTileSize);              // 667  (borde INFERIOR fila 34)
const double kL1_viewW = 38 * kTileSize; // 874
const double kL1_viewH = kL1_jTop - kL1_jBot; // 552

// Nivel 2
const double kL2_jTop  = kWorldH - (kLayerY +  0 * kTileSize) - kTileSize; // 1449
const double kL2_jBot  = kWorldH - (kLayerY + 21 * kTileSize);              // 989  (borde INFERIOR fila 20)
const double kL2_viewW = 34 * kTileSize; // 782
const double kL2_viewH = kL2_jTop - kL2_jBot; // 460

const String kWsUrl = 'wss://pico3.ieti.site';

const _playerColors = [
  Color(0xFF00FFFF),
  Color(0xFFFF66CC),
  Color(0xFF66FF66),
  Color(0xFFFFCC33),
];

// ─── Modelos ─────────────────────────────────────────────────────────────────

class PlayerState {
  final String id, name;
  final double x, y;
  final String state;
  final bool facingRight, hasKey, hasFinishedLevel;

  PlayerState.fromJson(Map<String, dynamic> j)
      : id   = j['id'],
        name  = j['name'],
        x     = (j['x'] as num).toDouble(),
        y     = (j['y'] as num).toDouble(),
        state = j['state'] ?? 'IDLE',
        facingRight      = j['facingRight']      ?? true,
        hasKey           = j['hasKey']           ?? false,
        hasFinishedLevel = j['hasFinishedLevel'] ?? false;
}

class GameState {
  final int level;
  final List<PlayerState> players;
  final Map<String, dynamic>? leafKey;
  final Map<String, dynamic>? door;
  final Map<String, dynamic>? button;
  final List<Map<String, dynamic>> movingPlatforms;

  GameState.fromJson(Map<String, dynamic> j)
      : level   = j['level'] ?? 1,
        players = (j['players'] as List? ?? [])
            .map((p) => PlayerState.fromJson(p)).toList(),
        leafKey  = j['leafKey'] != null ? Map<String, dynamic>.from(j['leafKey']) : null,
        door     = j['door']    != null ? Map<String, dynamic>.from(j['door'])    : null,
        button   = j['button']  != null ? Map<String, dynamic>.from(j['button'])  : null,
        movingPlatforms = (j['movingPlatforms'] as List? ?? [])
            .map((p) => Map<String, dynamic>.from(p)).toList();
}

// ─── Assets ──────────────────────────────────────────────────────────────────

class _Assets {
  final ui.Image tileset;
  final List<List<int>> tileMapL1;
  final List<List<int>> tileMapL2;
  final ui.Image mushroomIdle, mushroomLeft, mushroomRight;
  final ui.Image doorClosed, doorOpen;
  final ui.Image leafKey, button;

  _Assets({
    required this.tileset,
    required this.tileMapL1, required this.tileMapL2,
    required this.mushroomIdle, required this.mushroomLeft, required this.mushroomRight,
    required this.doorClosed, required this.doorOpen,
    required this.leafKey, required this.button,
  });

  static Future<ui.Image> _img(String p) async {
    final d = await rootBundle.load(p);
    final c = await ui.instantiateImageCodec(d.buffer.asUint8List());
    return (await c.getNextFrame()).image;
  }

  static List<List<int>> _map(String json) {
    final raw = (jsonDecode(json) as Map<String, dynamic>)['tileMap'] as List;
    return raw.map((r) => (r as List).map((v) => v as int).toList()).toList();
  }

  static Future<_Assets> load() async {
    final imgs = await Future.wait([
      _img('assets/map/tileset_cueva_2.png'),
      _img('assets/sprites/Mushroom Idle.png'),
      _img('assets/sprites/Mushroom Left.png'),
      _img('assets/sprites/Mushroom Right.png'),
      _img('assets/sprites/Door Closed.png'),
      _img('assets/sprites/Door Open.png'),
      _img('assets/sprites/Leaf Key.png'),
      _img('assets/sprites/Button.png'),
    ]);
    final maps = await Future.wait([
      rootBundle.loadString('assets/tilemaps/level_000_layer_000.json'),
      rootBundle.loadString('assets/tilemaps/level_001_layer_000.json'),
    ]);
    return _Assets(
      tileset: imgs[0],
      mushroomIdle: imgs[1], mushroomLeft: imgs[2], mushroomRight: imgs[3],
      doorClosed: imgs[4], doorOpen: imgs[5],
      leafKey: imgs[6], button: imgs[7],
      tileMapL1: _map(maps[0]), tileMapL2: _map(maps[1]),
    );
  }

  List<List<int>> tileMapForLevel(int level) => level == 2 ? tileMapL2 : tileMapL1;
}

// ─── App ─────────────────────────────────────────────────────────────────────

void main() => runApp(const OceanParkApp());

class OceanParkApp extends StatelessWidget {
  const OceanParkApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Ocean Park – Espectador',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: const SpectatorScreen(),
      );
}

// ─── Pantalla principal ───────────────────────────────────────────────────────

class SpectatorScreen extends StatefulWidget {
  const SpectatorScreen({super.key});
  @override
  State<SpectatorScreen> createState() => _SpectatorScreenState();
}

class _SpectatorScreenState extends State<SpectatorScreen>
    with SingleTickerProviderStateMixin {
  WebSocketChannel? _channel;
  GameState?        _gameState;
  _Assets?          _assets;
  String            _status = 'Cargando...';
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
    _Assets.load().then((a) {
      if (!mounted) return;
      setState(() { _assets = a; _status = ''; });
      _connect();
    }).catchError((e) {
      if (!mounted) return;
      setState(() => _status = 'Error assets: $e');
    });
  }

  void _connect() {
    setState(() => _status = 'Conectando...');
    try {
      _channel = WebSocketChannel.connect(Uri.parse(kWsUrl));
      _channel!.stream.listen(
        (msg) {
          final json = jsonDecode(msg as String);
          if (json['type'] == 'STATE') {
            setState(() { _gameState = GameState.fromJson(json); _status = ''; });
          }
        },
        onError: (_) => setState(() => _status = 'Error de conexión'),
        onDone:  () => setState(() => _status = 'Desconectado'),
      );
    } catch (_) { setState(() => _status = 'No se pudo conectar'); }
  }

  @override
  void dispose() { _anim.dispose(); _channel?.sink.close(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Column(children: [
      _buildTopBar(),
      Expanded(
        child: _assets == null
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                const CircularProgressIndicator(color: Colors.cyanAccent),
                const SizedBox(height: 16),
                Text(_status, style: const TextStyle(color: Colors.white70)),
              ]))
            : AnimatedBuilder(
                animation: _anim,
                builder: (_, __) => LayoutBuilder(
                  builder: (_, c) => CustomPaint(
                    painter: _GamePainter(
                      assets: _assets!, state: _gameState,
                      animTime: _anim.value, viewW: c.maxWidth, viewH: c.maxHeight,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
      ),
    ]),
  );

  Widget _buildTopBar() => Container(
    color: const Color(0xFF0A0A1A),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(children: [
      const Text('🌊 OCEAN PARK',
          style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold,
              fontSize: 16, letterSpacing: 2)),
      const Spacer(),
      if (_gameState != null)
        Text('Nivel ${_gameState!.level}', style: const TextStyle(color: Colors.white70)),
      const SizedBox(width: 16),
      if (_status.isNotEmpty)
        Row(children: [
          const SizedBox(width: 12, height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent)),
          const SizedBox(width: 8),
          Text(_status, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ])
      else
        const Icon(Icons.circle, color: Colors.greenAccent, size: 10),
      if (_gameState != null)
        ..._gameState!.players.asMap().entries.map((e) {
          final color = _playerColors[e.key % _playerColors.length];
          final p = e.value;
          return Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.circle, color: color, size: 8),
              const SizedBox(width: 4),
              Text(p.name, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
              if (p.hasKey)           const Text(' 🗝️', style: TextStyle(fontSize: 11)),
              if (p.hasFinishedLevel) const Text(' ✅',  style: TextStyle(fontSize: 11)),
            ]),
          );
        }),
    ]),
  );
}

// ─── Painter ─────────────────────────────────────────────────────────────────

class _GamePainter extends CustomPainter {
  final _Assets    assets;
  final GameState? state;
  final double     animTime;
  final double     viewW, viewH;

  _GamePainter({required this.assets, required this.state,
                required this.animTime, required this.viewW, required this.viewH});

  late double _scale, _offX, _offY;
  late double _jTop, _jBot, _vW, _vH;

  void _computeTransform(int level) {
    // Seleccionar viewport según nivel
    if (level == 2) {
      _jTop = kL2_jTop; _jBot = kL2_jBot; _vW = kL2_viewW; _vH = kL2_viewH;
    } else {
      _jTop = kL1_jTop; _jBot = kL1_jBot; _vW = kL1_viewW; _vH = kL1_viewH;
    }
    _scale = min(viewW / _vW, viewH / _vH);
    _offX  = (viewW - _vW * _scale) / 2;
    _offY  = (viewH - _vH * _scale) / 2;
  }

  /// Convierte coordenadas servidor → píxeles Flutter.
  ///   jx = serverX - kLayerX          (Java screen X, origen col-0)
  ///   jy = kWorldH - serverY - spriteH (Java screen Y, Y-up)
  ///   fx = jx * scale + offX           (col-0 queda en offX)
  ///   fy = (jTop - jy) * scale + offY  (jTop queda en offY=top)
  Offset _ts(double sx, double sy, {double spriteH = 0}) {
    final jx = sx - kLayerX;
    final jy = kWorldH - sy - spriteH;
    return Offset(
      jx * _scale + _offX,
      (_jTop - jy) * _scale + _offY,
    );
  }

  double _s(double v) => v * _scale;

  @override
  void paint(Canvas canvas, Size size) {
    final level = state?.level ?? 1;
    _computeTransform(level);

    canvas.drawRect(Rect.fromLTWH(0, 0, viewW, viewH),
        Paint()..color = const Color(0xFF547BAF));

    _drawTileMap(canvas, level);
    _drawMovingPlatforms(canvas);
    _drawButton(canvas);
    _drawDoor(canvas);
    _drawKey(canvas);
    _drawPlayers(canvas);
  }

  // ── Tilemap ────────────────────────────────────────────────────────────────

  void _drawTileMap(Canvas canvas, int level) {
    final tileMap     = assets.tileMapForLevel(level);
    final tilesetCols = assets.tileset.width ~/ kTileSize.toInt();
    final paint       = Paint()..filterQuality = FilterQuality.none;

    for (int row = 0; row < tileMap.length; row++) {
      for (int col = 0; col < tileMap[row].length; col++) {
        final id = tileMap[row][col];
        if (id < 0) continue;
        if (level == 2 && id == 145) continue; // plataforma móvil, se dibuja aparte

        final src = Rect.fromLTWH(
          (id % tilesetCols) * kTileSize,
          (id ~/ tilesetCols) * kTileSize,
          kTileSize, kTileSize,
        );
        // serverY del borde superior del tile = kLayerY + row*kTileSize
        // spriteH = kTileSize para que el borde superior quede arriba en Flutter
        final tl  = _ts(kLayerX + col * kTileSize, kLayerY + row * kTileSize, spriteH: kTileSize);
        canvas.drawImageRect(assets.tileset, src,
            Rect.fromLTWH(tl.dx, tl.dy, _s(kTileSize), _s(kTileSize)), paint);
      }
    }
  }

  // ── Plataformas móviles ────────────────────────────────────────────────────

  void _drawMovingPlatforms(Canvas canvas) {
    if (state == null) return;
    final tilesetCols = assets.tileset.width ~/ kTileSize.toInt();
    final paint = Paint()..filterQuality = FilterQuality.none;

    for (final mp in state!.movingPlatforms) {
      final double mpX = (mp['x'] as num).toDouble();
      final double mpY = (mp['y'] as num).toDouble();
      final double mpW = (mp['width']  as num).toDouble();
      final double mpH = (mp['height'] as num).toDouble();
      final int tileId = (mp['tileId'] as num).toInt();

      final src = Rect.fromLTWH(
        (tileId % tilesetCols) * kTileSize,
        (tileId ~/ tilesetCols) * kTileSize,
        kTileSize, kTileSize,
      );
      final tileCount = (mpW / kTileSize).round();
      for (int i = 0; i < tileCount; i++) {
        final tl = _ts(mpX + i * kTileSize, mpY, spriteH: mpH);
        canvas.drawImageRect(assets.tileset, src,
            Rect.fromLTWH(tl.dx, tl.dy, _s(kTileSize), _s(mpH)), paint);
      }
    }
  }

  // ── Botón ─────────────────────────────────────────────────────────────────

  void _drawButton(Canvas canvas) {
    final btn = state?.button;
    if (btn == null) return;
    final double bx = (btn['x'] as num).toDouble();
    final double by = (btn['y'] as num).toDouble();
    final double bw = (btn['width']  as num? ?? 20).toDouble();
    final double bh = (btn['height'] as num? ?? 22).toDouble();
    final bool pressed = btn['pressed'] ?? false;

    final tl  = _ts(bx, by, spriteH: bh);
    final dst = Rect.fromLTWH(tl.dx, tl.dy, _s(bw), _s(bh));
    final paint = Paint()..filterQuality = FilterQuality.none;
    if (pressed) paint.colorFilter = const ColorFilter.mode(Color(0x99999999), BlendMode.multiply);
    canvas.drawImageRect(assets.button, Rect.fromLTWH(0, 0, 20, 22), dst, paint);
  }

  // ── Puerta ─────────────────────────────────────────────────────────────────

  void _drawDoor(Canvas canvas) {
    final door = state?.door;
    if (door == null) return;
    final bool   open  = door['open'] ?? false;
    final double dx    = (door['x'] as num).toDouble();
    final double dy    = (door['y'] as num).toDouble();
    final double doorH = open ? 64.0 : 38.0;
    final double doorW = open ? 64.0 : 54.0;

    // GameScreen.java: drawY = worldHeight - doorY - 72 - doorH
    // → spriteH = 72 + doorH  (el 72 es un offset visual del cliente Java)
    final tl = _ts(dx, dy, spriteH: 72 + doorH);
    final img = open ? assets.doorOpen : assets.doorClosed;
    canvas.drawImageRect(img, Rect.fromLTWH(0, 0, doorW, doorH),
        Rect.fromLTWH(tl.dx, tl.dy, _s(doorW), _s(doorH)),
        Paint()..filterQuality = FilterQuality.none);
  }

  // ── Llave ──────────────────────────────────────────────────────────────────

  void _drawKey(Canvas canvas) {
    final key = state?.leafKey;
    if (key == null || (key['picked'] ?? false)) return;
    final double kx  = (key['x'] as num).toDouble();
    final double ky  = (key['y'] as num).toDouble();
    final double bob = sin(animTime * 2 * pi) * _s(3);
    final tl    = _ts(kx, ky, spriteH: 32);
    final frame = (animTime * 2).floor() % 2;
    canvas.drawImageRect(assets.leafKey, Rect.fromLTWH(frame * 32.0, 0, 32, 32),
        Rect.fromLTWH(tl.dx, tl.dy + bob, _s(32), _s(32)),
        Paint()..filterQuality = FilterQuality.none);
  }

  // ── Jugadores ──────────────────────────────────────────────────────────────

  void _drawPlayers(Canvas canvas) {
    if (state == null) return;
    for (int i = 0; i < state!.players.length; i++) {
      _drawPlayer(canvas, state!.players[i], i);
    }
  }

  void _drawPlayer(Canvas canvas, PlayerState p, int idx) {
    final color = _playerColors[idx % _playerColors.length];
    final tl  = _ts(p.x, p.y, spriteH: 32);
    final dst = Rect.fromLTWH(tl.dx, tl.dy, _s(32), _s(32));

    final ui.Image sheet = (p.state == 'RUN' || p.state == 'JUMP')
        ? (p.facingRight ? assets.mushroomRight : assets.mushroomLeft)
        : assets.mushroomIdle;

    final frameCount = sheet.width ~/ 32;
    final frame      = (animTime * frameCount * 8).floor() % frameCount;
    final src        = Rect.fromLTWH(frame * 32.0, 0, 32, 32);
    final basePaint  = Paint()..filterQuality = FilterQuality.none;

    canvas.drawImageRect(sheet, src, dst, basePaint);
    canvas.drawImageRect(sheet, src, dst,
        Paint()
          ..filterQuality = FilterQuality.none
          ..colorFilter = ColorFilter.mode(color.withOpacity(0.3), BlendMode.srcATop));

    if (p.hasKey) {
      canvas.drawImageRect(assets.leafKey, Rect.fromLTWH(0, 0, 32, 32),
          Rect.fromLTWH(tl.dx, tl.dy - _s(20), _s(20), _s(20)), basePaint);
    }

    if (p.hasFinishedLevel) {
      canvas.drawCircle(Offset(tl.dx + _s(16), tl.dy + _s(16)), _s(20),
          Paint()
            ..color = Colors.greenAccent.withOpacity(0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = _s(2));
    }

    final tp = TextPainter(
      text: TextSpan(text: p.name, style: TextStyle(
        color: color, fontSize: _s(9).clamp(8.0, 14.0), fontWeight: FontWeight.bold,
        shadows: const [Shadow(blurRadius: 3, color: Colors.black)],
      )),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(tl.dx + _s(16) - tp.width / 2, tl.dy - tp.height - _s(2)));
  }

  @override
  bool shouldRepaint(_GamePainter old) => true;
}
