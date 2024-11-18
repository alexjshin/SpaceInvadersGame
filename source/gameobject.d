module gameobject;

import std.stdio;
import std.algorithm;
import core.atomic;
import bindbc.sdl;
import sprite;
import component;
import scenetree;

class GameObject {
    private {
        string mName;
        size_t mID;
        IComponent[] mComponents;
        static shared size_t sGameObjectCount = 0;
        SceneNode sceneNode;
    }

    public {
        int x;
        int y;
        bool active = true;
    }

    this(string name, int x, int y) {
        assert(name.length > 0, "GameObject name cannot be empty");
        this.mName = name;
        this.x = x;
        this.y = y;
        // writeln("GameObject '", name, "' created at position: (", x, ",", y, ")");
        mID = sGameObjectCount.atomicOp!"+="(1);
    }

    void Update() {
        if (!active){
            // writeln("GameObject '", mName, "' is not active, skipping update");
            // destroy(this);
            return;
        }
        // writeln("Updating GameObject '", mName, "' with ", mComponents.length, " components");
        foreach (component; mComponents) {
            // writeln("  Updating component of type: ", typeid(component));
            component.Update();
        }
    }

    void Render(SDL_Renderer* renderer) {
        if (!active) return;
        foreach (component; mComponents) {
            component.Render(renderer);
        }
    }

    void AddComponent(IComponent component) {
        if (component !is null) {
            mComponents ~= component;
        }
    }

    T getComponent(T : IComponent)() {
        foreach (comp; mComponents) {
            if (auto cast_comp = cast(T)comp) {
                return cast_comp;
            }
        }
        return null;
    }

    string GetName() const { return mName; }
    size_t GetID() const { return mID; }
    @property SceneNode node() { return sceneNode; } // getter
    @property void node(SceneNode node) { sceneNode = node; } // setter
}