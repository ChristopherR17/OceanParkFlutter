package com.sabrinaelmeftah.OceanPark;

import com.badlogic.gdx.Game;
import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;
import com.badlogic.gdx.graphics.g2d.TextureRegion;
import com.badlogic.gdx.scenes.scene2d.ui.Skin;
import com.badlogic.gdx.utils.Array;

import com.github.czyzby.websocket.WebSocket;
import com.github.czyzby.websocket.WebSocketHandler;
import com.github.czyzby.websocket.WebSockets;
import com.github.czyzby.websocket.data.WebSocketCloseCode;

import com.sabrinaelmeftah.OceanPark.screens.*;
import com.sabrinaelmeftah.OceanPark.gametools.LevelLoader;

public class Main extends Game {

    public SpriteBatch batch;
    public Skin skin;
    public WebSocket socket;

    private final Array<String> messageQueue = new Array<>();

    public String playerId;
    public String playerName;

    // Animaciones del jugador
    public TextureRegion[] framesIdle;
    public TextureRegion[] framesLeft;
    public TextureRegion[] framesRight;

    // Mapa
    public Texture tilesetTexture;
    public int[][] tileMap;
    public LevelLoader levelLoader;

    // Llave
    public TextureRegion[] leafKeyFrames;

    // Puerta
    public TextureRegion doorClosedFrame;
    public TextureRegion[] doorOpenFrames;

    @Override
    public void create() {
        batch = new SpriteBatch();
        skin = new Skin(Gdx.files.internal("skin/neon-ui.json"));

        // Animaciones del jugador
        framesIdle = cargarAnimacion("sprites/Mushroom Idle.png", 32, 32);
        framesLeft = cargarAnimacion("sprites/Mushroom Left.png", 32, 32);
        framesRight = cargarAnimacion("sprites/Mushroom Right.png", 32, 32);

        // Mapa
        tilesetTexture = new Texture(Gdx.files.internal("map/tileset_cueva_2.png"));
        tilesetTexture.setFilter(Texture.TextureFilter.Nearest, Texture.TextureFilter.Nearest);

        levelLoader = new LevelLoader();
        levelLoader.load();
        tileMap = levelLoader.tileMap;

        // Llave animada: 2 frames de 32x32
        Texture keyTex = new Texture(Gdx.files.internal("sprites/Leaf Key.png"));
        keyTex.setFilter(Texture.TextureFilter.Nearest, Texture.TextureFilter.Nearest);

        TextureRegion[][] keyTmp = TextureRegion.split(keyTex, 32, 32);
        leafKeyFrames = new TextureRegion[]{ keyTmp[0][0], keyTmp[0][1] };

        // Puerta cerrada: en tu JSON mide 54x38
        Texture doorClosedTex = new Texture(Gdx.files.internal("sprites/Door Closed.png"));
        doorClosedTex.setFilter(Texture.TextureFilter.Nearest, Texture.TextureFilter.Nearest);
        doorClosedFrame = new TextureRegion(doorClosedTex, 0, 0, 54, 38);

        // Puerta abierta: en tu JSON es spritesheet de 64x64 con 2 frames
        Texture doorOpenTex = new Texture(Gdx.files.internal("sprites/Door Open.png"));
        doorOpenTex.setFilter(Texture.TextureFilter.Nearest, Texture.TextureFilter.Nearest);

        TextureRegion[][] doorOpenTmp = TextureRegion.split(doorOpenTex, 64, 64);
        doorOpenFrames = new TextureRegion[]{ doorOpenTmp[0][0], doorOpenTmp[0][1] };

        conectar();

        this.setScreen(new MainMenu(this));
    }

    private TextureRegion[] cargarAnimacion(String path, int width, int height) {
        Texture tex = new Texture(Gdx.files.internal(path));
        tex.setFilter(Texture.TextureFilter.Nearest, Texture.TextureFilter.Nearest);

        TextureRegion[][] tmp = TextureRegion.split(tex, width, height);

        TextureRegion[] frames = new TextureRegion[tmp[0].length];
        System.arraycopy(tmp[0], 0, frames, 0, tmp[0].length);

        return frames;
    }

    private void conectar() {
        // Para servidor público: "wss://pico3.ieti.site"
        // Para probar localmente: "ws://localhost:3000"
        socket = WebSockets.newSocket(WebSockets.toSecureWebSocketUrl("pico3.ieti.site", 443));
        socket.addListener(new WebSocketHandler() {
            @Override
            public boolean onOpen(WebSocket webSocket) {
                Gdx.app.log("WS", "Conectado con éxito");
                return FULLY_HANDLED;
            }

            @Override
            public boolean onMessage(WebSocket webSocket, String message) {
                synchronized (messageQueue) {
                    messageQueue.add(message);
                }
                return FULLY_HANDLED;
            }

            public boolean onClose(WebSocket webSocket, WebSocketCloseCode code) {
                Gdx.app.log("WS", "Conexión cerrada: " + code);
                return FULLY_HANDLED;
            }

            @Override
            public boolean onError(WebSocket webSocket, Throwable error) {
                Gdx.app.error("WS", "Error en la conexión: " + error.getMessage());
                return FULLY_HANDLED;
            }
        });
        socket.connect();
    }

    @Override
    public void render() {
        synchronized (messageQueue) {
            for (String message : messageQueue) {
                if (getScreen() instanceof IScreen) {
                    ((IScreen) getScreen()).handleMessage(message);
                }
            }

            messageQueue.clear();
        }

        super.render();
    }

    @Override
    public void dispose() {
        if (batch != null) batch.dispose();
        if (skin != null) skin.dispose();
        if (tilesetTexture != null) tilesetTexture.dispose();

        if (socket != null) {
            WebSockets.closeGracefully(socket);
        }
    }
}
