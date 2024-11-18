module gameapplication;

import std.stdio;
import std.string;
import bindbc.sdl;
import sdl_abstraction;
import gameobject;
import sprite;
import component;
import factory;
import constants;
import scenetree;
import resourcemanager;
import audiomanager;
import scenemanager;

class GameApplication {
    private {
        SDL_Window* mWindow;
        SDL_Renderer* mRenderer;
        bool mGameIsRunning = true;
        ResourceManager resourceManager;
        AudioManager audioManager;
        Scene currentScene;
    }

    this(string title) {
        initializeSDL(title);
        resourceManager = new ResourceManager(mRenderer);
        audioManager = new AudioManager();
        loadScene("gameplay");
    }

    ~this() {
        if (currentScene) {
            currentScene.Cleanup();
        }
        destroy(audioManager);
        destroy(resourceManager);
        SDL_DestroyRenderer(mRenderer);
        SDL_DestroyWindow(mWindow);
    }

    void RunLoop() {
        while (mGameIsRunning) {
            currentScene.Update();
            currentScene.Render();

            if (currentScene.IsComplete()) {
                string nextScene = currentScene.GetNextScene();
                if (nextScene == "quit") {
                    mGameIsRunning = false;
                } else {
                    loadScene(nextScene);
                }
            }
        }
    }

private:
    void initializeSDL(string title) {
        mWindow = SDL_CreateWindow(
            title.toStringz,
            SDL_WINDOWPOS_UNDEFINED,
            SDL_WINDOWPOS_UNDEFINED,
            WINDOW_WIDTH,
            WINDOW_HEIGHT,
            SDL_WINDOW_SHOWN
        );

        mRenderer = SDL_CreateRenderer(mWindow, -1, SDL_RENDERER_ACCELERATED);
    }

    void loadScene(string sceneName) {
        if (currentScene) {
            currentScene.Cleanup();
        }

        final switch (sceneName) {
            case "gameplay":
                currentScene = new GameplayScene(mRenderer, resourceManager, audioManager);
                break;
            case "gameover":
                currentScene = new GameOverScene(mRenderer, resourceManager, audioManager);
                break;
        }

        currentScene.Initialize();
    }
}