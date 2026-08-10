# Behavior Tree Visual Scripting

Godot 4.6 editor plugin for authoring, debugging, and running behavior trees.

## Current features

- Visual graph editing with drag creation, context menus, undo, and redo
- Root, Sequence, Selector, Random Selector, Parallel, Repeat, Action, Condition, Wait, and Decorator nodes
- Actor method execution, typed blackboard schema, validation, and runtime component
- Editor-only Live Debug with active paths, failure reasons, and blackboard values
- Independent large-tree display tools including compact cards, semantic zoom, fisheye, collapse, search, minimap, and branch dimming
- `.tres` resource save/load and left-to-right child execution order

## Open in Godot

1. Launch `Godot_v4.6-stable_win64.exe`
2. Import the folder `E:\course pdf\project\finalproject\visual_scripting`
3. Open the project
4. Make sure the plugin `Behavior Tree Editor` is enabled in `Project > Project Settings > Plugins`

The plugin appears in the bottom panel as `Behavior Tree`.

## Build a distributable package

From the repository root, run:

```powershell
.\tools\package_behavior_tree_plugin.ps1
```

The script creates `dist/behavior-tree-editor-0.9.0.zip`, verifies every
packaged file against a SHA-256 manifest, installs it into an empty Godot
project, enables the plugin, and checks the editor startup log.
