# Playable Multi-Scale Behavior Tree Arena

Run `res://scenes/test_game.tscn`. This is a finite, completable game scene used to show that the behavior-tree editor and runtime work with real NPCs. It is functional evidence for the plugin, not a separate dissertation research question.

## Goal and Controls

Defeat all five enemies. The player has infinite health, defeated enemies do not respawn, and the victory panel appears after the fifth enemy is defeated.

- `A` / `D` or Left / Right: move.
- `W` / Up: jump on the ground or climb upward near the ladder.
- `S` / Down: climb downward near the ladder.
- `J` or left mouse: melee attack.
- `Space`: dash with temporary invulnerability and a stamina cost.
- `H`: use a healing charge when health is not full. In this infinite-health arena the player normally remains full, so the key usually has no visible effect.
- `C`: cloak for two seconds. Enemies lose sight of the player, remember the last known position, and can switch to Search.
- `T`: pause or resume all five `BehaviorTreeComponent` runners.
- `R`: reset the player, all enemies, blackboards, behavior-tree execution state, enemy count, and victory state.

The HUD contains gameplay information only. Behavior-tree paths, blackboard values, node highlights, and failure reasons remain in the Godot editor's `Behavior Tree` panel through `Live Debug`; they are not drawn over the running game.

## Five Fixed Enemies

| Enemy | Tree resource | Resource nodes | Role in the demonstration |
| --- | --- | ---: | --- |
| Scout | `arena_scout_31.tres` | 31 | Small-tree reference and basic patrol/combat decisions |
| Skirmisher | `arena_skirmisher_61.tres` | 61 | Adds more tactical alternatives above the supervisor's approximate 50-node threshold |
| Hunter | `arena_hunter_121.tres` | 121 | Medium-large pursuit and traversal case |
| Tactician | `arena_tactician_241.tres` | 241 | Main complex NPC used to demonstrate ranged combat, traversal, search, recovery, and Live Debug |
| Commander | `arena_commander_364.tres` | 364 | Largest playable stress case |

Each enemy uses a different saved `.tres` resource. Every tree is structurally validated, every Action and method-based Condition resolves on the enemy actor, and the runners preserve the saved resources while the game is running.

## Meaningful 241-Node Tactician

The Tactician's 241-node resource is not a disconnected display fixture. Its reachable branches control actual game behavior, including:

1. emergency retreat and healing;
2. reaction to the player's attack window;
3. left- and right-facing melee decisions;
4. obstacle detection and jumping over crates;
5. approaching and climbing the ladder when the player is above;
6. aimed ranged attacks with visible projectiles and cooldown;
7. mid-range pressure and pursuit;
8. chase and last-known-position search after cloak or lost sight;
9. return to its guard area;
10. patrol and idle behavior.

The five resources also exercise Root, Sequence, Selector, Random Selector, Parallel, Repeat, Action, Condition, Wait, and attached Decorator nodes, together with blackboard values and runtime execution memory.

## Repeatable Demonstration

### A. Complete the game

1. Run `test_game.tscn` and confirm the HUD says `PLAYER HP INFINITE` and `ENEMIES 5/5`.
2. Attack the enemies with `J` or the left mouse button. A defeated enemy disappears and does not return.
3. Defeat the fifth enemy and confirm that the victory panel appears once.
4. Press `R` and confirm that all five enemies, their behavior trees, the HUD counter, and the hidden victory panel return to their initial state.

### B. Observe the Tactician's behavior

1. Stay far from the Tactician to observe patrol or guard behavior.
2. Enter its detection range to trigger pursuit; remain in an open lane to allow a ranged projectile attack.
3. Move behind a crate or onto the raised platform to exercise jumping and ladder pursuit.
4. Press `C` after being detected to trigger last-known-position search.
5. Attack at close range to exercise defensive reaction and directional melee branches.
6. Reduce the Tactician to low health without defeating it to observe retreat and recovery choices.

### C. Observe the Actual Game Tree in Live Debug

1. Before or while the game runs, open the Godot bottom panel named `Behavior Tree`.
2. Select `res://behavior_trees/arena_tactician_241.tres`.
3. Open `Debug` and enable `Live Debug`, `Active Path Highlight`, and optionally `Non-active Branch Dimming` and `Live Blackboard`.
4. Repeat the actions in section B. The highlighted path and leaf should change as the real `EnemyTactician` runner changes state.
5. Press `T` to pause all AI runners when a path needs closer inspection; press `T` again to resume.

## Automated Evidence

From the repository root, the relevant checks are:

```powershell
./Godot_v4.6-stable_win64_console.exe --headless --audio-driver Dummy --path ./testgame/testgame --script res://tests/run_game_integration_tests.gd
./Godot_v4.6-stable_win64_console.exe --headless --audio-driver Dummy --path ./testgame/testgame --script res://tests/run_arena_progression_tests.gd
./Godot_v4.6-stable_win64_console.exe --headless --audio-driver Dummy --path ./testgame/testgame --script res://tests/run_complex_arena_tests.gd
./Godot_v4.6-stable_win64_console.exe --rendering-method gl_compatibility --audio-driver Dummy --path ./testgame/testgame --script res://tests/run_arena_smoke_test.gd
./Godot_v4.6-stable_win64_console.exe --rendering-method gl_compatibility --audio-driver Dummy --path ./testgame/testgame --script res://tests/run_playable_game_evidence_visual_tests.gd
```

These tests check finite enemy progression, infinite player health, exact tree binding and node counts, permanent defeat, victory and reset, complex Tactician actions, active runtime paths, the absence of a behavior-tree overlay in the game, real rendering, and evidence screenshots.
