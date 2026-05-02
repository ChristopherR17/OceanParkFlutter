package com.sabrinaelmeftah.OceanPark.configuration;
import com.badlogic.gdx.utils.JsonReader;
import com.badlogic.gdx.utils.JsonValue;

public class MessageParser {
    private static final JsonReader reader = new JsonReader();

    public static JsonValue parse(String raw) {
        return reader.parse(raw);
    }

    public static PlayerMessage[] parsePlayers(JsonValue root) {
        JsonValue payload = root.get("players");
        if (payload == null) return new PlayerMessage[0];
        PlayerMessage[] players = new PlayerMessage[payload.size];
        for (int i = 0; i < payload.size; i++) {
            JsonValue p = payload.get(i);
            PlayerMessage pm = new PlayerMessage();
            pm.id = p.getString("id", null);
            pm.name = p.getString("name", null);
            players[i] = pm;
        }
        return players;
    }

    public static GameObjectMessage[] parseGameObjects(JsonValue root) {
        JsonValue players = root.get("players");
        if (players == null) return new GameObjectMessage[0];
        GameObjectMessage[] objects = new GameObjectMessage[players.size];
        for (int i = 0; i < players.size; i++) {
            JsonValue p = players.get(i);
            GameObjectMessage gom = new GameObjectMessage();
            gom.name = p.getString("name");
            gom.x = p.getFloat("x");
            gom.y = p.getFloat("y");
            gom.state = p.getString("state", "IDLE");
            gom.facingRight = p.getBoolean("facingRight", true);
            objects[i] = gom;
        }
        return objects;
    }
}
