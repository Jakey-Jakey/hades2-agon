# AGON [ALPHA]

## Things to watch out for

This is the first public alpha. 

- **If the first launch or Versus entry crashes, relaunch and report it.** I think I've squashed this bug once and for all. Could come back though so if it happens you should be good to just keep trying and eventually it'll let you in if you encounter this bug. 
- **Games just freeze on finish.** After a match ends, The game just kinda dozes off and you'll have to pause and click "undo night" or close and reopen the game.
- **Weapons might be weird.** By the time of release most of the weapons should be good, but if there are some weird interactions or something isn't working quite how it should please let me know.
- **Balance is intentionally unfinished.** HP is set to 1000, Mana is set to 100, Players damage at a 1x scale to the normal game. I really don't know how this plays with two actually good players.
- **Added mechanic: Stuns.** To make this feel a bit more like it has actual strategy there is a very short 20ms (2fr) (or longer 50ms(3fr) stun if it's over 100 dmg) when you get hit by something. This is to reward players for landing big damage with the ability to get some more hits in or try and predict their enemies movements. I get the feeling without this it would feel kinda like a slapfight. But do let me know how it actually feels. I suspect those numbers might go up to make the matches feel better.
- **No art assets.** This mod is kinda ugly a little and needs to be beautified. If you are willing to contribute art assets please let me know, I don't even have a thunderstore icon yet.
- **Hades II updates can break the mod.** Idk if the game is updating or nah. If it does, I'm cooked.

## What it is

AGON, **Action Gaming Over Network** (embarrassing name when the alpha launch is local only pvp multiplayer), The current expectation and setup is two players, one PC, one arena, best-of-five rounds. And eventually add in everything else I want.

The alpha's job is to find out whether PvP Hades feels good, how much I gotta touch balencing, numbers that need tuning, and every single bug I can possibly smush with my bare hands.

I will also not be mentioning any of the online stuff on Thunderstore until that stuff is live. 

## Install

Install with r2modman.

AGON depends on:
- Hell2Modding
- Hades2ModExtension

The mod manager should install those dependencies automatically. If you install manually, please make sure both are installed first.

WE ARE CURRENTLY NOT (OFFICIALLY) COMPATIBLE WITH ANY MODS, CO-OP MOD SPECIFICALLY RUNNING ALONGSIDE THIS PROBABLY WILL BREAK SOMETHING. 

I would also advise against trying to make your mods compatible with mine until I finish the local Versus mode at least. I'm certain many things will change as I continue work. 

## Starting a match

1. Launch Hades II with AGON enabled.
2. Choose **Versus** from the gamemode menu.
3. Claim devices:
   - Player 1: keyboard + mouse or a gamepad
   - Player 2: a separate gamepad
4. Pick an arena and each player's Nocturnal Arm.
5. Start the match and fight.

Versus uses a save-free sandbox. It should not load, advance, or write any of your normal Hades II save. It runs totally separately.

## Controls

All controls are set to the defaults. Eventually I will probably wire in proper control changing. Haven't actually tested in the ingame control changing yet, who knows maybe it works outta the box.

Only one player can use keyboard and mouse. Two keyboards are not supported, and both players cannot claim the same gamepad. You can do some tomfoolery to get past this. I encourage it, but I cannot save you. Parsec or steam can get some questionable online play probably. 

Primarily tested with Keyboard and controller. Have not tested with two controllers. I do not own two controllers.

To claim a player slot, using your device of choice click the player you'd like to be. So if you want handsome switch controller guy to be player one just use the sticks to take control of the menu and tap "A" on P1 and it should show your controller. Cute keyboard and mouse girl can just click p2 with the mouse.

## Match rules

- Local 1v1, shared screen.
- First to 3 round wins takes the match.
- Each round has a timer.
- If time runs out, Sudden Death starts and both players are dropped to low HP.
- Players use a standardized kit: base weapons, no boons, no run build.

## Feedback

Please report bugs and balance feedback on GitHub or hit me up on the Hades 2 modding discord server:

- [AGON issues](https://github.com/Jakey-Jakey/hades2-agon/issues)

I'm not making a feedback form. Please be reasonable and try to give good context for your issues. 

## What's next?

- Finish the thunderstore CI, 
- Make an icon, 
- Release onto thunderstore (becomes the beta), 
- Finish the local PVP multiplayer arena mode into a somewhat polished state

## Thanks

Big shoutout to TheNormalnijMods, their co-op mod was my main reference for the menus and controller-claim stuff (and AGON runs on their Hades2ModExtension).

Really impressive stuff and you should play that mod!

## I'm a developer and wanna do a little something something

Sure, go for it.

**Building:** clone the repo and double-click **`build.bat`** (needs Visual Studio with the "Desktop development with C++" workload + CMake). It fetches the submodules it needs, builds `AgonGame.dll`, and assembles the mod folder under `bin/`. To have it drop the build straight into your r2modman install, paste your plugins path into `env.cmake` when prompted — optional; building works without it. (No `--recursive` needed — `build.bat` handles submodules.)

A lot of the internals are going to move around. If you want to contribute, the most useful things right now are:

- Bug reports.
- Balance feedback from real matches.
- Art / icon / UI help
- Fixes for weapon weirdness, match-end flow, setup jank, and other obvious alpha problems.
- Figuring out things that are not on my roadmap just yet.
   - Per player Boons
   - Per player Keepsakes
   - Per player Hexes and Selene stuff
   - Item pickups/spawning
   - Making enemies work at all and figuring out targetting
   - Generally more configuration.
   - Generally more arenas.
   - Alternative Versus gamemodes that would be unlocked by these features like PvPvE or gun game or selecting boons each round or whatever.
- Compatibility notes, mayyybe compatibility patches if it's on something that's stable and not gonna shift like crazy. 

If you are making another mod and want to support AGON, I would recommend waiting until local versus is more settled and know that I can't do much besides answer questions. I reserve the right to break everything repeatedly in the name of basic functionality.

For code work, open an issue, talk to me in the discord or just shoot your shot straight into a PR. Tiny obvious fixes are fine, big fixes are okay but the bar for quality is gonna have to be incredibly solid. I would say if it touches multiplayer routing, player control, camera, spawning, save behavior, or weapon logic, please talk to me first. 
