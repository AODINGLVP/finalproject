# Behavior Tree Editor 0.9.0

A visual behavior-tree editor and runtime for Godot 4.6.

## Install

1. Extract the package so the project contains `addons/behavior_tree_editor/plugin.cfg`.
2. Open the project in Godot 4.6.
3. Open `Project > Project Settings > Plugins`.
4. Enable `Behavior Tree Editor`.
5. Open the `Behavior Tree` bottom panel.

## Runtime

Add `runtime/behavior_tree_component.gd` as a child node of an actor, assign a
`BTTreeResource`, and set `actor_path` when the actor is not the component's
parent. Action and actor-method Condition nodes call methods with this signature:

```gdscript
func action_name(blackboard: Dictionary, delta: float, node: BTNodeResource) -> int:
	return BTStatus.SUCCESS
```

The component supports Root, Sequence, Selector, Random Selector, Parallel,
Repeat, Action, Condition, Wait, and Decorator nodes. Runtime state is exposed
to the editor through Live Debug; the package does not add an in-game overlay.

## Compatibility

This release is tested with Godot 4.6. It is distributed under the MIT License.
