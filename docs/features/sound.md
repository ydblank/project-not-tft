# Sound

Sound effects and volume.

**Code:** `assets/commons/sfx.gd` (the `Sfx` autoload), sound files in `assets/audio/sfx/`, music in `assets/audio/music/` (played by `assets/levels/music_player.gd`), tests in `tests/test_sfx.gd`.

`Sfx.play(&"hit")` plays a sound by name; the name-to-file table is `SOUNDS` in `sfx.gd`. To change a sound, replace the file. `Sfx` creates two audio buses: **SFX** (everything played through `Sfx.play()`) and **Music** (the level's music player uses it).

## What plays

Sword swing, heavy swing, bow release, projectile or melee swing hitting a wall (`wall_hit`, the short dry countdown tick played low for a dull thump, layered with `wall_stone`, a real stone hit trimmed to 0.4 s), dash, hit (heavier and lower for heavy hits), block, guard break, death, countdown ticks, "FIGHT!", and pause-menu open / close. New combat sounds (parry, clash, armor, finisher) reuse existing recordings at different pitches.

## Music

The arena plays the **Battle Theme** on a loop (`assets/audio/music/battle_theme_loop.wav`, played by the `Music` node in `node_2d.tscn`, script `assets/levels/music_player.gd`). It uses the **Music** bus, so the Music volume slider controls it, and it keeps playing while the game is paused. It **starts on "FIGHT!"**, when the 3-2-1 countdown ends, not during the countdown. The node's own volume is -9 dB so it sits under the combat sounds.

- **Speeds up as the zone shrinks:** the tempo follows how far the [shrinking zone](fight-flow.md#shrinking-zone-gam-81) has closed (`ShrinkingZone.get_progress()`), from normal speed at the start to **1.25x** at the minimum size (`max_tempo` on the `Music` node), rising smoothly during each closing. Playing faster also raises the pitch, so a pitch shifter on the Music bus lowers it back and the key stays the same (`keep_pitch`; turn it off to let the pitch rise instead). At normal speed the shifter is bypassed, so the music is untouched. If the zone is switched off, the tempo glides back to normal. The shifter was checked by measuring (speed, signal level), not by ear, so it may sound slightly smeared on the drums; `keep_pitch = false` is the fallback.
- **Why a WAV:** Godot's MP3 loop restarts the decoder at the end and left about 55 ms of silence at every loop. The WAV was cut to a loop from one clean pass of the original MP3 (71.10 s, 48 kHz stereo, about 13 MB), at the sample where the end joins the start with no audible step, so it loops without a gap. It is imported uncompressed with a forward loop.
- **Changing the track:** replace the file with another WAV that is already trimmed to its loop length (no silence at either end) and set the same loop import options, or assign a different `stream` on the `Music` node. MP3 and Ogg also play and loop, but they will not loop as cleanly.
- The original MP3 is not in the project (it was in `msuic/`, which is untracked).

## Volume

A "Sound effects volume" and a "Music volume" slider in the pause menu (Audio group).

## Mix decisions

- Swing sounds play at about 82% (quick) and 88% (heavy) of their recorded pitch. Quick swings are 8 dB quieter, heavy swings 9 dB quieter, bow shots 10 dB quieter and arrow impacts 5 dB quieter than melee hits.
- The fighter who lands a hit sometimes grunts (about 30% of quick hits, 80% of heavy ones, deeper for heavy, at most once every 0.7s per fighter), using the same grunt recording as the dash. The dash is just the grunt (no whoosh), with pitch and speed varying by up to 5%.
- **Variety:** most sounds have several recordings picked at random, never the same twice in a row: 2 heavy swings, 2 bow shots and 3 hits. Each play also varies pitch (and with it speed) by up to 4% and loudness by up to 1 dB. Countdown, "FIGHT!" and menu sounds are kept exact.
- Sounds from human-controlled fighters play at full volume. Bots-only action plays 7 dB quieter so a crowd of AI does not drown out your own actions.

## Sound sources

- The raw sound packs live in `sfx/` at the repo root, which is **git-ignored** (licensed for use, not redistribution) and hidden from the Godot editor with `.gdignore`.
- Only the 18 short files the game uses (about 1.8 MB) are in `assets/audio/sfx/`. Some were cut from the Sonniss packs (hits, block, heavy swings, bow shots); the countdown drum-and-wood hit is synthesized; the rest are copies of short loose files.

## Not used yet

Footsteps, menu music, NPC voices, and the other loose sounds (rage, buff, smoke, monster roar).

## Known limitations

The sounds were chosen by name and measurement, not by ear. Several volumes and pitches were tuned from feedback and may need more tuning.
