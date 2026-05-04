package com.sabrinaelmeftah.OceanPark.screens;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.Input;
import com.badlogic.gdx.Screen;
import com.badlogic.gdx.graphics.GL20;
import com.badlogic.gdx.graphics.OrthographicCamera;
import com.badlogic.gdx.graphics.glutils.ShapeRenderer;
import com.badlogic.gdx.graphics.g2d.TextureRegion;
import com.badlogic.gdx.utils.JsonReader;
import com.badlogic.gdx.utils.JsonValue;
import com.badlogic.gdx.utils.viewport.FitViewport;
import com.badlogic.gdx.utils.viewport.Viewport;

import com.sabrinaelmeftah.OceanPark.Main;
import com.sabrinaelmeftah.OceanPark.gametools.LevelRenderer;

public class GameScreen implements Screen, IScreen {

    private final Main game;

    private OrthographicCamera camera;
    private FitViewport viewport;

    private OrthographicCamera hudCamera;
    private Viewport hudViewport;
    private ShapeRenderer shapeRenderer;

    private JsonValue ultimoEstado;
    private final JsonReader lector = new JsonReader();

    private String lastDir = "NONE";
    private float tiempoAnimacion = 0f;

    // HUD
    private static final float HUD_W = 480f;
    private static final float HUD_H = 270f;
    private static final float BTN_SIZE = 48f;
    private static final float BTN_MARGIN = 18f;

    private boolean touchLeft = false;
    private boolean touchRight = false;
    private boolean touchJump = false;
    private boolean jumpWasPressed = false;

    private final float MAP_X = -75.0f;
    private final float MAP_Y = 673.0f;
    private final float ZOOM = 1.07f;

    public GameScreen(Main game) {
        this.game = game;

        camera = new OrthographicCamera();
        viewport = new FitViewport(480, 270, camera);

        camera.zoom = ZOOM;
        camera.update();

        hudCamera = new OrthographicCamera();
        hudViewport = new FitViewport(HUD_W, HUD_H, hudCamera);
        hudViewport.apply();
        hudCamera.position.set(HUD_W / 2f, HUD_H / 2f, 0);
        hudCamera.update();

        shapeRenderer = new ShapeRenderer();
    }

    @Override
    public void render(float delta) {

        Gdx.gl.glClearColor(0.33f, 0.54f, 0.69f, 1);
        Gdx.gl.glClear(GL20.GL_COLOR_BUFFER_BIT);

        if (ultimoEstado == null || game.tileMap == null) {
            procesarEntrada();
            return;
        }

        float worldHeight = game.tileMap.length * 23f + MAP_Y;
        tiempoAnimacion += delta;

        JsonValue players = ultimoEstado.get("players");

        actualizarCamara(players, worldHeight);

        // MUNDO
        viewport.apply();
        game.batch.setProjectionMatrix(camera.combined);

        game.batch.begin();

        LevelRenderer.render(game.batch, game.tilesetTexture, game.tileMap, MAP_X, MAP_Y);
        dibujarPuerta(worldHeight);
        dibujarLlave(worldHeight);
        dibujarBoton(worldHeight);
        dibujarPlataformasMoviles(worldHeight);
        dibujarJugadores(players, worldHeight);

        game.batch.end();

        // HUD
        dibujarControlesTactiles();
        dibujarMensajeNivelCompletado();

        procesarEntrada();
    }

    private void actualizarCamara(JsonValue players, float worldHeight) {
        if (players == null) return;

        for (JsonValue p : players) {
            if (p.getString("id", "").equals(game.playerId)) {
                float tx = p.getFloat("x");
                float ty = worldHeight - p.getFloat("y") - 16f;

                camera.position.set(tx, ty, 0);
                camera.update();
                break;
            }
        }
    }

    private void dibujarPuerta(float worldHeight) {
        JsonValue doorData = ultimoEstado.get("door");

        boolean open = false;
        float doorX = 260f;
        float doorY = 379f;
        float doorClosedW = 54f;
        float doorClosedH = 38f;
        float doorOpenW = 64f;
        float doorOpenH = 64f;

        if (doorData != null) {
            open = doorData.getBoolean("open", false);
            doorX = doorData.getFloat("x", doorX);
            doorY = doorData.getFloat("y", doorY);
        }

        float drawX = doorX;

        if (open) {
            float drawY = worldHeight - doorY - 72f - doorOpenH;
            int frameIdx = (int) (tiempoAnimacion * 5) % game.doorOpenFrames.length;
            game.batch.draw(game.doorOpenFrames[frameIdx], drawX, drawY, doorOpenW, doorOpenH);
        } else {
            float drawY = worldHeight - doorY - 72f - doorClosedH;
            game.batch.draw(game.doorClosedFrame, drawX, drawY, doorClosedW, doorClosedH);
        }
    }

    private void dibujarLlave(float worldHeight) {
        JsonValue keyData = ultimoEstado.get("leafKey");

        float keyX = 45f;
        float keyY = 261f;
        boolean picked = false;

        if (keyData != null) {
            keyX = keyData.getFloat("x", keyX);
            keyY = keyData.getFloat("y", keyY);
            picked = keyData.getBoolean("picked", false);
        }

        float kx = keyX;
        float ky = worldHeight - keyY - 32f;

        int frameIdx = (int) (tiempoAnimacion * 5) % game.leafKeyFrames.length;

        game.batch.draw(game.leafKeyFrames[frameIdx], kx, ky, 32, 32);
    }

    private void dibujarBoton(float worldHeight) {
        JsonValue buttonData = ultimoEstado.get("button");

        if (buttonData == null) return;

        float buttonX = buttonData.getFloat("x", 342f);
        float buttonY = buttonData.getFloat("y", 194f + MAP_Y);
        float buttonW = buttonData.getFloat("width", 20f);
        float buttonH = buttonData.getFloat("height", 22f);
        boolean pressed = buttonData.getBoolean("pressed", false);

        float drawX = buttonX;
        float drawY = worldHeight - buttonY - buttonH;

        if (pressed) {
            game.batch.setColor(0.6f, 0.6f, 0.6f, 1f);
        }

        game.batch.draw(game.buttonFrame, drawX, drawY, buttonW, buttonH);
        game.batch.setColor(1f, 1f, 1f, 1f);
    }

    private void dibujarPlataformasMoviles(float worldHeight) {
        JsonValue platforms = ultimoEstado.get("movingPlatforms");
        if (platforms == null) return;

        int tileSize = 23;
        int cols = game.tilesetTexture.getWidth() / tileSize;
        TextureRegion[][] regions = TextureRegion.split(game.tilesetTexture, tileSize, tileSize);

        for (JsonValue p : platforms) {
            float x = p.getFloat("x");
            float y = worldHeight - p.getFloat("y") - p.getFloat("height", tileSize);
            float w = p.getFloat("width", tileSize);
            float h = p.getFloat("height", tileSize);

            int tileId = p.getInt("tileId", 145);

            TextureRegion tile = regions[tileId / cols][tileId % cols];

            int tileCount = Math.round(w / tileSize);

            for (int i = 0; i < tileCount; i++) {
                game.batch.draw(
                    tile,
                    x + i * tileSize,
                    y,
                    tileSize,
                    h
                );
            }
        }
    }

    private void dibujarJugadores(JsonValue players, float worldHeight) {
        if (players == null) return;

        for (JsonValue p : players) {
            float px = p.getFloat("x");
            float py = worldHeight - p.getFloat("y") - 32f;

            TextureRegion[] frames = obtenerFramesJugador(p);

            if (frames == null || frames.length == 0) continue;

            int frameIndex = (int) (tiempoAnimacion * 8) % frames.length;

            game.batch.draw(frames[frameIndex], px, py, 32, 32);
        }
    }

    private void dibujarMensajeNivelCompletado() {
        if (ultimoEstado == null) return;

        int level = ultimoEstado.getInt("level", 1);
        if (level != 2) return;

        JsonValue players = ultimoEstado.get("players");
        if (players == null || players.size == 0) return;

        boolean todosHanTerminado = true;

        for (JsonValue p : players) {
            if (!p.getBoolean("hasFinishedLevel", false)) {
                todosHanTerminado = false;
                break;
            }
        }

        if (!todosHanTerminado) return;

        hudViewport.apply();

        float boxW = 360f;
        float boxH = 90f;
        float boxX = (HUD_W - boxW) / 2f;
        float boxY = (HUD_H - boxH) / 2f;

        shapeRenderer.setProjectionMatrix(hudCamera.combined);

        Gdx.gl.glEnable(GL20.GL_BLEND);

        shapeRenderer.begin(ShapeRenderer.ShapeType.Filled);
        shapeRenderer.setColor(0f, 0f, 0f, 0.65f);
        shapeRenderer.rect(boxX, boxY, boxW, boxH);
        shapeRenderer.end();

        shapeRenderer.begin(ShapeRenderer.ShapeType.Line);
        shapeRenderer.setColor(0f, 1f, 1f, 1f);
        shapeRenderer.rect(boxX, boxY, boxW, boxH);
        shapeRenderer.end();

        Gdx.gl.glDisable(GL20.GL_BLEND);

        game.batch.setProjectionMatrix(hudCamera.combined);
        game.batch.begin();

        game.skin.getFont("font").getData().setScale(2.1f);
        game.skin.getFont("font").setColor(0f, 1f, 1f, 1f);
        game.skin.getFont("font").draw(
            game.batch,
            "NIVEL COMPLETADO",
            boxX + 45f,
            boxY + 58f
        );

        game.skin.getFont("font").getData().setScale(1f);
        game.skin.getFont("font").setColor(1f, 1f, 1f, 1f);
        game.skin.getFont("font").draw(
            game.batch,
            "¡Buen trabajo!",
            boxX + 130f,
            boxY + 28f
        );

        game.skin.getFont("font").setColor(1f, 1f, 1f, 1f);
        game.batch.end();

        viewport.apply();
    }

    private TextureRegion[] obtenerFramesJugador(JsonValue p) {
        String state = p.getString("state", "IDLE");
        boolean facingRight = p.getBoolean("facingRight", true);

        if (state.equals("RUN")) {
            return facingRight ? game.framesRight : game.framesLeft;
        }

        if (state.equals("JUMP")) {
            return facingRight ? game.framesRight : game.framesLeft;
        }

        return game.framesIdle;
    }

    private void actualizarEstadoTactil() {
        touchLeft = false;
        touchRight = false;
        touchJump = false;

        float leftX = BTN_MARGIN;
        float rightX = BTN_MARGIN + BTN_SIZE + 12f;
        float buttonsY = BTN_MARGIN;
        float jumpX = HUD_W - BTN_MARGIN - BTN_SIZE;

        for (int i = 0; i < 5; i++) {
            if (!Gdx.input.isTouched(i)) continue;

            float sx = Gdx.input.getX(i);
            float sy = Gdx.input.getY(i);

            com.badlogic.gdx.math.Vector2 p = hudViewport.unproject(
                new com.badlogic.gdx.math.Vector2(sx, sy)
            );

            if (estaDentro(p.x, p.y, leftX, buttonsY, BTN_SIZE, BTN_SIZE)) touchLeft = true;
            if (estaDentro(p.x, p.y, rightX, buttonsY, BTN_SIZE, BTN_SIZE)) touchRight = true;
            if (estaDentro(p.x, p.y, jumpX, buttonsY, BTN_SIZE, BTN_SIZE)) touchJump = true;
        }
    }

    private boolean estaDentro(float px, float py, float x, float y, float w, float h) {
        return px >= x && px <= x + w && py >= y && py <= y + h;
    }

    private void procesarEntrada() {
        actualizarEstadoTactil();

        String dir = "NONE";

        if (touchLeft) dir = "LEFT";
        else if (touchRight) dir = "RIGHT";

        boolean jump = touchJump && !jumpWasPressed;
        jumpWasPressed = touchJump;

        if (game.socket != null && game.socket.isOpen()) {
            if (!dir.equals(lastDir) || jump) {
                String msg = "{\"type\":\"MOVE\",\"dir\":\"" + dir + "\",\"jump\":" + jump + "}";
                game.socket.send(msg);
                lastDir = dir;
            }
        }
    }

    private void dibujarControlesTactiles() {
        hudViewport.apply();
        shapeRenderer.setProjectionMatrix(hudCamera.combined);

        float leftX = BTN_MARGIN;
        float rightX = BTN_MARGIN + BTN_SIZE + 12f;
        float y = BTN_MARGIN;
        float jumpX = HUD_W - BTN_MARGIN - BTN_SIZE;

        shapeRenderer.begin(ShapeRenderer.ShapeType.Filled);
        shapeRenderer.setColor(0, 0, 0, 0.35f);
        shapeRenderer.rect(leftX, y, BTN_SIZE, BTN_SIZE);
        shapeRenderer.rect(rightX, y, BTN_SIZE, BTN_SIZE);
        shapeRenderer.rect(jumpX, y, BTN_SIZE, BTN_SIZE);
        shapeRenderer.end();

        game.batch.setProjectionMatrix(hudCamera.combined);
        game.batch.begin();
        game.skin.getFont("font").draw(game.batch, "<", leftX + 15, y + 30);
        game.skin.getFont("font").draw(game.batch, ">", rightX + 15, y + 30);
        game.skin.getFont("font").draw(game.batch, "J", jumpX + 18, y + 30);
        game.batch.end();

        viewport.apply();
    }

    @Override
    public void handleMessage(String message) {
        try {
            JsonValue json = lector.parse(message);
            if (json.getString("type").equals("STATE")) {
                int level = json.getInt("level", 1);

                if (game.currentLevel != level) {
                    game.currentLevel = level;
                    game.levelLoader.load(level);
                    game.tileMap = game.levelLoader.tileMap;
                    ultimoEstado = null;
                }

                ultimoEstado = json;
            }        } catch (Exception ignored) {}
    }

    @Override
    public void resize(int width, int height) {
        viewport.update(width, height);
        hudViewport.update(width, height);
    }

    @Override public void show() {}
    @Override public void pause() {}
    @Override public void resume() {}
    @Override public void hide() {}
    @Override public void dispose() {
        shapeRenderer.dispose();
    }
}
