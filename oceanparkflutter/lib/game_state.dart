class PlayerState {
  final String id;
  final String name;
  final double x;
  final double y;
  final String state;
  final bool facingRight;
  final bool hasKey;
  final bool hasFinishedLevel;

  PlayerState.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        name = j['name'],
        x = (j['x'] as num).toDouble(),
        y = (j['y'] as num).toDouble(),
        state = j['state'] ?? 'IDLE',
        facingRight = j['facingRight'] ?? true,
        hasKey = j['hasKey'] ?? false,
        hasFinishedLevel = j['hasFinishedLevel'] ?? false;
}

class KeyState {
  final double x, y;
  final bool picked;
  KeyState.fromJson(Map<String, dynamic> j)
      : x = (j['x'] as num).toDouble(),
        y = (j['y'] as num).toDouble(),
        picked = j['picked'] ?? false;
}

class DoorState {
  final double x, y;
  final bool open;
  DoorState.fromJson(Map<String, dynamic> j)
      : x = (j['x'] as num).toDouble(),
        y = (j['y'] as num).toDouble(),
        open = j['open'] ?? false;
}

class GameState {
  final int level;
  final List<PlayerState> players;
  final KeyState? leafKey;
  final DoorState? door;

  GameState.fromJson(Map<String, dynamic> j)
      : level = j['level'] ?? 1,
        players = (j['players'] as List? ?? [])
            .map((p) => PlayerState.fromJson(p))
            .toList(),
        leafKey = j['leafKey'] != null ? KeyState.fromJson(j['leafKey']) : null,
        door = j['door'] != null ? DoorState.fromJson(j['door']) : null;
}
