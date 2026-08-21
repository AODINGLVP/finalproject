# Complex Behavior Tree Validation Arena

Run `res://scenes/test_game.tscn`. The arena compares one basic enemy tree with two playable 213-node tactical trees.

## Controls

- `A` / `D` or arrow keys: move.
- `J` or left mouse: melee attack.
- `Space`: dash with invulnerability frames and stamina cost.
- `H`: consume a healing charge.
- `C`: cloak for two seconds. Enemies remember the last known position and switch to Search.
- `T`: pause or resume every BehaviorTreeComponent.
- `R`: reset player, enemies, blackboards, and behavior trees.

## Enemy Groups

- `EnemyA`: basic comparison tree with left/right attacks, chase, and patrol.
- `EnemyB` and `EnemyC`: `playable_complex_enemy_213.tres`, a 213-node reactive tactical tree.

## Target Detection

- Enemies acquire a visible player within 330 pixels.
- After acquisition, the target remains locked until it moves beyond 460 pixels. This hysteresis prevents rapid chase/patrol switching at the boundary.
- Cloaking immediately breaks the target lock while preserving the last known position.
- Combat Selectors are reactive, so attack or chase can immediately preempt a running patrol/search branch when its conditions become valid.

## 213-Node Playable Tree

The node count comes from complete tactical alternatives rather than disconnected or duplicated filler. The reactive priority order is:

1. Emergency recovery with three retreat/heal routes.
2. Reactive defense that reads the player's current attack window and dodges or braces.
3. Directional melee combat with six light/heavy combo patterns.
4. Mid-range pressure with lateral movement and different approach commitment.
5. Coordinated chase with four pursuit strategies and parallel ally signalling.
6. Four last-known-position search patterns after cloak or lost detection.
7. Guard-post return behavior that prevents unlimited patrol drift.
8. Five layered patrol routes combining movement, Wait, observation, and time limits.
9. Four always-available guard-idle variations.

The tree uses all ten supported resource types, a 17-key typed blackboard schema, seeded Random Selectors, Parallel preparation, first-class Repeat and Wait nodes, plus Cooldown and Time Limit decorators. Enemy methods are real actor APIs, so every reachable Action can execute during play.

## Suggested Demonstration

1. Open `complex_guard_validation_tree.tres` in the Behavior Tree panel and enable `Live Debug`.
2. Run the game and stand far away to observe Patrol.
3. Enter detection range to observe Chase.
4. Move close to either side to observe directional Attack and Cooldown failures.
5. Press `C` after detection to observe Search Last Known.
6. Start an attack near a complex enemy to observe Dodge/Brace preempting a combo.
7. Damage a complex enemy until one health remains to observe Retreat and Heal.
8. Stand in the red damage zone or collect the green medkit to test environment-driven state changes.

The game HUD only shows gameplay information. Runtime paths, blackboard-driven failures, node highlights, connection activity, and failure annotations remain exclusively in the Godot Behavior Tree editor through `Live Debug`.
