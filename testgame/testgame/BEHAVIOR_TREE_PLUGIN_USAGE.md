# Behavior Tree Plugin Usage

## Editor

- Enable the plugin from `Project > Project Settings > Plugins`.
- Open the bottom panel named `Behavior Tree`.
- Drag node types from the `Palette` into the graph.
- Right-click the graph to add nodes at the cursor.
- Right-click a node to disconnect, delete, or enable/disable it.
- Use `Undo` and `Redo` in the toolbar while editing.
- Use the attached-decorator list in `Node Inspector` to edit or remove decorators.
- The editor validates roots, connections, cycles, leaf children, decorators, and disconnected nodes before saving.

## Display Tools

- Open `Display Features` to enable or disable every optimization independently.
- `Fisheye`: locally enlarges nodes near the pointer without changing the graph zoom.
- `Compact`: reduces card size and keeps only the essential node identity.
- `Semantic Zoom`: hides secondary information at low zoom while keeping card geometry stable.
- `Zoom-Aware Auto Spacing`: temporarily separates expanded cards at medium or full detail without changing saved node coordinates.
- `Arrange for Overview`: right-click the canvas and choose this command to save a compact low-detail layout; zooming in then demonstrates Auto Spacing, while zooming out restores the dense arrangement.
- `Collapse All` / `Expand All`: summarizes or restores child subtrees.
- `Focus`: keeps the selected subtree and its ancestor path; `Show All` restores the full tree.
- `Find Node`: highlights matches in titles, types, descriptions, action names, condition names, and decorators.
- `Minimap`, `Grid`, and `Fit`: support navigation in large trees.
- `Runtime Path` and `Selection` show clickable path buttons for Live Debug and the selected node.
- `Active Path Highlight`, `Non-active Branch Dimming`, and `Failure Reason Annotation` explain runtime decisions in the editor.
- `Multi-column Layout` wraps wide fan-outs while preserving left-to-right execution order.
- `Stable Incremental Layout` keeps valid existing positions when `Auto Arrange` is used.
- `Orthogonal Edges` and `Edge Bundling` provide alternative connection routing for dense trees.

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
./Godot_v4.6-stable_win64_console.exe --headless --path ./testgame/testgame --script res://tests/run_arena_smoke_test.gd
./Godot_v4.6-stable_win64_console.exe --headless --path ./testgame/testgame --script res://tests/run_display_benchmarks.gd
```
