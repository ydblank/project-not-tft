# AI/Enemy Component Architecture Plan

## Overview
The AI Component (`AIComponent`) will control enemy behavior by integrating with existing components (MovementComponent, AttackComponent, etc.). It follows the same component-based architecture pattern used throughout the project.

## Component Structure

### Required Nodes/Components
An enemy character should have the following structure:

```
EnemyCharacter (CharacterBody2D)
├── Sprite2D
├── AnimationPlayer
├── AnimationTree
├── StatsComponent
├── HealthComponent
├── HitboxComponent (Area2D)
│   └── CollisionShape2D
├── MovementComponent
├── AttackComponent
│   └── AttackTimer (Timer)
├── AnimationComponent
├── NavigationAgent2D (Optional, for pathfinding)
└── AIComponent (NEW)
    ├── DetectionArea (Area2D) - Optional, for detection range
    │   └── CollisionShape2D
    └── StateTimer (Timer) - For state transitions
```

## AIComponent Features

### 1. State Machine
The AI will use a state machine with the following states:

- **IDLE**: Enemy is stationary, scanning for targets
- **CHASE**: Enemy is moving toward a target
- **ATTACK**: Enemy is performing an attack
- **RETREAT**: Enemy is backing away (low health or cooldown)
- **STUNNED**: Enemy is temporarily disabled (from stagger/knockback)
- **DEAD**: Enemy is dead (cleanup state)

### 2. Target Detection
- **Detection Range**: Configurable radius for detecting targets
- **Target Selection**: Find nearest valid target (not same team, not dead)
- **Target Validation**: Check if target is still valid (alive, in range, etc.)
- **Target Groups**: Can target specific groups (e.g., "players", "allies")

### 3. Decision Making
- **Attack Range**: Distance at which enemy will attack
- **Retreat Threshold**: HP percentage that triggers retreat
- **Attack Cooldown**: Time between attacks
- **Chase Distance**: Maximum distance to chase before giving up
- **Decision Intervals**: How often to re-evaluate decisions

### 4. Integration Points
- **MovementComponent**: Controls movement direction and speed
- **AttackComponent**: Triggers attacks when in range
- **HealthComponent**: Monitors health for retreat logic
- **HitboxComponent**: Uses team ID for target filtering
- **NavigationAgent2D**: Optional pathfinding support (requires NavigationRegion2D in scene)

## Configuration Options

### Detection Settings
- `detection_range`: float = 200.0
- `detection_angle`: float = 360.0 (for cone detection)
- `target_groups`: Array[String] = ["players"]
- `target_team`: int = -1 (targets all teams except own)

### Behavior Settings
- `attack_range`: float = 50.0
- `chase_range`: float = 400.0
- `retreat_hp_threshold`: float = 0.3 (30% HP)
- `attack_cooldown`: float = 1.5
- `decision_interval`: float = 0.2
- `idle_wander`: bool = false
- `wander_radius`: float = 50.0
- `use_pathfinding`: bool = true
- `pathfinding_update_interval`: float = 0.1

### State Durations
- `idle_duration`: float = 2.0
- `retreat_duration`: float = 1.0
- `stun_duration`: float = 0.5

## Implementation Details

### State Transitions
```
IDLE -> CHASE: Target detected within detection_range
CHASE -> ATTACK: Target within attack_range
CHASE -> IDLE: Target lost or out of chase_range
ATTACK -> CHASE: Attack finished, target still in range
ATTACK -> IDLE: Attack finished, target out of range
CHASE -> RETREAT: HP below retreat_threshold
RETREAT -> IDLE: Retreat duration expired
Any -> STUNNED: Hit by attack (stagger/knockback)
Any -> DEAD: Health reaches 0
```

### Movement Control
- AIComponent sets `movement_component.is_controllable = false` (AI controls movement)
- AIComponent calculates direction to target and sets velocity via MovementComponent
- AIComponent can trigger dashes/lunges via MovementComponent methods

### Attack Control
- AIComponent checks if target is in attack range
- AIComponent calls `attack_component.handle_attack_input()` with appropriate AttackType
- AIComponent respects attack cooldowns and state

### Target Detection Methods
1. **Area2D Detection**: Use DetectionArea to detect targets via signals
2. **Distance Check**: Manual distance checks to targets in scene
3. **Group Query**: Query nodes in target groups

## Example Usage

```gdscript
# In enemy scene setup
@onready var ai_component: AIComponent = $AIComponent
@onready var movement_component: MovementComponent = $MovementComponent
@onready var attack_component: AttackComponent = $AttackComponent

func _ready():
    # AIComponent will automatically find and connect to components
    # Or manually assign:
    ai_component.movement_component = movement_component
    ai_component.attack_component = attack_component
    ai_component.hitbox_component = $HitboxComponent
```

## Pathfinding Support

The AIComponent supports NavigationAgent2D for pathfinding:
- **Optional**: If NavigationAgent2D is assigned and `use_pathfinding` is true, enemies will use pathfinding
- **Fallback**: If NavigationAgent2D is not assigned, enemies use direct movement toward targets
- **Setup**: Requires NavigationRegion2D in scene with baked navigation mesh

## Future Enhancements
- Behavior trees for complex AI
- Different AI personalities (aggressive, defensive, ranged)
- Formation/group behavior
- Patrol routes
- Alert states (investigate sounds/events)
- Dynamic obstacle avoidance