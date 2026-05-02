package com.sabrinaelmeftah.OceanPark.gametools;

import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;
import com.badlogic.gdx.graphics.g2d.TextureRegion;

public class LevelRenderer {
    public static void render(SpriteBatch batch, Texture tileset, int[][] map, float layerX, float layerY) {
        int tileSize = 23;
        float worldHeight = map.length * tileSize + layerY;
        int cols = tileset.getWidth() / tileSize;
        TextureRegion[][] regions = TextureRegion.split(tileset, tileSize, tileSize);

        for (int row = 0; row < map.length; row++) {
            for (int col = 0; col < map[row].length; col++) {
                int id = map[row][col];
                if (id >= 0) {
                    float x = layerX + (col * tileSize);
                    float yDown = layerY + (row * tileSize);
                    float y = worldHeight - yDown - tileSize;

                    batch.draw(regions[id / cols][id % cols], x, y, tileSize, tileSize);
                }
            }
        }
    }
}
