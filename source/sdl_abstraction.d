// Load the SDL2 library
module sdl_abstraction;

import std.stdio;
import std.string;

import bindbc.sdl;
import bindbc.sdl.mixer;
import loader = bindbc.loader.sharedlib;
// global variable for sdl;
const SDLSupport ret;
const SDLMixerSupport mixerRet;
/// At the module level we perform any initialization before our program
/// executes. Effectively, what I want to do here is make sure that the SDL
/// library successfully initializes.
shared static this(){
		// Load the SDL libraries from bindbc-sdl
		// on the appropriate operating system
    version(Windows){
        writeln("Searching for SDL on Windows");
        ret = loadSDL("SDL2.dll");
        mixerRet = loadSDLMixer("SDL2_mixer.dll");
    }
  	version(OSX){
      	writeln("Searching for SDL on Mac");
        ret = loadSDL();

        const(char)* mixerPath = "/opt/homebrew/lib/libSDL2_mixer.dylib".ptr;
        writeln("Attempting to load SDL_Mixer from: ", fromStringz(mixerPath));
        mixerRet = loadSDLMixer(mixerPath);

        // Print detailed SDL_Mixer loading status
        final switch(mixerRet) {
            case SDLMixerSupport.noLibrary:
                writeln("SDL_Mixer: No library found");
                writeln("Detailed error information:");
                foreach(info; loader.errors) {
                    writeln(" - ", info.error, ": ", info.message);
                }
                break;
            case SDLMixerSupport.badLibrary:
                writeln("SDL_Mixer: Bad library version");
                writeln("Detailed error information:");
                foreach(info; loader.errors) {
                    writeln(" - ", info.error, ": ", info.message);
                }
                break;
            case SDLMixerSupport.sdlMixer200:
                writeln("SDL_Mixer: Successfully loaded SDL_Mixer 2.0.0");
                break;
            case SDLMixerSupport.sdlMixer201:
                writeln("SDL_Mixer: Successfully loaded SDL_Mixer 2.0.1");
                break;
            case SDLMixerSupport.sdlMixer202:
                writeln("SDL_Mixer: Successfully loaded SDL_Mixer 2.0.2");
                break;
            case SDLMixerSupport.sdlMixer204:
                writeln("SDL_Mixer: Successfully loaded SDL_Mixer 2.0.4");
                break;
            case SDLMixerSupport.sdlMixer260:
                writeln("SDL_Mixer: Successfully loaded SDL_Mixer 2.6.0");
                break;
        }
    }
    version(linux){ 
        writeln("Searching for SDL on Linux");
        ret = loadSDL();
        mixerRet = loadSDLMixer();
    }

		// Error if SDL cannot be loaded
    if(ret != sdlSupport){
        writeln("error loading SDL library");    
        foreach( info; loader.errors){
            writeln(info.error,':', info.message);
        }
    }
    if(ret == SDLSupport.noLibrary){
        writeln("error no library found");    
    }
    if(ret == SDLSupport.badLibrary){
        writeln("Eror badLibrary, missing symbols, perhaps an older or very new version of SDL is causing the problem?");
    }

    if (mixerRet != sdlMixerSupport){
        writeln("error loading SDL_mixer library");    
        foreach( info; loader.errors){
            writeln(info.error,':', info.message);
        }
    }

    // Initialize SDL
    if(SDL_Init(SDL_INIT_EVERYTHING) !=0){
        writeln("SDL_Init: ", fromStringz(SDL_GetError()));
    }

    // Initialize SDL_Mixer
    if (Mix_OpenAudio(48_000, AUDIO_S16SYS, 2, 4096) < 0)
    {
        writeln("Mix_OpenAudio: ", fromStringz(Mix_GetError()));
    }
}

/// At the module level, when we terminate, we make sure to 
/// terminate SDL, which is initialized at the start of the application.
shared static ~this(){
    Mix_CloseAudio();
    writeln("Closing SDL_mixer");

    // Quit the SDL Application 
    SDL_Quit();
		writeln("Ending application--good bye!");
}
