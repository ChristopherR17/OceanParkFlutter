package com.sabrinaelmeftah.OceanPark.gametools;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.utils.JsonReader;
import com.badlogic.gdx.utils.JsonValue;

public class LevelLoader {
    public int[][] tileMap;
    public float offsetX = 0;
    public float offsetY = 0;

    public void load(int level) {
        JsonReader reader = new JsonReader();

        // 1. Leer la posición real (Player Zone / Layer)
        try {
            // Asegúrate de que la ruta coincida con donde tienes tu game_data.json en la carpeta assets
            JsonValue gameData = reader.parse(Gdx.files.internal("game_data.json"));
            int levelIndex = level - 1;
            JsonValue layer = gameData.get("levels").get(levelIndex).get("layers").get(0);
            this.offsetX = layer.getFloat("x", 0);
            this.offsetY = layer.getFloat("y", 0);
            Gdx.app.log("MAPA", "Zona detectada -> Offset X: " + offsetX + ", Y: " + offsetY);
        } catch (Exception e) {
            Gdx.app.log("MAPA", "No se pudo leer la zona en game_data.json, usando 0,0");
        }

        // 2. Leer la matriz de tiles
        try {
            int levelIndex = level - 1;
            String levelName = String.format("%03d", levelIndex);
            JsonValue mapData = reader.parse(Gdx.files.internal("tilemaps/level_" + levelName + "_layer_000.json"));
            JsonValue mapArray = mapData.get("tileMap");
            tileMap = new int[mapArray.size][mapArray.get(0).size];

            for (int r = 0; r < mapArray.size; r++) {
                for (int c = 0; c < mapArray.get(r).size; c++) {
                    //tileMap[r][c] = mapArray.get(r).getInt(c);

                    int tileId = mapArray.get(r).getInt(c);

                    if (level == 2 && tileId == 145) {
                        tileMap[r][c] = 0; // o el ID del tile de fondo
                    } else {
                        tileMap[r][c] = tileId;
                    }
                }
            }
        } catch (Exception e) {
            Gdx.app.error("MAPA", "Error leyendo matriz de tiles: " + e.getMessage());
        }
    }
}
