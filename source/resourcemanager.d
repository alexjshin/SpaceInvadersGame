module resourcemanager;

import std.stdio;
import std.string;
import std.container.rbtree;
import bindbc.sdl;
import core.atomic;

class ResourceManager {
    private {
        struct TextureInfo {
            SDL_Texture* texture;
            shared int refCount;
        }
        
        TextureInfo[string] textureCache;
        SDL_Renderer* renderer;
    }

    this(SDL_Renderer* renderer) {
        this.renderer = renderer;
        writeln("ResourceManager initialized");
    }

    SDL_Texture* getTexture(string filepath) {
        // Check if texture is already loaded
        if (auto textureInfo = filepath in textureCache) {
            // Increment reference count
            atomicOp!"+="(textureInfo.refCount, 1);
            // writeln("Reusing texture: ", filepath, " (RefCount: ", textureInfo.refCount, ")");
            return textureInfo.texture;
        }

        writeln("Loading new texture: ", filepath);
        
        // Load new texture
        SDL_Surface* surface = SDL_LoadBMP(filepath.toStringz);
        if (surface is null) {
            writeln("Failed to load bitmap: ", SDL_GetError());
            return null;
        }
        scope(exit) SDL_FreeSurface(surface);

        SDL_Texture* texture = SDL_CreateTextureFromSurface(renderer, surface);
        if (texture is null) {
            writeln("Failed to create texture: ", SDL_GetError());
            return null;
        }

        // Store in cache with initial reference count of 1
        textureCache[filepath] = TextureInfo(texture, 1);
        return texture;
    }

    void releaseTexture(string filepath) nothrow @nogc {
        try {
            if (auto textureInfo = filepath in textureCache) {
                // Decrement reference count
                auto newCount = atomicOp!"-="(textureInfo.refCount, 1);
                
                if (newCount <= 0) {
                    if (textureInfo.texture !is null) {
                        SDL_DestroyTexture(textureInfo.texture);
                        textureInfo.texture = null;
                    }
                    textureCache.remove(filepath);
                }
            }
        } catch (Exception e) {
            // Can't do anything in nothrow function
        }
    }
}