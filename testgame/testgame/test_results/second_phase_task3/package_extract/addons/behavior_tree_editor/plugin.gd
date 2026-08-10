@tool
extends EditorPlugin

const BTEditorView = preload("res://addons/behavior_tree_editor/bt_editor_view.gd")

var editor_view: BTEditorView


func _enter_tree() -> void:
	editor_view = BTEditorView.new()
	editor_view.plugin = self
	add_control_to_bottom_panel(editor_view, "Behavior Tree")


func _exit_tree() -> void:
	if is_instance_valid(editor_view):
		remove_control_from_bottom_panel(editor_view)
		editor_view.queue_free()
