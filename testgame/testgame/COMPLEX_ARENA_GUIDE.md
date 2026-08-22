# Complex Behavior Tree Validation Arena

Run `res://scenes/test_game.tscn`. The arena compares one basic enemy tree with two playable 241-node tactical trees.

## Controls

- `A` / `D` or arrow keys: move.
- `W` / Up: jump on the ground or climb upward near a ladder.
- `S` / Down: climb downward near a ladder.
- `J` or left mouse: melee attack.
- `Space`: dash with invulnerability frames and stamina cost.
- `H`: consume a healing charge.
- `C`: cloak for two seconds. Enemies remember the last known position and switch to Search.
- `T`: pause or resume every BehaviorTreeComponent.
- `R`: reset player, enemies, blackboards, and behavior trees.

## Enemy Groups

- `EnemyA`: basic comparison tree with left/right attacks, chase, and patrol.
- `EnemyB` and `EnemyC`: `complex_display_tree_241.tres`, the same 241-node resource used for large-tree display evaluation.

## Target Detection

- Enemies acquire a visible player within 330 pixels.
- After acquisition, the target remains locked until it moves beyond 460 pixels. This hysteresis prevents rapid chase/patrol switching at the boundary.
- Cloaking immediately breaks the target lock while preserving the last known position.
- Combat Selectors are reactive, so attack or chase can immediately preempt a running patrol/search branch when its conditions become valid.

## 241-Node Playable Tree

The node count comes from complete tactical alternatives rather than disconnected or duplicated filler. The reactive priority order is:

1. Emergency recovery with three retreat/heal routes.
2. Reactive defense that reads the player's current attack window and dodges or braces.
3. Directional melee combat with six light/heavy combo patterns.
4. Obstacle traversal that detects crates with a physics ray and jumps over them.
5. Vertical pursuit that approaches and climbs a ladder when the player is above.
6. Ranged suppression with aiming telegraphs, visible projectiles, and cooldown.
7. Mid-range pressure with lateral movement and different approach commitment.
8. Coordinated chase with four pursuit strategies and parallel ally signalling.
9. Four last-known-position search patterns after cloak or lost detection.
10. Guard-post return behavior that prevents unlimited patrol drift.
11. Five layered patrol routes combining movement, Wait, observation, and time limits.
12. Four always-available guard-idle variations.

The tree uses all ten supported resource types, a 23-key typed blackboard schema, seeded Random Selectors, Parallel preparation, first-class Repeat and Wait nodes, plus Cooldown and Time Limit decorators. Every reachable Action maps to a real actor method. Its saved multi-level coordinates are also the fixed 241-node large-tree display fixture.

## Suggested Demonstration

1. Open `complex_guard_validation_tree.tres` in the Behavior Tree panel and enable `Live Debug`.
2. Run the game and stand far away to observe Patrol.
3. Enter detection range to observe Chase.
4. Move close to either side to observe directional Attack and Cooldown failures.
5. Press `C` after detection to observe Search Last Known.
6. Start an attack near a complex enemy to observe Dodge/Brace preempting a combo.
7. Stand across an open lane to observe the aiming telegraph and projectile attack.
8. Lead an enemy toward a striped crate to observe obstacle detection and jumping.
9. Climb onto the blue platform to trigger ladder-based vertical pursuit.
10. Damage a complex enemy until one health remains to observe Retreat and Heal.
11. Stand in the red damage zone or collect the green medkit to test environment-driven state changes.

The game HUD only shows gameplay information. Runtime paths, blackboard-driven failures, node highlights, connection activity, and failure annotations remain exclusively in the Godot Behavior Tree editor through `Live Debug`.
