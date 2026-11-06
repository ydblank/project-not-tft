# Docs

Documentation is organised **by feature**, not by release. To learn how something works, open its feature doc. To see what changed in a release, open the changelog.

## Feature docs

| Doc | Covers |
|---|---|
| [Controls](features/controls.md) | Keyboard / mouse bindings, local 2-player mode |
| [Fight flow](features/fight-flow.md) | Countdown, lives and respawn, arena, 2v2 teams, bot / team toggles |
| [Combat](features/combat.md) | Combos, ranged, block, parry, armor, clashes, stun rules, dash |
| [AI](features/ai.md) | Bot behaviour: dodging, targeting, teamwork, smart behaviours |
| [Game feel](features/game-feel.md) | Freeze frame, camera, hit and block effects |
| [Sound](features/sound.md) | `Sfx` helper, volume, mix decisions, sound sources |
| [UI and dev tools](features/ui-and-dev-tools.md) | Overlays, pause menu, live-tunable dev settings |

## Changelog

- [v2.2](CHANGELOG.md): combat, AI and game-feel overhaul

## Keeping docs current

When you change a feature, edit its feature doc in the same commit. Put new release notes in `CHANGELOG.md` and link to the feature doc instead of repeating the details.
