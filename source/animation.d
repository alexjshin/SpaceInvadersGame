// animation.d
module animation;

import std.stdio;
import std.algorithm;
import std.conv;
import std.array;
import std.json;
import std.file;
import bindbc.sdl;
// import component;

struct Frame {
    SDL_Rect mRect;
}

struct AnimationSequences {
    // Store file name of data for sequences
    string mFilename;
    // all possible frames that are part of a sprite
    Frame[] mFrames;
    // Array for the named sequence of an animation
    long[][string] mFrameNumbers;
    // Current animation sequence state info
    string mCurrentAnimationName;
    long mCurrentFramePlaying;
    long mLastFrameInSequence;
    // References to the Sprites data
    SDL_Renderer* mRendererRef;
    SDL_Texture* mTextureRef;
    SDL_Rect*    mRectRef;

    // Time tracking for animation
    uint         lastFrameTime;
    uint         frameDelay = 500;

    this(SDL_Renderer* r, SDL_Texture* tex_reference, SDL_Rect* rect) {
        mRendererRef = r;
        mTextureRef = tex_reference;
        mRectRef = rect;
        lastFrameTime = SDL_GetTicks();
    }

    void LoopAnimationSequence(string name) {
        // if (name != mCurrentAnimationName) {
        //     mCurrentAnimationName = name;
        //     mCurrentFramePlaying = 0;
        //     mLastFrameInSequence = cast(long)mFrameNumbers[name].length - 1;
        // }
        // long frameIndex = mFrameNumbers[name][mCurrentFramePlaying];
        // SDL_Rect srcRect = mFrames[frameIndex].mRect;
        // SDL_RenderCopy(mRendererRef, mTextureRef, &srcRect, mRectRef);
        // mCurrentFramePlaying = (mCurrentFramePlaying + 1) % (mLastFrameInSequence + 1);
        // Check if it's time to change frames
        uint currentTime = SDL_GetTicks();
        if (currentTime - lastFrameTime >= frameDelay) {
            // Time to advance to next frame
            if (name != mCurrentAnimationName) {
                mCurrentAnimationName = name;
                mCurrentFramePlaying = 0;
                mLastFrameInSequence = cast(long)mFrameNumbers[name].length - 1;
            } else {
                // Only advance frame if we're in the same animation
                mCurrentFramePlaying = (mCurrentFramePlaying + 1) % (mLastFrameInSequence + 1);
            }
            lastFrameTime = currentTime;
        }

        // Always render the current frame
        long frameIndex = mFrameNumbers[name][mCurrentFramePlaying];
        SDL_Rect srcRect = mFrames[frameIndex].mRect;
        SDL_RenderCopy(mRendererRef, mTextureRef, &srcRect, mRectRef);
    }

    void Load(string filename) {
        mFilename = filename;
        string jsonContent = readText(filename);
        JSONValue json = parseJSON(jsonContent);
        
        // Parse width, height, tileWidth, and tileHeight from JSON
        int width = json["format"]["width"].integer.to!int;
        int height = json["format"]["height"].integer.to!int;
        int tileWidth = json["format"]["tileWidth"].integer.to!int;
        int tileHeight = json["format"]["tileHeight"].integer.to!int;

        // Create frames and add to mFrames
        int columns = width / tileWidth;
        int rows = height / tileHeight;
        for (int y = 0; y < rows; y++) {
            for (int x = 0; x < columns; x++) {
                Frame frame;
                frame.mRect = SDL_Rect(x * tileWidth, y * tileHeight, tileWidth, tileHeight);
                mFrames ~= frame;
            }
        }

        // Parse frames section
        foreach (string key, JSONValue value; json["frames"]) {
            long[] frameNumbers;
            foreach (JSONValue frameNumber; value.array) {
                frameNumbers ~= frameNumber.integer;
            }
            mFrameNumbers[key] = frameNumbers;
        }
    }
}
