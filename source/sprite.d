module sprite;

import std.stdio;
import std.string;
import std.file;
import bindbc.sdl;
import resourcemanager;
import animation;

struct Sprite {
    AnimationSequences* mAnimations;
    private {
        SDL_Texture* mTexture;
        SDL_Rect     mRectangle;
        string       mFilePath;
        ResourceManager mResourceManager;
    }

    @property ResourceManager resourceManager() { return mResourceManager; }
    @property SDL_Texture* texture() { return mTexture; }
    @property SDL_Rect* destRect() { return &mRectangle; }

    this(ResourceManager resourceManager, string bitmapFilePath, int x, int y, int width, int height) {
        if (resourceManager is null) {
            writeln("Warning: null ResourceManager passed to Sprite constructor");
            return;
        }
        mResourceManager = resourceManager;
        mFilePath = bitmapFilePath;
        mTexture = resourceManager.getTexture(bitmapFilePath);
        if (mTexture is null) {
            writeln("ERROR: Failed to load texture: ", bitmapFilePath);
        } else {
            writeln("Successfully loaded texture: ", bitmapFilePath);
        }
        mRectangle = SDL_Rect(x, y, width, height);
        writeln("Created sprite with dest rect: x=", x, " y=", y, " w=", width, " h=", height);
    }

    void initializeAnimations(SDL_Renderer* renderer, string jsonPath) {
        try {
            writeln("Attempting to initialize animations from: ", jsonPath);
            mAnimations = new AnimationSequences(renderer, mTexture, &mRectangle);
            mAnimations.Load(jsonPath);
            writeln("Successfully loaded animations");
        } catch (Exception e) {
            writeln("ERROR loading animations: ", e.msg);
        }
    }

    void changePos(int x, int y) {
        mRectangle.x = x;
        mRectangle.y = y;
    }

    void Render(SDL_Renderer* renderer) {
        if (mTexture !is null && renderer !is null) {
            if (mAnimations !is null) {
                // Animation will handle the rendering
                mAnimations.LoopAnimationSequence("idle");
                return;
            }
            // Default rendering if no animation
            SDL_RenderCopy(renderer, mTexture, null, &mRectangle);
        }
    }
}