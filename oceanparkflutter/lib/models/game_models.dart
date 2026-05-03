class PlayerState {
  final String id;
  final String name;
  final double x;
  final double y;
  final String state;
  final bool facingRight;
  final bool hasKey;
  final bool hasFinishedLevel;

  const PlayerState({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    required this.state,
    required this.facingRight,
    required this.hasKey,
    required this.hasFinishedLevel,
  });

  factory PlayerState.fromJson(Map<String, dynamic> json) {
    return PlayerState(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Jugador',
      x: (json['x'] as num? ?? 0).toDouble(),
      y: (json['y'] as num? ?? 0).toDouble(),
      state: json['state']?.toString() ?? 'IDLE',
      facingRight: json['facingRight'] as bool? ?? true,
      hasKey: json['hasKey'] as bool? ?? false,
      hasFinishedLevel: json['hasFinishedLevel'] as bool? ?? false,
    );
  }
}

class LeafKeyState {
  final double x;
  final double y;
  final String? pickedBy;
  final bool picked;

  const LeafKeyState({
    required this.x,
    required this.y,
    required this.pickedBy,
    required this.picked,
  });

  factory LeafKeyState.fromJson(Map<String, dynamic> json) {
    return LeafKeyState(
      x: (json['x'] as num? ?? 45).toDouble(),
      y: (json['y'] as num? ?? 933).toDouble(),
      pickedBy: json['pickedBy']?.toString(),
      picked: json['picked'] as bool? ?? false,
    );
  }
}

class DoorState {
  final double x;
  final double y;
  final double width;
  final double height;
  final bool open;

  const DoorState({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.open,
  });

  factory DoorState.fromJson(Map<String, dynamic> json) {
    return DoorState(
      x: (json['x'] as num? ?? 260).toDouble(),
      y: (json['y'] as num? ?? 1052).toDouble(),
      width: (json['width'] as num? ?? 54).toDouble(),
      height: (json['height'] as num? ?? 38).toDouble(),
      open: json['open'] as bool? ?? false,
    );
  }
}

class ExitZoneState {
  final double x;
  final double y;
  final double width;
  final double height;

  const ExitZoneState({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory ExitZoneState.fromJson(Map<String, dynamic> json) {
    return ExitZoneState(
      x: (json['x'] as num? ?? 0).toDouble(),
      y: (json['y'] as num? ?? 0).toDouble(),
      width: (json['width'] as num? ?? 0).toDouble(),
      height: (json['height'] as num? ?? 0).toDouble(),
    );
  }
}

class GameState {
  final int level;
  final List<PlayerState> players;
  final LeafKeyState? leafKey;
  final DoorState? door;
  final ExitZoneState? exitZone;

  const GameState({
    required this.level,
    required this.players,
    required this.leafKey,
    required this.door,
    required this.exitZone,
  });

  factory GameState.fromJson(Map<String, dynamic> json) {
    final rawPlayers = json['players'] as List<dynamic>? ?? const [];
    return GameState(
      level: json['level'] as int? ?? 1,
      players: rawPlayers
          .whereType<Map>()
          .map((p) => PlayerState.fromJson(Map<String, dynamic>.from(p)))
          .toList(),
      leafKey: json['leafKey'] is Map
          ? LeafKeyState.fromJson(Map<String, dynamic>.from(json['leafKey'] as Map))
          : null,
      door: json['door'] is Map
          ? DoorState.fromJson(Map<String, dynamic>.from(json['door'] as Map))
          : null,
      exitZone: json['exitZone'] is Map
          ? ExitZoneState.fromJson(Map<String, dynamic>.from(json['exitZone'] as Map))
          : null,
    );
  }
}
