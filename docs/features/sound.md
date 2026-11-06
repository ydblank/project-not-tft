# Sound

Sound effects and volume.

**Code:** `assets/commons/sfx.gd` (the `Sfx` autoload), sound files in `assets/audio/sfx/`, tests in `tests/test_sfx.gd`.

`Sfx.play(&"hit")` plays a sound by name; the name-to-file table is `SOUNDS` in `sfx.gd`. To change a sound, replace the file. `Sfx` creates two audio buses: **SFX** (everything played through `Sfx.play()`) and **Music** (the level's music player uses it).

## What plays

Sword swing, heavy swing, bow release, dash, hit (heavier and lower for heavy hits), block, guard break, death, countdown ticks, "FIGHT!", and pause-menu open / close. New combat sounds (parry, clash, armor, finisher) reuse existing recordings at different pitches.

## Volume

A "Sound effects volume" and a "Music volume" slider in the pause menu (Audio group).

## Mix decisions

- Swing sounds play at about 82% (quick) and 88% (heavy) of their recorded pitch. Quick swings are 8 dB quieter, heavy swings 9 dB quieter, bow shots 10 dB quieter and arrow impacts 5 dB quieter than melee hits.
- The fighter who lands a hit sometimes grunts (about 30% of quick hits, 80% of heavy ones, deeper for heavy, at most once every 0.7s per fighter), using the same grunt recording as the dash. The dash is just the grunt (no whoosh), with pitch and speed varying by up to 5%.
- **Variety:** most sounds have several recordings picked at random, never the same twice in a row: 2 heavy swings, 2 bow shots and 3 hits. Each play also varies pitch (and with it speed) by up to 4% and loudness by up to 1 dB. Countdown, "FIGHT!" and menu sounds are kept exact.
- Sounds from human-controlled fighters play at full volume. Bots-only action plays 7 dB quieter so a crowd of AI does not drown out your own actions.

## Sound sources

- The raw sound packs live in `sfx/` at the repo root, which is **git-ignored** (licensed for use, not redistribution) and hidden from the Godot editor with `.gdignore`.
- Only the 17 short files the game uses (about 1.8 MB) are in `assets/audio/sfx/`. Some were cut from the Sonniss packs (hits, block, heavy swings, bow shots); the countdown drum-and-wood hit is synthesized; the rest are copies of short loose files.

## Not used yet

Footsteps, music tracks, NPC voices, and the other loose sounds (rage, buff, smoke, monster roar).

## Known limitations

The sounds were chosen by name and measurement, not by ear. Several volumes and pitches were tuned from feedback and may need more tuning.
