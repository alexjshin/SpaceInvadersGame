module factory;

import std.stdio;
import bindbc.sdl;
import gameobject;
import sprite;
import component;
import scenetree;
import constants;
import resourcemanager;
import animation;
import audiomanager;

GameObject createTurretObject(SDL_Renderer* renderer, ResourceManager resourceManager, SceneTree sceneTree, AudioManager audioManager) {
    auto turret = new GameObject("Turret", PLAYER_START_X, PLAYER_START_Y);
    auto sprite = new Sprite(resourceManager, "assets/player.bmp", PLAYER_START_X, PLAYER_START_Y, TURRET_WIDTH, TURRET_HEIGHT);

    turret.AddComponent(new RenderComponent(turret, sprite));
    turret.AddComponent(new PlayerMovementScript(turret, PLAYER_MOVE_SPEED));
    turret.AddComponent(new PlayerShootingScript(turret, renderer, sceneTree, audioManager));
    turret.AddComponent(new CollisionComponent(turret, TURRET_WIDTH, TURRET_HEIGHT));
    turret.AddComponent(new ScoreComponent(turret, renderer, resourceManager));

    auto node = new SceneNode(turret);
    turret.node = node;
    sceneTree.addNode(node);

    return turret;
}

GameObject createEnemyObject(SDL_Renderer* renderer, ResourceManager resourceManager, SceneTree sceneTree, AudioManager audioManager, 
                            SceneNode parent = null, string spriteFilePath = "assets/enemy_sheet.bmp") {
    auto enemy = new GameObject("Enemy", 0, 0);
    auto sprite = new Sprite(resourceManager, spriteFilePath, 50, 50,
                           ENEMY_WIDTH, ENEMY_HEIGHT);

    // Initialize Animations
    sprite.initializeAnimations(renderer, "assets/enemy_animations.json");

    enemy.AddComponent(new AnimationSequenceComponent(enemy, sprite.mAnimations));
    enemy.AddComponent(new RenderComponent(enemy, sprite));
    enemy.AddComponent(new EnemyMovementScript(enemy, ENEMY_MOVE_SPEED, WINDOW_WIDTH, ENEMY_WIDTH));
    enemy.AddComponent(new EnemyShootingScript(enemy, renderer, sceneTree, audioManager));
    enemy.AddComponent(new CollisionComponent(enemy, ENEMY_WIDTH, ENEMY_HEIGHT));
    enemy.AddComponent(new DeathRotationComponent(enemy));

    auto node = new SceneNode(enemy);
    enemy.node = node;
    sceneTree.addNode(node);

    return enemy;
}

GameObject createProjectileObject(SDL_Renderer* renderer, ResourceManager resourceManager, SceneNode parent, 
                            int startX, int startY, 
                            bool is_turret_projectile, int speed = -10,
                            string spriteFilePath = "assets/projectile.bmp") {
    writeln("Creating projectile with speed: ", speed);
    auto projectile = new GameObject("Projectile", startX, startY);

    auto node = new SceneNode(projectile);
    projectile.node = node;
    // writeln("Adding projectile to parent node");
    parent.addChild(node);
    
    int width = is_turret_projectile ? TURRET_PROJECTILE_WIDTH : ENEMY_PROJECTILE_WIDTH;
    int height = is_turret_projectile ? TURRET_PROJECTILE_HEIGHT : ENEMY_PROJECTILE_HEIGHT;
    
    auto sprite = new Sprite(resourceManager, spriteFilePath, startX, startY, width, height);
    
    // writeln("Adding components to projectile");
    projectile.AddComponent(new RenderComponent(projectile, sprite));
    projectile.AddComponent(new ProjectileMovementScript(projectile, speed, is_turret_projectile));
    // writeln("Added ProjectileMovementComponent with speed: ", speed);
    projectile.AddComponent(new CollisionComponent(projectile, width, height));


    return projectile;
}

GameObject[] createEnemyGrid(SDL_Renderer* renderer, ResourceManager resourceManager, SceneTree sceneTree, AudioManager audioManager,
                           string spriteFilePath = "assets/enemy_sheet.bmp",
                           int screenWidth = WINDOW_WIDTH, int screenHeight = WINDOW_HEIGHT) {
    auto formationNode = new SceneNode(null);
    sceneTree.addNode(formationNode);

    GameObject[] enemies;
    int topSectionHeight = screenHeight / 3;
    int columns = (screenWidth + GRID_SPACING) / (ENEMY_WIDTH + GRID_SPACING);
    int rows = (topSectionHeight + GRID_SPACING) / (ENEMY_HEIGHT + GRID_SPACING);

    int startY = 40;
    int startX = (screenWidth - (columns * (ENEMY_WIDTH + GRID_SPACING))) / 2;

    for (int row = 0; row < rows; ++row) {
        for (int col = 0; col < columns; ++col) {
            auto enemy = createEnemyObject(renderer, resourceManager, sceneTree, audioManager, formationNode, spriteFilePath);
            enemy.x = startX + col * (ENEMY_WIDTH + GRID_SPACING);
            enemy.y = startY + row * (ENEMY_HEIGHT + GRID_SPACING);
            enemies ~= enemy;
        }
    }

    return enemies;
}
