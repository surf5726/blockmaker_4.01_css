# blockmaker_4.01_css
Blockmaker 4.01 ported for Counter-Strike: Source

## Features:
- Say !bm in chat to bring up the main menu.
- Bind a key to +bmgrab to move the blocks around.
- While grabbing a block, move backward to move a block closer, and move forward to move a block further away.
- Create a block by aiming at the floor or a wall.
- Convert block you are aiming at to the selected block type.
- Delete block you are aiming at.
- Rotate the block you are aiming at.
- Optional noclip and godmode to make creating blocks easier.
- Snapping option so when creating and moving blocks, they snap into place next to, above or below other nearby blocks.
- Snapping gap option to leave a gap between blocks when they snap together.
- Save all blocks to file using mapname, will load on map load. Save folder: \data\blockmaker\
- In game plugin help including server CVAR values.
- Look at a block to see what type of block it is.

## CVARs:
- bm_telefrags 1 (Players near teleport exit die if someone comes through)
- bm_firedamageamount 20.0 (How much the fire damage block hurts per half second)
- bm_damageamount 5.0 (How much the damage block hurts per half second)
- bm_healamount 1.0 (How much life the healer block gives per half second)
- bm_invincibletime 20.0 (How long invincibility lasts in seconds)
- bm_invinciblecooldown 60.0 (Seconds before invincibility can be used again)
- bm_stealthtime 20.0 (How long stealth lasts in seconds)
- bm_stealthcooldown 60.0 (Seconds before stealth can be used again)
- bm_camouflagetime 20.0 (How long camouflage lasts in seconds)
- bm_camouflagecooldown 60.0 (Seconds before camouflage can be used again)
- bm_nukecooldown 60.0 (Seconds before the nuke can be used again)
- bm_randomcooldown 30.0 (Seconds before the random block can be used again)
- bm_bootsofspeedtime 20.0 (How long the boots of speed last for in seconds)
- bm_bootsofspeedcooldown 60.0 (Seconds until boots can be used again)
- bm_autobhoptime 20.0 (How long the player has auto bhop)
- bm_autobhopcooldown 60.0 (Time before auto bhop can be used again)
- bm_teleportsound 1 (Teleporters make a sound when something passes through them)

## Block types:
- Platform (A platform you can stand on)
- Bunnyhop (A platform that disappears for a short period of time after touching it)
- Damage (Hurts you if you stand on top of it)
- Healer (Heals you if you stand on top of it)
- No Fall Damage (You don't take any damage if you fall onto it)
- Ice (You slide around like you're on ice)
- Trampoline (Throws you up in the air)
- Speed Boost (Throws you forwards in the direction you're looking)
- Invincibility (Player becomes invincible for a set amount of time)
- Stealth (Player becomes invisible for a set amount of time)
- Death (Player dies instantly)
- Nuke (Destroys all players on the other team unless a player has invincibility)
- Camouflage (Player looks like the other team for a set amount of time)
- Low Gravity (Jumping from this block you get low gravity until you land) (Thanks C$L for idea)
- Fire (Another damage block but nicer looking) =)
- Slap (You get slapped!) (Pat made this one)
- Random (Random between Invincibility, Stealth, Camouflage, Boots Of Speed, a slap, or death!)
- Honey (Player moves slowly like they're stuck in honey) (Thanks C$L for idea)
- CT Barrier (Only Terrorists can pass through these blocks, acts as solid for Counter-Terrorists)
- T Barrier (Only Counter-Terrorists can pass through these blocks, acts as solid for Terrorists)
- Boots Of Speed (Player runs fast for a set amount of time)
- Glass (Same as platform but looks like a transparent pane of glass)
- Bunnyhop - No slow down (Same as bunnyhop block but you don't slow down after landing)
- Auto bunnyhop (Player can hold jump to auto bunnyhop for 'bm_autobhoptime' amount of time)
