/// Run with: 'dub'
import std.stdio;
import core.stdc.stdlib;
import gameapplication;

// Entry point to program
void main()
{
	GameApplication app = new GameApplication("Space Invaders!");
	app.RunLoop();
}
