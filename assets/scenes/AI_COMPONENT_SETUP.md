# AIComponent Child Components Setup Guide

## Overview

AIComponent automatically creates its child components if they don't exist. However, you can also manually add them in the editor for customization.

## Auto-Creation (Default Behavior)

The AIComponent will **automatically create** these child nodes if they don't exist:

1. **DetectionArea** (Area2D) - Created automatically
2. **StateTimer** (Timer) - Created automatically  
3. **NavigationAgent2D** - Created automatically (if `use_pathfinding` is true)

### How Auto-Creation Works

When `_ready()` is called, the component checks for each child:
- If the child doesn't exist → Creates it automatically
- If the child exists → Uses the existing one

This means you can **optionally** add them manually, or let the code create them.

## Manual Setup (Optional)

If you want to manually set up the child components in the editor:

### Step 1: Add AIComponent to Enemy Character

1. Select your enemy CharacterBody2D
2. Add child node → Node2D
3. Attach script: `assets/scenes/ai_component.gd`
4. Name it: `AIComponent`

### Step 2: Add DetectionArea (Optional)

**Option A: Let it auto-create** (Recommended)
- Do nothing - it will be created automatically

**Option B: Manual setup**
1. Right-click AIComponent → Add Child Node → Area2D
2. Name it: `DetectionArea`
3. Add child to DetectionArea → CollisionShape2D
4. In CollisionShape2D inspector:
   - Shape → New CircleShape2D
   - Set radius to match `detection_range` (default: 200.0)

### Step 3: Add StateTimer (Optional)

**Option A: Let it auto-create** (Recommended)
- Do nothing - it will be created automatically

**Option B: Manual setup**
1. Right-click AIComponent → Add Child Node → Timer
2. Name it: `StateTimer`
3. In Timer inspector:
   - One Shot: ✓ (checked)
   - Wait Time: Doesn't matter (managed by code)

### Step 4: Add NavigationAgent2D (Optional - Only if using pathfinding)

**Option A: Let it auto-create** (Recommended)
- Set `use_pathfinding` to `true` in AIComponent inspector
- It will be created automatically

**Option B: Manual setup**
1. Right-click AIComponent → Add Child Node → NavigationAgent2D
2. Name it: `NavigationAgent2D`
3. In NavigationAgent2D inspector:
   - Path Desired Distance: 4.0
   - Target Desired Distance: ~40.0 (should be less than `attack_range`)
   - Max Speed: Match your `movement_component.move_speed`

## Complete Scene Structure

```
EnemyCharacter (CharacterBody2D)
├── Sprite2D
├── AnimationPlayer
├── AnimationTree
├── StatsComponent
├── HealthComponent
├── HitboxComponent
├── MovementComponent
├── AttackComponent
├── AnimationComponent
└── AIComponent (Node2D)
    ├── DetectionArea (Area2D) ← Auto-created or manual
    │   └── CollisionShape2D ← Auto-created or manual
    ├── StateTimer (Timer) ← Auto-created or manual
    └── NavigationAgent2D ← Auto-created or manual (if use_pathfinding = true)
```

## Configuration

### DetectionArea Configuration

If manually created, configure:
- **CollisionShape2D → Shape → CircleShape2D**
  - Radius: Should match `detection_range` in AIComponent (default: 200.0)
- **Area2D → Monitoring**: Enabled (default)
- **Area2D → Monitorable**: Can be disabled (not needed for detection)

### StateTimer Configuration

If manually created:
- **One Shot**: ✓ Enabled
- **Wait Time**: Doesn't matter (managed dynamically by code)
- **Autostart**: ✗ Disabled

### NavigationAgent2D Configuration

If manually created:
- **Path Desired Distance**: 4.0 (distance to next waypoint)
- **Target Desired Distance**: ~40.0 (should be less than `attack_range`)
- **Max Speed**: Match `movement_component.move_speed`
- **Avoidance Enabled**: Optional (for obstacle avoidance)
- **Radius**: Optional (for collision avoidance)

## Quick Setup (Recommended)

**Easiest approach:**

1. Add AIComponent to enemy character
2. Assign component references (movement_component, attack_component, etc.)
3. Configure AIComponent settings (detection_range, attack_range, etc.)
4. **That's it!** All child components will be auto-created

The only time you need to manually add children is if you want to:
- Customize DetectionArea collision layers/masks
- Adjust NavigationAgent2D advanced settings
- Pre-configure specific values before runtime

## Troubleshooting

**DetectionArea not detecting targets:**
- Check that CollisionShape2D radius matches `detection_range`
- Verify Area2D Monitoring is enabled
- Check collision layers/masks if manually created

**NavigationAgent2D not working:**
- Ensure NavigationRegion2D exists in scene
- Ensure NavigationMeshInstance2D has baked navigation mesh
- Check that `use_pathfinding` is true in AIComponent
- Verify NavigationAgent2D is child of AIComponent (or auto-created)

**StateTimer not working:**
- Should be auto-created, but if manual: ensure One Shot is enabled
- Timer is managed by code, don't manually start it
