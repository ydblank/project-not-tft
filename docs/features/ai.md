# AI

How bot fighters (enemies and the ally) decide what to do.

**Code:** `assets/scenes/ai_component.gd`. Like `PlayerController` it only writes a `CombatIntent` each physics frame; `CombatComponent` decides what happens. Setup guides for new enemies: `assets/scenes/AI_COMPONENT_SETUP.md`, `ENEMY_SETUP_EXAMPLE.md`, `AI_COMPONENT_PLAN.md`.

## Basics

- **Dodging:** dashes out of the way of incoming arrows and wind-ups.
- **Stays in the arena:** treats the arena edge as a wall (and the edge of the [shrinking zone](fight-flow.md#shrinking-zone-gam-81)). It won't walk, retreat or dash out, and walks back in if knocked out or caught by the zone. The way back follows the navigation path, so it goes round pillars and walls instead of pushing against them; with no path it turns until the way ahead is clear (`_way_back` in `ai_component.gd`).
- **Attack pacing:** tuned so the AI fights back (attack cooldown 0.7s, personality changes every 1.2s).
- **Ally AI** uses the same brain as the enemy archer and targets enemies.
- **Dash reserve:** movement dashes keep one charge in reserve for dodging and combo breaks.

## Smart behaviours

All can be switched off per fighter in the AIComponent **"Smarts"** export group.

- **Combo breaker:** when held in combo hitstun, the AI reacts after about 0.2s and may dash out (60% to 85% chance depending on personality).
- **Punish dash:** dashes in on a target that is stunned, knocked back or recovering from a swing, and can spend its last charge to do it.
- **Steadier decisions:** commits to chasing or retreating for at least 0.7s, retreats more when hurt, and does not run straight back into a corner it just escaped.
- **Smarter targets:** scores targets by distance, openings, low health, and whether a teammate is already on them. Targets are kept for 1s so it does not flip between two.
- **Teamwork:** two fighters on the same target flank from opposite sides, and they cooperate through how they pick targets:
  - **Range:** with `hunt_far_targets` on (the default) a bot ignores `detection_range` and `chase_range` and picks from every living enemy, so it never idles while an enemy is alive somewhere far off. Turn it off to get the old "only notice enemies within 200px" behaviour.
  - **Protect:** a bot goes after whoever is attacking or targeting a friend: a bot that has targeted it, or a fighter mid-attack aimed at it (full priority), or anyone standing within 90px of it (half). Archers and mages are protected more than melee fighters, and a friend under 50% HP more again.
  - **Focus fire:** a target under 45% HP gets everyone's attention, so a kill chance is finished by the whole team. Healthy targets are spread out instead (a small penalty when a teammate already has them).
  - **Ranged first:** melee bots lean toward enemy archers and mages (small bonus, so distance still matters).
- **Adapts to you:** blocks and dodges more when you spam attacks, and holds back its heavy while you still have a dash to sidestep it (goes for it more when you are out of dashes or stunned).
- **Uses the arena edge:** approaches from the inside so its hits push you toward the edge, and avoids hanging around the edge itself.
- **Needs a clear line:** will not swing, shoot or charge at a target behind a wall or pillar. It takes a short step to the side to get a clear angle, and circles round wide blocks if no angle is in reach. This also applies while it is holding its distance (cautious), so it never just waits behind cover. The target has to be in clear view for 0.1s before it attacks, so a corner does not make it twitch.

Pause-menu tunables: attack cooldown, dodging on/off, dodge cooldown, respawn delay.

## Known limitations

- The AI only stands at the arena edge if you are outside; it does not follow you out.
- The AI does not parry on purpose (it can land one by chance), and blocks are judged by where the attacker stands, not by where an arrow comes from.
- The new behaviours were checked one by one in the running game with staged hits, not in long live fights. They need real play to tune.
