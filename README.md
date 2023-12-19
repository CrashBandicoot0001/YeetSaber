# Yeet Saber
This is a fork of [Open Saber VR](https://github.com/dhcdht/OpenSaberVR) which itself is a fork of [Beep Saber by NeoSpark314](https://github.com/NeoSpark314/BeepSaber) which ported it from Godot 3.x to Godot 4.2 and OpenXR (WIP)
(The OQ Toolkit is only partially ported/patched for it to work on Godot 4 with OpenXR, most features that are not used in this project will not work)

This fork intends to extend it from a demo to a full game. 

# TODO

Expose resolution scale settings, Expose antialiasing settings, Expose mirror settings, Upgrade glow to Godot 4 method so it works, Expose and add more particle settings, Implement Health system, Implement speed modifiers, Implement NJS override, Implement NJD override, Add backend to online leaderboard, Implement progress bar for BeatSaver downloads, lock framerate counter to playfield and add color changing ring bar, Replace default environment, Implement custom platform parser, Implement avatar parser, Implement saber parser, Implement custom block parser,  Implement custom mine parser, Implement custom sounds, Implement custom menu music, Make saber adjustment fields expose numpad and add tooltips for what they are doing, Implement swing assist or whatever its called, Implement twitch chat, Implement song requests, Implement filters for downloaded songs, Implement UI Theming, Expose audio offset adjustment, Expose volume control, Implement ghost notes, Implement half ghost notes, Implement audio offset wizzard, Implement hit statistics on result screen, Impliment global statistics, Implement customization for hitscorevisualizatizer, Implement clock, Implement room adjust, Implement practice mode, Implement saber color presets (as far as I could tell) Fix not being able to set environment different colors than sabers, Add wall presets, Implement multiplayer, Implement replays, Implement playlists, Implement favorites, Implement occlusion culling, Expose song duration on song select screen, Implement Difficulty calculation, Implement CountersPlus



# Info

This is a partial implementation of the beat saber game mechanic using [Godot Game Engine](https://godotengine.org/) and [Godot Oculus Quest Toolkit](https://github.com/NeoSpark314/godot_oculus_quest_toolkit). The main objective of this project is to make a highly optimized and deeply extensible Bloq slicing game without relying on mods. 

The target platform is Oculus Quest but it could also work with SteamVR if the OpenVR plugin is added to the addons folder in the godot project.

Originally this prject was (and still is) a demo game as part of the Godot Oculus Quest Toolkit. To keep the demo implementation small
this stand alone version was forked so that it can be changed and developed independent of the original demo.


# About the implementation
This game uses godot 4.2-dev4. The implementation supports to load and play maps from [BeatSaver](https://beatsaver.com/).

There is one demo song included that is part of the deployed package.

You can play custom songs by downloading them in the in-game menu. 

# Credits
The included Music Track is Time Lapse by TheFatRat (https://www.youtube.com/watch?v=3fxq7kqyWO8)

# Licensing
The source code of the godot beep saber / open saber / Yeet Saber game in this repository is licensed under an MIT License.


