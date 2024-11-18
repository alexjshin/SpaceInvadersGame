module component;

import std.stdio;
import std.random;
import bindbc.sdl;
import gameobject;
import sprite;
import factory;
import scenetree;
import constants;
import animation;
import resourcemanager;
import audiomanager;

interface IComponent {
    void Update();
    void Render(SDL_Renderer* renderer);
}

abstract class BaseComponent : IComponent {
    protected GameObject owner;

    this(GameObject owner) {
        this.owner = owner;
    }

    void Update() {}
    void Render(SDL_Renderer* renderer) {}
}

abstract class ScriptComponent : BaseComponent {
    this(GameObject owner) {
        super(owner);
    }

    void start() {} // Called when script is first initialized
    void onCollision(GameObject other) {} // Called on collision
}

class RenderComponent : BaseComponent {
    private {
        Sprite* sprite;
        // for debugging
        static int renderCounter = 0;
        int renderId;
    }
    this(GameObject owner, Sprite* sprite) {
        super(owner);
        this.sprite = sprite;
        this.renderId = ++renderCounter;
    }

    override void Update() {
        // writeln("Updating RenderComponent ID ", renderId, " at: (", 
        //         owner.x, ",", owner.y, ")");
        sprite.changePos(owner.x, owner.y);
    }

    override void Render(SDL_Renderer* renderer) {
        // writeln("RenderComponent ID ", renderId, " rendering at: (", 
        //         owner.x, ",", owner.y, ")");
        auto deathComponent = owner.getComponent!DeathRotationComponent();
        if (deathComponent && deathComponent.isRotating) {
            // deathComponent.Render(renderer);
            return;
        }
        sprite.Render(renderer);
    }
}

class PlayerMovementScript : ScriptComponent {
    private int speed;

    this(GameObject owner, int speed) {
        super(owner);
        this.speed = speed;
    }

    override void Update() {
        const ubyte* keyState = SDL_GetKeyboardState(null);
        if (keyState[SDL_SCANCODE_A] || keyState[SDL_SCANCODE_LEFT]) owner.x -= speed;
        if (keyState[SDL_SCANCODE_D] || keyState[SDL_SCANCODE_RIGHT]) owner.x += speed;
    }
}

class EnemyMovementScript : ScriptComponent {
    private {
        int speed;
        bool movingRight;
        int screenWidth;
        int enemyWidth;
    }

    this(GameObject owner, int speed = 2, int screenWidth = WINDOW_WIDTH, int enemyWidth = ENEMY_WIDTH) {
        super(owner);
        this.speed = speed;
        this.movingRight = true;
        this.screenWidth = screenWidth;
        this.enemyWidth = enemyWidth;
    }

    override void Update() {
        if (movingRight) {
            owner.x += speed;
        } else {
            owner.x -= speed;
        }

        if (owner.x <= 0) {
            owner.x = 0;
            owner.y += ENEMY_HEIGHT;
            movingRight = true;
        }
        else if (owner.x >= screenWidth - enemyWidth) {
            owner.x = screenWidth - enemyWidth;
            owner.y += ENEMY_HEIGHT;
            movingRight = false;
        }
    }
}

class ProjectileMovementScript : ScriptComponent {
    private {
        int speed;
        bool isPlayerProjectile;
        static int projectileCounter = 0;
        int projectileId;
    }

    this(GameObject owner, int speed, bool isPlayerProjectile) {
        super(owner);
        this.speed = speed;
        this.isPlayerProjectile = isPlayerProjectile;
        this.projectileId = ++projectileCounter;
    }

    override void Update() {
        int oldY = owner.y;
        owner.y += speed;

        if (owner.y < 0 || owner.y > WINDOW_HEIGHT) {
            owner.active = false;
            if (owner.node && owner.node.getParent) {
                owner.node.getParent.removeChild(owner.node);
                writeln("Removed projectile ID ", projectileId, " from scene tree at y: ", owner.y);
            }
        }
    }

    bool getIsPlayerProjectile() { return isPlayerProjectile; }
}

// Shooting Scripts
class PlayerShootingScript : ScriptComponent {
    private {
        SDL_Renderer* renderer;
        SceneTree sceneTree;
        AudioManager audioManager;
        string projectileSpritePath;
        int lastShot;
    }

    this(GameObject owner, SDL_Renderer* renderer, SceneTree sceneTree, 
         AudioManager audioManager, string projectileSpritePath = "assets/projectile.bmp") {
        super(owner);
        this.renderer = renderer;
        this.sceneTree = sceneTree;
        this.audioManager = audioManager;
        this.projectileSpritePath = projectileSpritePath;
        this.lastShot = 0;
    }

    override void Update() {
        const ubyte* keyState = SDL_GetKeyboardState(null);
        if (keyState[SDL_SCANCODE_SPACE] && canFire()) {
            fire();
        }
    }

    private void fire() {
        auto projectile = createProjectileObject(
            renderer,
            owner.getComponent!(RenderComponent)().sprite.resourceManager,
            sceneTree.getRoot,
            owner.x + 26,
            owner.y - 32,
            true,
            -7,
            projectileSpritePath
        );
        
        audioManager.playSound("shoot");
        lastShot = SDL_GetTicks();
    }

    private bool canFire() {
        bool existingProjectile = false;
        sceneTree.traverse((SceneNode node) {
            if (node.gameObject && 
                node.gameObject.GetName() == "Projectile" &&
                node.gameObject.active && 
                node.gameObject.getComponent!(ProjectileMovementScript).getIsPlayerProjectile()) {
                existingProjectile = true;
            }
        });
        return !existingProjectile;
    }
}

class EnemyShootingScript : ScriptComponent {
    private {
        SDL_Renderer* renderer;
        SceneTree sceneTree;
        AudioManager audioManager;
        int nextShotInterval;
        int lastShot;
    }

    this(GameObject owner, SDL_Renderer* renderer, SceneTree sceneTree, AudioManager audioManager) {
        super(owner);
        this.renderer = renderer;
        this.sceneTree = sceneTree;
        this.audioManager = audioManager;
        this.nextShotInterval = getRandomInterval();
        this.lastShot = 0;
    }

    override void Update() {
        if (!owner.active) return;

        int timeSinceLastShot = SDL_GetTicks() - lastShot;
        if (timeSinceLastShot >= nextShotInterval) {
            fire();
        }
    }

    private void fire() {
        auto projectile = createProjectileObject(
            renderer,
            owner.getComponent!(RenderComponent)().sprite.resourceManager,
            sceneTree.getRoot,
            owner.x + 4,
            owner.y + 12,
            false,
            3,
            "assets/enemyProjectile.bmp"
        );
        
        lastShot = SDL_GetTicks();
        nextShotInterval = getRandomInterval();
    }

    private int getRandomInterval() {
        return uniform(0, 50000);
    }
}

class CollisionComponent : BaseComponent {
    private int width;
    private int height;

    this(GameObject owner, int width, int height) {
        super(owner);
        this.width = width;
        this.height = height;
    }

    bool checkCollision(GameObject other) {
        auto otherCollision = other.getComponent!(CollisionComponent)();
        if (!otherCollision) return false;
        
        return !(owner.x + width < other.x ||
                 owner.x > other.x + otherCollision.width ||
                 owner.y + height < other.y ||
                 owner.y > other.y + otherCollision.height);
    }
}

// Add a component to handle the animation
class AnimationSequenceComponent : BaseComponent {
    private {
        AnimationSequences* sequences;
        string currentAnimation;
    }

    this(GameObject owner, AnimationSequences* sequences) {
        super(owner);
        this.sequences = sequences;
        this.currentAnimation = "idle";
    }

    override void Update() {
        if (sequences !is null) {
            sequences.LoopAnimationSequence(currentAnimation);
        }
    }

    void playAnimation(string name) {
        currentAnimation = name;
    }
}

class DeathRotationComponent : BaseComponent {
    bool isRotating = false;
    private {
        double totalRotation = 0.0;
        double rotationSpeed = 720.0;  // Degrees per second (2 full rotations per second)
        uint startTime;
    }

    this(GameObject owner) {
        super(owner);
    }

    void startDeathRotation() {
        isRotating = true;
        startTime = SDL_GetTicks();
        totalRotation = 0.0;
    }

    override void Update() {
        if (!isRotating) return;

        uint currentTime = SDL_GetTicks();
        float deltaTime = (currentTime - startTime) / 1000.0f;
        totalRotation = rotationSpeed * deltaTime;

        // Check if we've completed a 360-degree rotation
        if (totalRotation >= 360.0) {
            isRotating = false;
            owner.active = false;
        }
    }

    override void Render(SDL_Renderer* renderer) {
        if (!isRotating) return;

        auto renderComp = owner.getComponent!RenderComponent();
        if (renderComp && renderComp.sprite) {
            auto sprite = renderComp.sprite;
            auto rect = sprite.destRect;

            // Get the current animation frame rect
            SDL_Rect srcRect;
            auto animComp = owner.getComponent!AnimationSequenceComponent();
            if (animComp && sprite.mAnimations) {
                // Get the current frame from the animation
                auto animations = sprite.mAnimations;
                string currentAnim = "idle";  // or whatever your animation is called
                long frameIndex = animations.mFrameNumbers[currentAnim][animations.mCurrentFramePlaying];
                srcRect = animations.mFrames[frameIndex].mRect;
            } else {
                // Fallback if no animation: use the first frame
                srcRect = SDL_Rect(0, 0, ENEMY_WIDTH, ENEMY_HEIGHT);
            }
            
            // Create a temporary rect for rotation that keeps the sprite centered
            SDL_Point center = {cast(int)(rect.w / 2), cast(int)(rect.h / 2)};
            SDL_Rect rotationRect = *rect;
            rotationRect.x = owner.x + center.x - (rect.w / 2);
            rotationRect.y = owner.y + center.y - (rect.h / 2);

            // Render with rotation
            SDL_RenderCopyEx(
                renderer,
                sprite.texture,
                &srcRect,
                &rotationRect,
                totalRotation % 360,
                &center,
                SDL_FLIP_NONE
            );
        }
    }
}

class ScoreComponent : BaseComponent {
    private {
        SDL_Renderer* renderer;
        ResourceManager resourceManager;
        int score = 0;
        string texturePath = "assets/digits.bmp";
        
        enum {
            CHAR_WIDTH = 32,
            CHAR_HEIGHT = 32,
            RENDER_WIDTH = 16,
            RENDER_HEIGHT = 16,
            START_X = 20,    // Starting X position
            START_Y = 20     // Starting Y position
        }
    }

    this(GameObject owner, SDL_Renderer* renderer, ResourceManager resourceManager) {
        super(owner);
        this.renderer = renderer;
        this.resourceManager = resourceManager;

        // Verify texture loads through resource manager
        if (resourceManager.getTexture(texturePath) is null) {
            writeln("Warning: Failed to load score texture: ", texturePath);
        }
    }

    override void Render(SDL_Renderer* renderer) {
        auto texture = resourceManager.getTexture(texturePath);
        if (texture is null) return;

        import std.conv : to;
        
        // Create rectangles for rendering
        SDL_Rect srcRect;
        srcRect.y = 0;
        srcRect.w = CHAR_WIDTH;
        srcRect.h = CHAR_HEIGHT;

        SDL_Rect destRect;
        destRect.y = START_Y;
        destRect.w = RENDER_WIDTH;
        destRect.h = RENDER_HEIGHT;

        // First render "Score: "
        string prefix = "Score: ";
        foreach (i, c; prefix) {
            int charIndex;
            switch (c) {
                case 'S': charIndex = 11; break;
                case 'c': charIndex = 12; break;
                case 'o': charIndex = 13; break;
                case 'r': charIndex = 14; break;
                case 'e': charIndex = 15; break;
                case ':': charIndex = 10; break;
                case ' ': continue;  // Skip spaces
                default: continue;
            }
            
            srcRect.x = charIndex * CHAR_WIDTH;
            destRect.x = START_X + (cast(int)i * CHAR_WIDTH);
            SDL_RenderCopy(renderer, texture, &srcRect, &destRect);
        }

        // Then render the score numbers
        string scoreStr = to!string(score);
        foreach (i, digit; scoreStr) {
            srcRect.x = (digit - '0') * CHAR_WIDTH;
            destRect.x = cast(int)(START_X + ((prefix.length + i) * CHAR_WIDTH));
            SDL_RenderCopy(renderer, texture, &srcRect, &destRect);
        }
    }

    void increaseScore(int points = 100) {
        score += points;
    }

    int getScore() {
        return score;
    }

    void setScore(int newScore) {
        score = newScore;
    }
}
