# Complex Behavior Tree Validation Arena

Run `res://scenes/test_game.tscn`. The arena compares one basic enemy tree with two complete validation trees.

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
- `EnemyB` and `EnemyC`: `complex_guard_validation_tree.tres` with six priority branches.

## Target Detection

- Enemies acquire a visible player within 330 pixels.
- After acquisition, the target remains locked until it moves beyond 460 pixels. This hysteresis prevents rapid chase/patrol switching at the boundary.
- Cloaking immediately breaks the target lock while preserving the last known position.
- Combat Selectors are reactive, so attack or chase can immediately preempt a running patrol/search branch when its conditions become valid.

## Complex Tree Branches

1. Emergency Recovery: critical health plus detected player triggers retreat, then delayed healing.
2. Attack Left: actor Condition, Action, Cooldown, and Time Limit.
3. Attack Right: actor Condition, Action, Cooldown, and Time Limit.
4. Chase: detected player outside attack range triggers a timed chase Action.
5. Search: cloaked/lost player triggers movement toward `last_known_player_x`.
6. Patrol: structural Invert Decorator confirms the player is not detected, then a Random Selector chooses a direction. A Parallel node runs movement together with a short built-in Wait task.

The Root is wrapped by the first-class Repeat node. The tree also uses the new Random Selector, Parallel, and Wait nodes plus attached Blackboard, Cooldown, and Time Limit Decorators.

## Suggested Demonstration

1. Open `complex_guard_validation_tree.tres` in the Behavior Tree panel and enable `Live Debug`.
2. Run the game and stand far away to observe Patrol.
3. Enter detection range to observe Chase.
4. Move close to either side to observe directional Attack and Cooldown failures.
5. Press `C` after detection to observe Search Last Known.
6. Damage a complex enemy until one health remains to observe Retreat and Heal.
7. Stand in the red damage zone or collect the green medkit to test environment-driven state changes.

The game HUD only shows gameplay information. Runtime paths, blackboard-driven failures, node highlights, connection activity, and failure annotations remain exclusively in the Godot Behavior Tree editor through `Live Debug`.
