# Enemy Character Setup Example

This document shows how to set up an enemy character using the AIComponent.

## Scene Structure

Create an enemy scene with the following node hierarchy:

```
EnemyCharacter (CharacterBody2D)
├── Sprite2D
│   └── (Set texture to enemy sprite)
├── AnimationPlayer
│   └── (Add animations: Idle, Walk, Attack)
├── AnimationTree
│   └── (Set up blend tree with Idle/Walk/Attack states)
├── StatsComponent (Node2D)
│   └── (Configure enemy stats)
├── HealthComponent (Node2D)
│   └── HealthBarComponent (optional)
├── HitboxComponent (Area2D)
│   ├── CollisionShape2D
│   └── (Set team ID, e.g., team = 2 for enemies)
├── MovementComponent (Node2D)
│   └── (AI will control this)
├── AttackComponent (Node2D)
│   └── AttackTimer (Timer)
├── AnimationComponent (Node2D)
│   └── (Links to AnimationPlayer/AnimationTree)
└── AIComponent (Node2D)
    ├── DetectionArea (Area2D)
    │   └── CollisionShape2D (CircleShape2D)
    ├── StateTimer (Timer)
    └── NavigationAgent2D (Optional, for pathfinding)
```

## Component Configuration

### StatsComponent
- Set `base_max_health` (e.g., 50.0)
- Set `base_move_speed` (e.g., 80.0)
- Configure `entity_class` and `entity_weapon` if needed

### HealthComponent
- Assign `stats` reference to StatsComponent
- Optionally add HealthBarComponent child

### HitboxComponent
- Set `team` to a unique team ID (e.g., 2 for enemies)
- Assign `stats` and `health` references
- Set up CollisionShape2D for hit detection

### MovementComponent
- Assign `stats_component` reference
- Set `is_controllable` to false (AIComponent will handle this)
- Configure movement speeds

### AttackComponent
- Assign all component references (stats, movement, animation, health, hitbox)
- Assign `entity` reference to parent CharacterBody2D
- Configure attack settings

### AnimationComponent
- Set paths to AnimationPlayer, AnimationTree, and Sprite2D
- Assign component references if needed

### AIComponent
- **Child Components**: DetectionArea, StateTimer, and NavigationAgent2D are **auto-created** if they don't exist
- You can manually add them if you want to customize settings
- See `AI_COMPONENT_SETUP.md` for detailed setup instructions
- Assign all component references (movement, attack, health, hitbox, animation, navigation_agent)
- Configure detection settings:
  - `detection_range`: 200.0 (how far enemy can detect targets)
  - `attack_range`: 50.0 (how close to get before attacking)
  - `chase_range`: 400.0 (max distance to chase)
- Configure behavior:
  - `attack_cooldown`: 1.5 (seconds between attacks)
  - `retreat_hp_threshold`: 0.3 (retreat at 30% HP)
  - `use_pathfinding`: true (use NavigationAgent2D if available)
  - `pathfinding_update_interval`: 0.1 (how often to update path)
- Set target groups:
  - `target_groups`: ["players"] (targets nodes in "players" group)

## GDScript Setup

Create a script for the enemy character:

```gdscript
extends CharacterBody2D

@onready var stats_component: StatsComponent = $StatsComponent
@onready var health_component: HealthComponent = $HealthComponent
@onready var hitbox_component: HitboxComponent = $HitboxComponent
@onready var movement_component: MovementComponent = $MovementComponent
@onready var attack_component: AttackComponent = $AttackComponent
@onready var animation_component: AnimationComponent = $AnimationComponent
@onready var ai_component: AIComponent = $AIComponent

func _ready() -> void:
    # Add to enemy group for easy querying
    add_to_group("enemies")
    
    # Components will auto-find each other, but you can manually assign:
    # ai_component.movement_component = movement_component
    # ai_component.attack_component = attack_component
    # etc.
    
    # Set enemy team ID
    if hitbox_component:
        hitbox_component.team = 2  # Enemy team
```

## Scene Setup

### Navigation Setup (for pathfinding)

If using pathfinding, add NavigationRegion2D to your scene:

```
MainScene (Node2D)
├── NavigationRegion2D
│   └── (Add NavigationMeshInstance2D with navigation mesh)
├── PlayerCharacter
└── EnemyCharacter
```

1. Add NavigationRegion2D node to scene
2. Add NavigationMeshInstance2D as child
3. Bake navigation mesh in editor (Navigation > Bake NavigationMesh)
4. NavigationAgent2D will automatically use this for pathfinding

### Player Setup

Make sure players are in the "players" group:

```gdscript
# In player_character.gd _ready():
add_to_group("players")
```

## Testing

1. Place enemy in scene
2. Place player in scene
3. Run game
4. Enemy should detect player and chase/attack

## Customization

### Different AI Behaviors

You can create different enemy types by adjusting AIComponent settings:

**Aggressive Enemy:**
- `detection_range`: 300.0
- `attack_range`: 40.0
- `attack_cooldown`: 1.0
- `retreat_hp_threshold`: 0.1

**Defensive Enemy:**
- `detection_range`: 150.0
- `attack_range`: 60.0
- `attack_cooldown`: 2.0
- `retreat_hp_threshold`: 0.5

**Ranged Enemy:**
- `attack_range`: 150.0 (attack from further away)
- `chase_range`: 200.0 (stay at range)

### Wandering Behavior

Enable idle wandering:
- `idle_wander`: true
- `wander_radius`: 50.0

## Troubleshooting

**Enemy doesn't detect player:**
- Check that player is in "players" group
- Check DetectionArea CollisionShape2D size
- Check `detection_range` value

**Enemy doesn't attack:**
- Check `attack_range` value
- Check AttackComponent is properly configured
- Check `attack_cooldown` timer

**Enemy doesn't move:**
- Check MovementComponent is assigned
- Check `is_controllable` is false (AIComponent handles this)
- Check entity reference in AIComponent

**Pathfinding not working:**
- Ensure NavigationRegion2D exists in scene
- Ensure NavigationMeshInstance2D has baked navigation mesh
- Check NavigationAgent2D is assigned to AIComponent
- Check `use_pathfinding` is true in AIComponent
- Verify NavigationAgent2D is child of enemy character
