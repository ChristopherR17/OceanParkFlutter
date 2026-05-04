package com.sabrinaelmeftah.OceanPark.screens;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.Screen;
import com.badlogic.gdx.graphics.Color;
import com.badlogic.gdx.graphics.GL20;
import com.badlogic.gdx.graphics.OrthographicCamera;
import com.badlogic.gdx.graphics.g2d.BitmapFont;
import com.badlogic.gdx.scenes.scene2d.InputEvent;
import com.badlogic.gdx.scenes.scene2d.Stage;
import com.badlogic.gdx.scenes.scene2d.ui.Label;
import com.badlogic.gdx.scenes.scene2d.ui.ScrollPane;
import com.badlogic.gdx.scenes.scene2d.ui.Table;
import com.badlogic.gdx.scenes.scene2d.ui.TextButton;
import com.badlogic.gdx.scenes.scene2d.ui.TextField;
import com.badlogic.gdx.scenes.scene2d.utils.ClickListener;
import com.badlogic.gdx.scenes.scene2d.utils.Drawable;
import com.badlogic.gdx.utils.JsonReader;
import com.badlogic.gdx.utils.JsonValue;
import com.badlogic.gdx.utils.viewport.FitViewport;

import com.sabrinaelmeftah.OceanPark.Main;
import com.sabrinaelmeftah.OceanPark.gametools.LevelRenderer;

public class MainMenu implements Screen, IScreen {

    private final Main game;

    private Stage stage;
    private OrthographicCamera mapCamera;
    private FitViewport mapViewport;

    private Label labelInfo;
    private Table playersListTable;

    private final JsonReader lector = new JsonReader();

    private final float MAP_X = -295.0f;
    private final float MAP_Y = 673.0f;

    private static final Color[] PLAYER_COLORS = {
        new Color(0f, 1f, 1f, 1f),
        new Color(1f, 0.4f, 0.8f, 1f),
        new Color(0.4f, 1f, 0.4f, 1f),
        new Color(1f, 0.8f, 0.2f, 1f),
    };

    public MainMenu(final Main game) {
        this.game = game;

        game.currentLevel = 1;
        game.levelLoader.load(1);
        game.tileMap = game.levelLoader.tileMap;

        mapCamera = new OrthographicCamera();
        mapViewport = new FitViewport(480, 270, mapCamera);
        mapCamera.position.set(240, 135, 0);
        mapCamera.zoom = 1.07f;
        mapCamera.update();

        stage = new Stage(new FitViewport(800, 480), game.batch);

        Table root = new Table();
        root.setFillParent(true);
        root.pad(40);
        root.setBackground((Drawable) null);
        stage.addActor(root);

        // --- Panel izquierdo: formulario ---
        Table menuTable = new Table();

        Label title = new Label("OCEAN PARK", game.skin, "over");
        title.setColor(0f, 1f, 1f, 1f);

        Label subtitle = new Label("Introduce tu nombre para jugar", game.skin);
        subtitle.setColor(0.6f, 0.9f, 0.9f, 1f);

        final TextField nombreInput = new TextField("", game.skin);
        nombreInput.setMessageText("Nombre del jugador...");

        TextButton btnJugar = new TextButton("▶  ENTRAR AL JUEGO", game.skin);
        labelInfo = new Label("", game.skin);
        labelInfo.setColor(1f, 0.4f, 0.4f, 1f);

        menuTable.add(title).padBottom(6).row();
        menuTable.add(subtitle).padBottom(30).row();
        menuTable.add(nombreInput).width(380).height(50).padBottom(14).row();
        menuTable.add(btnJugar).width(380).height(54).padBottom(10).row();
        menuTable.add(labelInfo).row();

        // --- Panel derecho: lista de jugadores ---
        Table playersPanel = new Table();

        Label playersTitle = new Label("EN LINEA", game.skin, "over");
        playersTitle.setColor(0f, 1f, 1f, 1f);

        playersListTable = new Table();
        playersListTable.top().left();

        ScrollPane scroll = new ScrollPane(playersListTable, game.skin);
        scroll.setFadeScrollBars(false);

        ScrollPane.ScrollPaneStyle scrollStyle = new ScrollPane.ScrollPaneStyle(scroll.getStyle());
        scrollStyle.background = null;
        scroll.setStyle(scrollStyle);

        playersPanel.add(playersTitle).padBottom(14).row();
        playersPanel.add(scroll).width(200).height(300).top();

        actualizarListaJugadores(null);

        root.add(menuTable).expand().center().padRight(40);
        root.add(playersPanel).width(220).top().padTop(30);

        btnJugar.addListener(new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                String nombre = nombreInput.getText().trim();

                if (!nombre.isEmpty() && game.socket != null && game.socket.isOpen()) {
                    String nombreSeguro = nombre.replace("\"", "\\\"");
                    String msg = "{\"type\":\"JOIN\", \"name\":\"" + nombreSeguro + "\"}";
                    game.socket.send(msg);
                    labelInfo.setText("");
                } else if (game.socket == null || !game.socket.isOpen()) {
                    labelInfo.setText("Sin conexión al servidor.");
                } else {
                    labelInfo.setText("Introduce un nombre.");
                }
            }
        });
    }

    @Override
    public void handleMessage(String message) {
        try {
            JsonValue json = lector.parse(message);
            String type = json.getString("type", "");

            if (type.equals("JOINED")) {
                game.playerId = json.getString("playerId");
                game.playerName = json.getString("name");

                Gdx.app.postRunnable(() -> game.setScreen(new GameScreen(game)));
            }

            if (type.equals("STATE")) {
                actualizarListaJugadores(json.get("players"));
            }

            if (type.equals("ERROR")) {
                labelInfo.setText(json.getString("message", "Error desconocido"));
            }

        } catch (Exception e) {
            Gdx.app.log("MainMenu", "Mensaje ignorado o error: " + e.getMessage());
        }
    }

    private void actualizarListaJugadores(JsonValue players) {
        playersListTable.clear();

        if (players == null || players.size == 0) {
            Label empty = new Label("Nadie conectado aun", game.skin);
            empty.setColor(0.5f, 0.5f, 0.5f, 1f);
            playersListTable.add(empty).padTop(12).row();
            return;
        }

        int i = 0;
        for (JsonValue p : players) {
            String nombre = p.getString("name", "Jugador");
            Color color = PLAYER_COLORS[i % PLAYER_COLORS.length];

            Table row = new Table();

            Label dot = new Label("●", game.skin);
            dot.setColor(color);

            Label nameLabel = new Label(nombre, game.skin);
            nameLabel.setColor(color);

            row.add(dot).padRight(10);
            row.add(nameLabel).left();

            playersListTable.add(row).left().padBottom(10).row();
            i++;
        }
    }

    @Override
    public void render(float delta) {
        Gdx.gl.glClearColor(0.02f, 0.02f, 0.08f, 1);
        Gdx.gl.glClear(GL20.GL_COLOR_BUFFER_BIT);

        dibujarMapaFondo();

        stage.act(delta);
        stage.draw();
    }

    private void dibujarMapaFondo() {
        if (game.tileMap == null || game.tilesetTexture == null) return;

        mapViewport.apply();
        game.batch.setProjectionMatrix(mapCamera.combined);

        game.batch.begin();

        game.batch.setColor(1f, 1f, 1f, 1f);

        LevelRenderer.render(
            game.batch,
            game.tilesetTexture,
            game.tileMap,
            MAP_X,
            MAP_Y
        );

        game.batch.end();
    }

    @Override
    public void show() {
        Gdx.input.setInputProcessor(stage);
    }

    @Override
    public void resize(int width, int height) {
        stage.getViewport().update(width, height, true);
        mapViewport.update(width, height, true);
    }

    @Override public void pause() {}
    @Override public void resume() {}
    @Override public void hide() {}

    @Override
    public void dispose() {
        stage.dispose();
    }
}

