# Behavior Tree Plugin Usage

## Editor

- Enable the plugin from `Project > Project Settings > Plugins`.
- Open the bottom panel named `Behavior Tree`.
- Right-click an empty point on the graph and choose a node type to create it at the cursor.
- Right-click a node to disconnect, delete, or enable/disable it.
- Use `Undo` and `Redo` in the toolbar while editing.

## Display Tools

- Open the compact `Display` menu to switch individual optimizations and the graph grid. Common `Collapse`, `Expand`, `Focus`, `All`, and `Fit` actions remain directly available.
- Open the compact `Debug` menu for Live Debug, inactive-branch dimming, failure annotations, Live Blackboard, and Blackboard Schema authoring.
- `Fisheye` enlarges only the card directly under the pointer, shrinks surrounding cards, and temporarily reflows them without changing saved positions.
- Enable `Semantic Zoom` and `Zoom-Aware Auto Spacing` to keep low-detail trees dense while temporarily separating expanded cards and preserving clear connection channels.
- Keep `Zoom View Anchor` enabled to preserve the viewport center's relative position within nearby nodes while zoom-triggered layout changes settle.
- Right-click the graph and choose `Arrange for Overview` to save a compact low-detail layout. Zooming out restores these saved coordinates; the expanded spacing is visual only.
- Keep `Edge Obstacle Avoidance` enabled to reroute a connection only when its normal route crosses an unrelated card.
- `Always Curved Edges (Experiment)` and `Translucent Cards (Experiment)` are optional, default-off comparison modes rather than the recommended baseline.

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
