import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/game_models.dart';
import '../services/websocket_service.dart';

// Rutas según tu pubspec actual.
const String kGameDataPath = 'assets/game_data.json';
const String kTilesetPath = 'assets/map/tileset_cueva_2.png';
const String kMushroomIdlePath = 'assets/sprites/Mushroom Idle.png';
const String kMushroomLeftPath = 'assets/sprites/Mushroom Left.png';
const String kMushroomRightPath = 'assets/sprites/Mushroom Right.png';
const String kLeafKeyPath = 'assets/sprites/Leaf Key.png';
const String kDoorClosedPath = 'assets/sprites/Door Closed.png';
const String kDoorOpenPath = 'assets/sprites/Door Open.png';
const String kButtonPath = 'assets/sprites/Button.png';

// Estos valores deben coincidir con el servidor.
const double kServerLayerX = -75.0;
const double kServerLayerY = 673.0;
const double kFallbackTileSize = 23.0;

class GameWidget extends StatefulWidget {
  const GameWidget({super.key});

  @override
  State<GameWidget> createState() => _GameWidgetState();
}

class _GameWidgetState extends State<GameWidget> with SingleTickerProviderStateMixin {
  final WebSocketService _ws = WebSocketService();
  final TransformationController _transformController = TransformationController();
  late final AnimationController _animation;

  final Map<int, Future<OceanAssets>> _assetsByLevel = {};
  Size? _lastViewportSize;
  int? _lastCenteredLevel;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
    _assetsByLevel[1] = OceanAssets.load(1);
    _ws.addListener(_onStateChanged);
    _ws.connect();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ws.removeListener(_onStateChanged);
    _ws.dispose();
    _transformController.dispose();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _ws.latestState;
    final level = state?.level ?? 1;
    final assetsFuture = _assetsByLevel.putIfAbsent(level, () => OceanAssets.load(level));

    return FutureBuilder<OceanAssets>(
      future: assetsFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorView(message: 'Error cargando assets: ${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final assets = snapshot.data!;

        return Column(
          children: [
            _TopBar(
              status: _ws.status,
              connected: _ws.connected,
              level: state?.level,
              players: state?.players.length ?? 0,
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
                  _applyInitialCenteredTransform(assets, viewportSize);

                  return ClipRect(
                    child: InteractiveViewer(
                      constrained: false,
                      minScale: 0.1,
                      maxScale: 10,
                      boundaryMargin: const EdgeInsets.all(600),
                      transformationController: _transformController,
                      child: AnimatedBuilder(
                        animation: _animation,
                        builder: (_, __) {
                          return CustomPaint(
                            size: Size(assets.mapWidth, assets.mapHeight),
                            painter: OceanGamePainter(
                              assets: assets,
                              state: state,
                              animationValue: _animation.value,
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _applyInitialCenteredTransform(OceanAssets assets, Size viewportSize) {
    if (_lastViewportSize == viewportSize && _lastCenteredLevel == assets.level) return;
    _lastViewportSize = viewportSize;
    _lastCenteredLevel = assets.level;

    final scale = math.min(
      viewportSize.width / assets.mapWidth,
      viewportSize.height / assets.mapHeight,
    ).clamp(0.05, 10.0).toDouble();

    final dx = (viewportSize.width - assets.mapWidth * scale) / 2;
    final dy = (viewportSize.height - assets.mapHeight * scale) / 2;

    _transformController.value = Matrix4.identity()
      ..translate(dx, dy)
      ..scale(scale);
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.status,
    required this.connected,
    required this.level,
    required this.players,
  });

  final String status;
  final bool connected;
  final int? level;
  final int players;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      color: const Color(0xDD020208),
      child: Row(
        children: [
          Icon(
            connected ? Icons.circle : Icons.error,
            size: 12,
            color: connected ? Colors.greenAccent : Colors.redAccent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Ocean Park - $status',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Text('Nivel ${level ?? '-'}'),
          const SizedBox(width: 16),
          Text('Jugadores: $players'),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}

class OceanAssets {
  OceanAssets({
    required this.level,
    required this.tileMap,
    required this.tileset,
    required this.mushroomIdle,
    required this.mushroomLeft,
    required this.mushroomRight,
    required this.leafKey,
    required this.doorClosed,
    required this.doorOpen,
    required this.button,
    required this.layerX,
    required this.layerY,
    required this.tileSize,
    required this.minCol,
    required this.maxCol,
    required this.minRow,
    required this.maxRow,
  });

  final int level;
  final List<List<int>> tileMap;
  final ui.Image tileset;
  final ui.Image mushroomIdle;
  final ui.Image mushroomLeft;
  final ui.Image mushroomRight;
  final ui.Image leafKey;
  final ui.Image doorClosed;
  final ui.Image doorOpen;
  final ui.Image button;
  final double layerX;
  final double layerY;
  final double tileSize;
  final int minCol;
  final int maxCol;
  final int minRow;
  final int maxRow;

  double get mapWidth => (maxCol - minCol + 1) * tileSize;
  double get mapHeight => (maxRow - minRow + 1) * tileSize;

  double worldToCanvasX(double worldX) => worldX - (layerX + minCol * tileSize);

  // El servidor usa coordenadas Y-down y suma 673. Flutter también pinta Y-down.
  // Por eso NO invertimos Y; solo quitamos el offset del servidor y el recorte superior.
  double worldToCanvasY(double worldY) => worldY - layerY - minRow * tileSize;

  static Future<OceanAssets> load(int level) async {
    var tileSize = kFallbackTileSize;

    try {
      final gameData = jsonDecode(await rootBundle.loadString(kGameDataPath)) as Map<String, dynamic>;
      final levels = gameData['levels'] as List<dynamic>;
      final index = (level - 1).clamp(0, levels.length - 1).toInt();
      final levelData = levels[index] as Map<String, dynamic>;
      final layer = (levelData['layers'] as List<dynamic>).first as Map<String, dynamic>;
      tileSize = (layer['tilesWidth'] as num? ?? kFallbackTileSize).toDouble();
    } catch (_) {
      // Usar constantes fallback.
    }

    final levelIndex = (level - 1).clamp(0, 999).toInt();
    final tileMapPath = 'assets/tilemaps/level_${levelIndex.toString().padLeft(3, '0')}_layer_000.json';
    final mapJson = jsonDecode(await rootBundle.loadString(tileMapPath)) as Map<String, dynamic>;
    final rawMap = mapJson['tileMap'] as List<dynamic>;
    final tileMap = rawMap
        .map((row) => (row as List<dynamic>).map((value) => (value as num).toInt()).toList())
        .toList();

    var minCol = 1 << 30;
    var maxCol = -1;
    var minRow = 1 << 30;
    var maxRow = -1;

    for (var row = 0; row < tileMap.length; row++) {
      for (var col = 0; col < tileMap[row].length; col++) {
        if (tileMap[row][col] >= 0) {
          minCol = math.min(minCol, col);
          maxCol = math.max(maxCol, col);
          minRow = math.min(minRow, row);
          maxRow = math.max(maxRow, row);
        }
      }
    }

    if (maxCol < minCol || maxRow < minRow) {
      minCol = 0;
      minRow = 0;
      maxCol = tileMap.isEmpty ? 0 : tileMap.map((r) => r.length).reduce(math.max) - 1;
      maxRow = tileMap.length - 1;
    }

    final loaded = await Future.wait<ui.Image>([
      _loadImage(kTilesetPath),
      _loadImage(kMushroomIdlePath),
      _loadImage(kMushroomLeftPath),
      _loadImage(kMushroomRightPath),
      _loadImage(kLeafKeyPath),
      _loadImage(kDoorClosedPath),
      _loadImage(kDoorOpenPath),
      _loadImage(kButtonPath),
    ]);

    return OceanAssets(
      level: level,
      tileMap: tileMap,
      tileset: loaded[0],
      mushroomIdle: loaded[1],
      mushroomLeft: loaded[2],
      mushroomRight: loaded[3],
      leafKey: loaded[4],
      doorClosed: loaded[5],
      doorOpen: loaded[6],
      button: loaded[7],
      layerX: kServerLayerX,
      layerY: kServerLayerY,
      tileSize: tileSize,
      minCol: minCol,
      maxCol: maxCol,
      minRow: minRow,
      maxRow: maxRow,
    );
  }

  static Future<ui.Image> _loadImage(String path) async {
    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}

class OceanGamePainter extends CustomPainter {
  OceanGamePainter({
    required this.assets,
    required this.state,
    required this.animationValue,
  });

  final OceanAssets assets;
  final GameState? state;
  final double animationValue;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF568BB1));
    _drawMap(canvas);
    _drawDoor(canvas);
    _drawLeafKey(canvas);
    _drawButton(canvas);
    _drawMovingPlatforms(canvas);
    _drawPlayers(canvas);

    if (state == null) {
      _drawCenteredText(canvas, size, 'Esperando estado del servidor...');
    }
  }

  void _drawMap(Canvas canvas) {
    final colsInTileset = assets.tileset.width ~/ assets.tileSize;
    if (colsInTileset <= 0) return;

    final paint = Paint()..filterQuality = FilterQuality.none;

    for (var row = assets.minRow; row <= assets.maxRow; row++) {
      if (row < 0 || row >= assets.tileMap.length) continue;
      final currentRow = assets.tileMap[row];

      for (var col = assets.minCol; col <= assets.maxCol; col++) {
        if (col < 0 || col >= currentRow.length) continue;
        final id = currentRow[col];
        if (id < 0) continue;
        if (assets.level == 2 && id == 145) continue; // La plataforma móvil se dibuja desde el servidor.

        _drawTile(canvas, id, (col - assets.minCol) * assets.tileSize, (row - assets.minRow) * assets.tileSize, paint);
      }
    }
  }

  void _drawTile(Canvas canvas, int tileId, double x, double y, Paint paint, {double? height}) {
    final colsInTileset = assets.tileset.width ~/ assets.tileSize;
    if (colsInTileset <= 0 || tileId < 0) return;

    final srcCol = tileId % colsInTileset;
    final srcRow = tileId ~/ colsInTileset;
    final src = Rect.fromLTWH(
      srcCol * assets.tileSize,
      srcRow * assets.tileSize,
      assets.tileSize,
      assets.tileSize,
    );
    final dst = Rect.fromLTWH(x, y, assets.tileSize, height ?? assets.tileSize);
    canvas.drawImageRect(assets.tileset, src, dst, paint);
  }

  void _drawPlayers(Canvas canvas) {
    final players = state?.players ?? const <PlayerState>[];
    for (var i = 0; i < players.length; i++) {
      final player = players[i];
      if (player.hasFinishedLevel) continue;

      final sheet = _playerSheet(player);
      const frameW = 32.0;
      const frameH = 32.0;
      final frames = math.max(1, sheet.width ~/ frameW);
      final frame = ((animationValue * 8).floor()) % frames;

      // Sin offset visual: esta era la colocación que encajaba con el Flutter anterior.
      final x = assets.worldToCanvasX(player.x);
      final y = assets.worldToCanvasY(player.y);
      final src = Rect.fromLTWH(frame * frameW, 0, frameW, frameH);
      final dst = Rect.fromLTWH(x, y, frameW, frameH);

      canvas.drawImageRect(sheet, src, dst, Paint()..filterQuality = FilterQuality.none);
      _drawName(canvas, player.name, x + frameW / 2, y - 13, _playerColor(i));
    }
  }

  ui.Image _playerSheet(PlayerState player) {
    if (player.state == 'RUN' || player.state == 'JUMP') {
      return player.facingRight ? assets.mushroomRight : assets.mushroomLeft;
    }
    return assets.mushroomIdle;
  }

  void _drawLeafKey(Canvas canvas) {
    final key = state?.leafKey;
    if (key == null || key.picked) return;

    const frameW = 32.0;
    const frameH = 32.0;
    final frames = math.max(1, assets.leafKey.width ~/ frameW);
    final frame = ((animationValue * 5).floor()) % frames;

    final src = Rect.fromLTWH(frame * frameW, 0, frameW, frameH);
    final dst = Rect.fromLTWH(
      assets.worldToCanvasX(key.x),
      assets.worldToCanvasY(key.y),
      frameW,
      frameH,
    );
    canvas.drawImageRect(assets.leafKey, src, dst, Paint()..filterQuality = FilterQuality.none);
  }

  void _drawDoor(Canvas canvas) {
    final door = state?.door;
    if (door == null) return;

    final x = assets.worldToCanvasX(door.x);

    // Mantener +72: es la compensación que hacía coincidir la puerta con el Flutter anterior.
    final y = assets.worldToCanvasY(door.y) + 72.0;

    if (door.open) {
      const frameW = 64.0;
      const frameH = 64.0;
      final frames = math.max(1, assets.doorOpen.width ~/ frameW);
      final frame = ((animationValue * 5).floor()) % frames;
      final src = Rect.fromLTWH(frame * frameW, 0, frameW, frameH);
      final dst = Rect.fromLTWH(x, y, frameW, frameH);
      canvas.drawImageRect(assets.doorOpen, src, dst, Paint()..filterQuality = FilterQuality.none);
    } else {
      const frameW = 54.0;
      const frameH = 38.0;
      final src = Rect.fromLTWH(0, 0, frameW, frameH);
      final dst = Rect.fromLTWH(x, y, frameW, frameH);
      canvas.drawImageRect(assets.doorClosed, src, dst, Paint()..filterQuality = FilterQuality.none);
    }
  }

  void _drawButton(Canvas canvas) {
    final button = state?.button;
    if (button == null) return;

    final x = assets.worldToCanvasX(button.x);
    final y = assets.worldToCanvasY(button.y);
    final src = Rect.fromLTWH(0, 0, button.width, button.height);
    final dst = Rect.fromLTWH(x, y, button.width, button.height);

    final paint = Paint()..filterQuality = FilterQuality.none;
    if (button.pressed) {
      paint.colorFilter = const ColorFilter.mode(Color(0xAAFFFFFF), BlendMode.modulate);
    }

    canvas.drawImageRect(assets.button, src, dst, paint);
  }

  void _drawMovingPlatforms(Canvas canvas) {
    final platforms = state?.movingPlatforms ?? const <MovingPlatformState>[];
    if (platforms.isEmpty) return;

    final paint = Paint()..filterQuality = FilterQuality.none;

    for (final platform in platforms) {
      final x = assets.worldToCanvasX(platform.x);
      final y = assets.worldToCanvasY(platform.y);
      final tileCount = math.max(1, (platform.width / assets.tileSize).round());

      for (var i = 0; i < tileCount; i++) {
        _drawTile(
          canvas,
          platform.tileId,
          x + i * assets.tileSize,
          y,
          paint,
          height: platform.height,
        );
      }
    }
  }

  void _drawName(Canvas canvas, String name, double cx, double y, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: name,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    painter.paint(canvas, Offset(cx - painter.width / 2, y));
  }

  Color _playerColor(int index) {
    const colors = [
      Color(0xFF00FFFF),
      Color(0xFFFF66CC),
      Color(0xFF66FF66),
      Color(0xFFFFCC33),
    ];
    return colors[index % colors.length];
  }

  void _drawCenteredText(Canvas canvas, Size size, String text) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Colors.black, blurRadius: 8)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width * 0.8);
    painter.paint(canvas, Offset((size.width - painter.width) / 2, (size.height - painter.height) / 2));
  }

  @override
  bool shouldRepaint(covariant OceanGamePainter oldDelegate) {
    return oldDelegate.state != state ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.assets != assets;
  }
}
