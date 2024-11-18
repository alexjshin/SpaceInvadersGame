module audiomanager;

import std.stdio;
import std.string;
import bindbc.sdl;
import bindbc.sdl.mixer;

class AudioManager {
    private {
        Mix_Chunk*[string] soundEffects;
    }

    this() {
        // Allocate channels for sound effects
        Mix_AllocateChannels(4);  // We only need a few channels for our sounds
    }

    ~this() {
        // Free all loaded sounds
        foreach (key, chunk; soundEffects) {
            if (chunk !is null) {
                Mix_FreeChunk(chunk);
            }
        }
    }

    bool loadSound(string name, string filepath) {
        if (name in soundEffects) {
            writeln("Sound effect already loaded: ", name);
            return true;
        }

        Mix_Chunk* chunk = Mix_LoadWAV(filepath.toStringz);
        if (chunk is null) {
            writeln("Failed to load sound effect! SDL_mixer Error: ", fromStringz(Mix_GetError()));
            return false;
        }

        soundEffects[name] = chunk;
        return true;
    }

    void playSound(string name) {
        if (auto sound = name in soundEffects) {
            Mix_PlayChannel(-1, *sound, 0);
        } else {
            writeln("Sound effect not found: ", name);
        }
    }
}