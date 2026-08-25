# Behavior Tree Plugin Usage

## Editor

- Enable the plugin from `Project > Project Settings > Plugins`.
- Open the bottom panel named `Behavior Tree`.
- Right-click an empty point on the graph and choose a node type to create it at the cursor.
- Right-click a node to disconnect, delete, or enable/disable it.
- Use `Undo` and `Redo` in the toolbar while editing.
- Use the attached-decorator list in `Node Inspector` to edit or remove decorators.
- The editor validates roots, connections, cycles, leaf children, decorators, and disconnected nodes before saving.

## Display Tools

- Open the compact `Display` menu to enable or disable every optimization and the graph grid independently. The toolbar keeps only common navigation actions visible.
- Open the compact `Debug` menu to toggle `Live Debug`, inactive-branch dimming, failure annotations, the Live Blackboard panel, and Blackboard Schema authoring. `Failures` remains beside it as a clickable node-location list.
- `Fisheye`: enlarges only the card directly under the pointer, shrinks surrounding cards, and temporarily reflows them without changing saved positions.
- `Compact`: reduces card size and keeps only the essential node identity.
- `Semantic Zoom`: hides secondary information at low zoom while keeping card geometry stable.
- `Zoom-Aware Auto Spacing`: temporarily separates expanded cards, keeps lower levels from moving upward, and reserves clear parent-child connection channels without changing saved node coordinates.
- `Zoom View Anchor`: records the viewport center and nearby node relationships at the start of a wheel-zoom burst, then preserves that center-relative neighborhood while temporary layout changes settle.
- `Arrange for Overview`: right-click the canvas and choose this command to save a compact low-detail layout; zooming in then demonstrates Auto Spacing, while zooming out restores the dense arrangement.
- `Collapse` / `Expand`: summarizes or restores all child subtrees.
- `Focus`: keeps the selected subtree and its ancestor path; `All` restores the full tree.
- `Find Node`: highlights matches in titles, types, descriptions, action names, condition names, and decorators. Enable or disable highlighting through `Display > Search + Highlight`.
- `Minimap`, `Grid`, and `Fit`: support navigation in large trees.
- `Runtime Path` and `Selection` show clickable path buttons for Live Debug and the selected node.
- `Active Path Highlight`, `Non-active Branch Dimming`, and `Failure Reason Annotation` explain runtime decisions in the editor.
- `Multi-column Layout` wraps wide fan-outs while preserving left-to-right execution order.
- `Stable Incremental Layout` keeps valid existing positions when `Auto Arrange` is used.
- `Edge Obstacle Avoidance` is enabled by default and reroutes a connection only when its normal route crosses an unrelated card.
- `Orthogonal Edges` and `Edge Bundling` provide alternative connection routing for dense trees.
- `Always Curved Edges (Experiment)` and `Translucent Cards (Experiment)` are optional, default-off comparison modes. They are not the recommended baseline.

Display options are saved in `user://behavior_tree_editor_view.cfg`. Experimental or potentially expensive options such as Compact, Semantic Zoom, branch dimming, multi-column layout, orthogonal edges, edge bundling, and stable layout are disabled by default. Disabling a feature restores its baseline visual state without changing behavior-tree execution data.

`complex_guard_validation_tree.tres` uses the compact overview arrangement by default. Enable both `Semantic Zoom` and `Zoom-Aware Auto Spacing` to compare its dense overview coordinates with the temporary expanded detail layout.

## Runtime

Add a `BehaviorTreeComponent` node under your NPC and assign a `BTTreeResource`.
If the component is not a child of the NPC, set `actor_path` to the actor that owns the behavior.

Action nodes call a method on the actor using `parameters.action_name`.
Condition nodes either compare a blackboard value or call `parameters.condition_name`.

Agent methods should use this signature:

```gdscript
func patrol(blackboard: Dictionary, delta: float, node: Resource) -> int:
	return BTStatus.RUNNING
```

Return `BTStatus.SUCCESS`, `BTStatus.FAILURE`, `BTStatus.RUNNING`, or return `true`/`false`.

Example scene setup:

```text
NPCCharacterBody2D
  BehaviorTreeComponent
```

In `BehaviorTreeComponent`:

- `behavior_tree`: assign your `.tres` behavior tree.
- `actor_path`: leave empty if the component is a child of the NPC.
- `tick_on_process`: enable for normal frame updates.
- `tick_on_physics`: enable for physics movement.

## Automated Verification

Run these commands from the repository root:

```powershell
./Godot_v4.6-stable_win64_console.exe --headless --path ./testgame/testgame --script res://tests/run_behavior_tree_tests.gd
./Godot_v4.6-stable_win64_console.exe --headless --path ./testgame/testgame --script res://tests/run_editor_view_tests.gd
./Godot_v4.6-stable_win64_console.exe --headless --path ./testgame/testgame --script res://tests/run_game_integration_tests.gd
./Godot_v4.6-stable_win64_console.exe --headless --path ./testgame/testgame --script res://tests/run_complex_arena_tests.gd
./Godot_v4.6-stable_win64_console.exe --headless --path ./testgame/testgame --script res://tests/run_arena_progression_tests.gd
./Godot_v4.6-stable_win64_console.exe --rendering-method gl_compatibility --path ./testgame/testgame --script res://tests/run_arena_smoke_test.gd
./Godot_v4.6-stable_win64_console.exe --rendering-method gl_compatibility --path ./testgame/testgame --script res://tests/run_playable_game_evidence_visual_tests.gd
./Godot_v4.6-stable_win64_console.exe --headless --path ./testgame/testgame --script res://tests/run_display_benchmarks.gd
```

For the finite five-enemy game, controls, victory/reset flow, and actual 241-node Live Debug procedure, see `COMPLEX_ARENA_GUIDE.md`.
