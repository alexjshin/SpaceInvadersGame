module scenetree;

import gameobject;
import std.stdio;
import std.algorithm;
import std.array;

class SceneNode {
    private {
        GameObject mGameObject;
        SceneNode parent;
        SceneNode[] children;
    }

    @property GameObject gameObject() { return mGameObject; }
    @property void gameObject(GameObject obj) { mGameObject = obj; }
    @property SceneNode getParent() { return parent; }

    this (GameObject obj = null) {
        this.mGameObject = obj;
    }

    void addChild(SceneNode child) {
        if (child !is null) {
            // writeln("Adding child node to scene tree");
            if (child.gameObject) {
                // writeln("Child GameObject position before add: (", 
                //         child.gameObject.x, ",", child.gameObject.y, ")");
            }
        
            children ~= child;
            child.parent = this;

            if (child.gameObject) {
                // writeln("Child GameObject position after add: (", 
                //         child.gameObject.x, ",", child.gameObject.y, ")");
            }
        }
    }

    void removeChild(SceneNode child) {
        if (child !is null) {
            children = children.filter!(n => n !is child).array;
            child.parent = null;
        }
    }

    void traverse(void delegate(SceneNode) func) {
        // writeln("Traversing node", mGameObject ? " with GameObject: " ~ mGameObject.GetName() : " (no GameObject)");
        func(this);
        foreach (child; children) {
            child.traverse(func);
        }
    }
}

class SceneTree {
    private {
        SceneNode root;
    }    

    this() {
        root = new SceneNode();
    }

    @property SceneNode getRoot() { return root; }

    void addNode(SceneNode node, SceneNode parent = null) {
        if (parent is null){ // no parent was specified
            if (root.mGameObject is null) { // root node hasn't been set
                root = node; // make this node the root
            } else { // if no parent is specified make the node a child of the root
                root.addChild(node);
            }
        } else { // add child to specified parent
            parent.addChild(node);
        }
    }

    void traverse(void delegate(SceneNode) func) {
        root.traverse(func);
    }
}
