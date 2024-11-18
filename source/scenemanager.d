module scenemanager;

import std.stdio;
import bindbc.sdl;
import gameobject;
import sprite;
import component;
import factory;
import scenetree;
import resourcemanager;
import audiomanager;
import constants;

// Abstract base class for all scenes
abstract class Scene {
    protected {
        SDL_Renderer* mRenderer;
        ResourceManager resourceManager;
        AudioManager audioManager;
        SceneTree sceneTree;
        bool isComplete = false;
        string nextScene;
    }

    this(SDL_Renderer* mRenderer, ResourceManager resourceManager, AudioManager audioManager) {
        this.mRenderer = mRenderer;
        this.resourceManager = resourceManager;
        this.audioManager = audioManager;
        this.sceneTree = new SceneTree();
    }

    abstract void Initialize();
    abstract void Update();
    abstract void Render();
    abstract void Cleanup();

    bool IsComplete() { return isComplete; }
    string GetNextScene() { return nextScene; }

    // void clearSceneTree() {
    //     if (sceneTree) {
    //         // First remove all nodes
    //         sceneTree.traverse((SceneNode node) {
    //             node.gameObject.active = false;
    //             // if (node.getParent) {
    //             //     node.getParent.removeChild(node);
    //             // }
    //             // if (node.gameObject) {
    //             //     destroy(node.gameObject);
    //             // }
    //         });
            
    //         // Then destroy the tree itself
    //         // destroy(sceneTree);
    //         // sceneTree = new SceneTree();
    //     }
    // }
}

// Game play scene
class GameplayScene : Scene {
    private {
        uint lastFrameTime = 0;
    }

    this(SDL_Renderer* mRenderer, ResourceManager resourceManager, AudioManager audioManager) {
        super(mRenderer, resourceManager, audioManager);
    }

    override void Initialize() {
        initializeAudio();
        initializeGameObjects();
        lastFrameTime = SDL_GetTicks();
    }

    void initializeAudio() {
        audioManager.loadSound("shoot", "assets/sounds/shoot.mp3");
        audioManager.loadSound("explosion", "assets/sounds/explosion.wav");
    }

    void initializeGameObjects() {
        createTurretObject(mRenderer, resourceManager, sceneTree, audioManager);
        createEnemyGrid(mRenderer, resourceManager, sceneTree, audioManager);
    }

    override void Update() {
        // Frame Timing
        uint frameStart = SDL_GetTicks();
        uint elapsedTime = frameStart - lastFrameTime;

        // update if enough time passed
        if (elapsedTime >= FRAME_TARGET_TIME) {
            Input();
            updateGameObjects();
            checkCollisions();
            checkGameEndConditions();

            lastFrameTime = frameStart;

            uint frameTime = SDL_GetTicks() - frameStart;

            if (frameTime < FRAME_TARGET_TIME) {
                SDL_Delay(FRAME_TARGET_TIME - frameTime);
            }
        }
    }

    override void Render() {
        SDL_SetRenderDrawColor(mRenderer, 5, 50, 100, SDL_ALPHA_OPAQUE);
        SDL_RenderClear(mRenderer);

        sceneTree.traverse((SceneNode node) {
            if (node.gameObject && node.gameObject.active) {
                node.gameObject.Render(mRenderer);
            }
        });

        SDL_RenderPresent(mRenderer);
    }

    override void Cleanup() {
        // Cleanup will happen through the SceneTree destructor
    }

    private void Input() {
        SDL_Event event;
        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_QUIT) {
                isComplete = true;
                nextScene = "quit";
            }
        }
    }


    private void updateGameObjects() {
        sceneTree.traverse((SceneNode node) {
            if (node.gameObject && node.gameObject.active) {
                node.gameObject.Update();
            }
        });

        // Collect nodes to remove
        SceneNode[] nodesToRemove;
        sceneTree.traverse((SceneNode node) {
            if (node.gameObject && !node.gameObject.active && 
                node.gameObject.GetName() == "Enemy" && 
                node.getParent) {
                nodesToRemove ~= node;
            }
        });

        // Remove collected nodes
        foreach (node; nodesToRemove) {
            if (node.getParent) {
                node.getParent.removeChild(node);
                writeln("Removed inactive enemy from scene tree");
            }
        }
    }

    private void checkCollisions() {
        // find the turret
        GameObject turret;
        sceneTree.traverse((SceneNode node) {
            if (node.gameObject && node.gameObject.GetName() == "Turret") {
                turret = node.gameObject;
                // writeln("Turret position: ", turret.x, ", ", turret.y);
            }
        });

        if (!turret || !turret.active) return;

        // Check collisions
        auto turretCollision = turret.getComponent!(CollisionComponent)();
        sceneTree.traverse((SceneNode node) {
            if (node.gameObject && node.gameObject.active) {
                if (node.gameObject.GetName() == "Enemy") {
                    if (turretCollision.checkCollision(node.gameObject)) {
                        writeln("Collision detected between: ",
                            "Turret(", turret.x, ",", turret.y, ") and ",
                            "Enemy(", node.gameObject.x, ",", node.gameObject.y, ")");
                        endGame(false, "Game Over! You got hit!");
                    }
                } 
                else if (node.gameObject.GetName() == "Projectile") {
                    auto projMovement = node.gameObject.getComponent!ProjectileMovementScript();
                    if (projMovement) {
                        if (projMovement.getIsPlayerProjectile()) {
                            checkTurretProjectileCollisions(node.gameObject);
                        } else {
                            checkEnemyProjectileCollisions(node.gameObject, turret);
                        }
                    }
                }
            } else {
                return;
            }
        });
    }

    private void checkTurretProjectileCollisions(GameObject projectile) {
        // checking if turret's projectile kills an enemy
        auto projectileCollision = projectile.getComponent!CollisionComponent();

        // Find the turret to update its score
        GameObject turret;
        sceneTree.traverse((SceneNode node) {
            if (node.gameObject && node.gameObject.GetName() == "Turret") {
                turret = node.gameObject;
            }
        });
        
        if (!turret) return;  // Safety check
        auto scoreComp = turret.getComponent!ScoreComponent();

        sceneTree.traverse((SceneNode node) {
            if (node.gameObject && node.gameObject.GetName() == "Enemy") {
                if (projectileCollision.checkCollision(node.gameObject)) {
                    projectile.active = false;

                    // Update score before starting death animation
                    if (scoreComp) {
                        scoreComp.increaseScore(100);  // 100 points per enemy
                        // scoreComp.debugPrintScore();
                        // writeln("Score increased! Current score: ", scoreComp.getScore());
                    }

                    audioManager.playSound("explosion");
                    
                    // Start death rotation instead of immediately deactivating
                    auto rotationComp = node.gameObject.getComponent!DeathRotationComponent();
                    if (rotationComp) {
                        rotationComp.startDeathRotation();
                    }
                    writeln("Enemy hit! Starting death rotation");
                }
            }
        });
    }

    private void checkEnemyProjectileCollisions(GameObject projectile, GameObject turret) {
        auto projectileCollision = projectile.getComponent!(CollisionComponent)();
        auto turretCollision = turret.getComponent!(CollisionComponent)();
        if (projectileCollision && turretCollision && 
            projectileCollision.checkCollision(turret)) {
            endGame(false, "You got hit. Game Over.");
        }
    }

    private void checkGameEndConditions() {
        bool enemiesExist = false;
        GameObject turret;

        sceneTree.traverse((SceneNode node) {
            if (node.gameObject) {
                if (node.gameObject.GetName() == "Enemy" && node.gameObject.active) {
                    enemiesExist = true;
                }
                if (node.gameObject.GetName() == "Turret") {
                    turret = node.gameObject;
                }
            }
        });

        if (!enemiesExist) {
            endGame(true, "You won!");
        }
    }

    private void endGame(bool victory, string message) {
        writeln(message);
        isComplete = true;
        nextScene = "gameover";
        
        // Find turret through scene tree to get final score
        sceneTree.traverse((SceneNode node) {
            if (node.gameObject && node.gameObject.GetName() == "Turret") {
                auto scoreComp = node.gameObject.getComponent!ScoreComponent();
                if (scoreComp) {
                    GameOverScene.finalScore = scoreComp.getScore();
                    GameOverScene.playerWon = victory;
                }
            }
        });

        // sceneTree.traverse((SceneNode node) {
        //     if (node.gameObject) {
        //         node.gameObject.active = false;
        //     }
        // });
    }
}

// Game over scene
class GameOverScene : Scene {
    static int finalScore = 0;  // Static to persist between scene changes
    static bool playerWon = false;
    
    private GameObject messageDisplay;
    private GameObject scoreDisplay;

    this(SDL_Renderer* mRenderer, ResourceManager resourceManager, AudioManager audioManager) {
        super(mRenderer, resourceManager, audioManager);
    }

    override void Initialize() {
        // Create game over or victory message
        string spritePath = playerWon ? "assets/youwin.bmp" : "assets/gameover.bmp";
        auto sprite = new Sprite(resourceManager, spritePath, 
                               WINDOW_WIDTH/2 - 200, WINDOW_HEIGHT/2 - 100,
                               400, 200);
        
        messageDisplay = new GameObject("Message", WINDOW_WIDTH/2 - 100, WINDOW_HEIGHT/2 - 50);
        messageDisplay.AddComponent(new RenderComponent(messageDisplay, sprite));
        
        auto node = new SceneNode(messageDisplay);
        messageDisplay.node = node;
        sceneTree.addNode(node);

        // Create score display
        scoreDisplay = new GameObject("Score", WINDOW_WIDTH/2 - 50, WINDOW_HEIGHT/2 + 50);
        scoreDisplay.AddComponent(new ScoreComponent(scoreDisplay, mRenderer, resourceManager));
        scoreDisplay.getComponent!ScoreComponent().setScore(finalScore);
        
        auto scoreNode = new SceneNode(scoreDisplay);
        scoreDisplay.node = scoreNode;
        sceneTree.addNode(scoreNode);
    }

    override void Update() {
        SDL_Event event;
        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_QUIT) {
                isComplete = true;
                nextScene = "quit";
            }
            // else if (event.type == SDL_KEYDOWN) {
            //     // restart game functionality
            //     if (event.key.keysym.sym == SDLK_SPACE) {
            //         isComplete = true;
            //         nextScene = "gameplay"; 
            //         sceneTree.traverse((SceneNode node) {
            //             if (node.getParent) {
            //                 node.getParent.removeChild(node);
            //             }
            //             if (node.gameObject) {
            //                 node.gameObject.active = false;
            //                 destroy(node.gameObject);
            //             }
            //         });

            //         destroy(sceneTree);
            //         sceneTree = new SceneTree();
            //     }
            // }
        }
    }

    override void Render() {
        SDL_SetRenderDrawColor(mRenderer, 5, 50, 100, SDL_ALPHA_OPAQUE);
        SDL_RenderClear(mRenderer);

        sceneTree.traverse((SceneNode node) {
            if (node.gameObject && node.gameObject.active) {
                node.gameObject.Render(mRenderer);
            }
        });

        SDL_RenderPresent(mRenderer);
    }

    override void Cleanup() {
        // Cleanup will happen through the SceneTree destructor
    }
}