# Behavior Tree Visual Scripting

Godot 4.6 editor plugin for building behavior trees with a visual 2D GUI.

## Current features

- Dockable editor plugin inside the Godot editor
- Behavior tree resource format based on custom `Resource` scripts
- Visual node graph using `GraphEdit` and `GraphNode`
- Create root and child nodes from a node palette
- Connect and disconnect parent-child relations visually
- Edit node title, type, status text, and parameters in a side panel
- Save and load `.tres` behavior tree resources

## Open in Godot

1. Launch `Godot_v4.6-stable_win64.exe`
2. Import the folder `E:\course pdf\project\finalproject\visual_scripting`
3. Open the project
4. Make sure the plugin `Behavior Tree Editor` is enabled in `Project > Project Settings > Plugins`

The plugin appears in the bottom panel as `Behavior Tree`.

## Suggested next steps for your graduation project

- Add runtime execution for sequence, selector, and decorator nodes
- Add blackboard variable definitions and typed ports
- Add right-click canvas menus and drag creation
- Add undo/redo integration with `EditorUndoRedoManager`
- Add validation, minimap, and subtree resources
