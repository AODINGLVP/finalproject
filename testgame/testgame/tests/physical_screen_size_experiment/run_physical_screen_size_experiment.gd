extends "res://tests/run_multiscale_display_experiment.gd"

## Runs the established multiscale display conditions on one physical display.
## The canvas is derived from EDID centimetres at a fixed logical density so
## native resolution is retained only as audit metadata, not as the treatment.

const EVIDENCE_TREE_SIZES := [241, 364]
const EVIDENCE_CONDITIONS := ["Baseline", "Optimized Overview", "Optimized Search"]

var run_output_dir := ""
var screen_metadata: Dictionary = {}
var normalized_viewport_size := Vector2i(1600, 900)
var measured_trials := 3
var warmup_trials := 2
var logical_units_per_cm := 35.0
var matched_screen_index := -1
var matched_screen_metadata: Dictionary = {}


func _run() -> void:
	_load_configuration()
	await _place_window_on_requested_screen()
	if failures > 0:
		quit(1)
		return

	var viewport := SubViewport.new()
	viewport.size = normalized_viewport_size
	viewport.gui_embed_subwindows = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)
	var view := BTEditorView.new()
	view.size = Vector2(normalized_viewport_size)
	viewport.add_child(view)
	await _settle_frames()

	var fixtures := await _build_fixtures(view)
	if failures > 0:
		view.free()
		viewport.free()
		quit(1)
		return

	var raw_rows: Array[PackedStringArray] = []
	raw_rows.append(_raw_header())
	var samples_by_key: Dictionary = {}
	var metrics_by_key: Dictionary = {}
	var geometry_signatures: Dictionary = {}
	var geometry_consistent: Dictionary = {}
	for size_variant in TREE_SIZES:
		var tree_size := int(size_variant)
		for condition_variant in CONDITIONS:
			var condition := str(condition_variant)
			var empty_samples: Array[float] = []
			var key := _key(tree_size, condition)
			samples_by_key[key] = empty_samples
			geometry_consistent[key] = true

	for size_variant in TREE_SIZES:
		var tree_size := int(size_variant)
		var fixture: Dictionary = fixtures[tree_size]
		await _activate_tree(view, fixture)
		for condition_variant in CONDITIONS:
			var condition := str(condition_variant)
			for warmup_index in range(warmup_trials):
				await _restore_baseline(view, fixture["tree"])
				await _apply_condition(view, fixture, condition)

	for trial in range(1, measured_trials + 1):
		for size_position in range(TREE_SIZES.size()):
			var size_index := (trial - 1 + size_position) % TREE_SIZES.size()
			var tree_size := int(TREE_SIZES[size_index])
			var fixture: Dictionary = fixtures[tree_size]
			await _activate_tree(view, fixture)
			for condition_position in range(CONDITIONS.size()):
				var condition_index := (trial - 1 + size_position + condition_position) % CONDITIONS.size()
				var condition := str(CONDITIONS[condition_index])
				await _restore_baseline(view, fixture["tree"])
				var started_usec := Time.get_ticks_usec()
				await _apply_condition(view, fixture, condition)
				var interaction_ms := float(Time.get_ticks_usec() - started_usec) / 1000.0
				var metrics := _measure_physical_screen(view, fixture, _information_fields_for(condition))
				metrics["fit_zoom"] = await _measure_fit_zoom(view)
				metrics["cards_in_viewport_after_fit"] = _count_cards_in_viewport(view)
				metrics["fit_viewport_coverage_ratio"] = _safe_ratio(
					float(metrics["cards_in_viewport_after_fit"]), float(metrics["rendered_cards"])
				)
				var key := _key(tree_size, condition)
				var samples: Array[float] = samples_by_key[key]
				samples.append(interaction_ms)
				samples_by_key[key] = samples
				metrics_by_key[key] = metrics
				var signature := _geometry_signature(metrics)
				if geometry_signatures.has(key):
					geometry_consistent[key] = bool(geometry_consistent[key]) and str(geometry_signatures[key]) == signature
				else:
					geometry_signatures[key] = signature
				raw_rows.append(_physical_raw_row(
					trial, size_position + 1, condition_position + 1, tree_size,
					condition, metrics, interaction_ms
				))
		print("BT_PHYSICAL_SCREEN_PROGRESS device=%s trial=%d/%d" % [
			str(screen_metadata["device_key"]), trial, measured_trials,
		])

	var summary_rows := _build_physical_summary_rows(samples_by_key, metrics_by_key)
	_write_absolute_rows(run_output_dir.path_join("raw.csv"), raw_rows)
	_write_absolute_rows(run_output_dir.path_join("summary.csv"), summary_rows)
	await _capture_physical_evidence(view, viewport, fixtures)
	failures += _validate_results(fixtures, metrics_by_key)
	for key_variant in geometry_consistent.keys():
		var key := str(key_variant)
		failures += _expect(bool(geometry_consistent[key]), "%s geometry is stable across repetitions" % key)

	_write_run_manifest()
	print("BT_PHYSICAL_SCREEN_SUMMARY device=%s diagonal_in=%.2f canvas=%dx%d observations=%d failed=%d output=%s" % [
		str(screen_metadata["device_key"]), float(screen_metadata["diagonal_in"]),
		normalized_viewport_size.x, normalized_viewport_size.y,
		TREE_SIZES.size() * CONDITIONS.size() * measured_trials, failures, run_output_dir,
	])
	view.free()
	viewport.free()
	quit(0 if failures == 0 else 1)


func _load_configuration() -> void:
	run_output_dir = OS.get_environment("BT_SCREEN_OUTPUT_DIR").replace("\\", "/")
	if run_output_dir.is_empty():
		run_output_dir = ProjectSettings.globalize_path("res://test_results/physical_screen_size_experiment/manual")
	logical_units_per_cm = _environment_float("BT_SCREEN_LOGICAL_UNITS_PER_CM", 35.0)
	warmup_trials = _environment_int("BT_SCREEN_WARMUPS", 2)
	measured_trials = _environment_int("BT_SCREEN_TRIALS", 3)
	var width_cm := _environment_float("BT_SCREEN_WIDTH_CM", 0.0)
	var height_cm := _environment_float("BT_SCREEN_HEIGHT_CM", 0.0)
	var diagonal_in := sqrt(width_cm * width_cm + height_cm * height_cm) / 2.54
	normalized_viewport_size = Vector2i(
		maxi(640, roundi(width_cm * logical_units_per_cm)),
		maxi(480, roundi(height_cm * logical_units_per_cm))
	)
	screen_metadata = {
		"session": OS.get_environment("BT_SCREEN_SESSION"),
		"device_key": OS.get_environment("BT_SCREEN_DEVICE_KEY"),
		"gdi_name": OS.get_environment("BT_SCREEN_GDI_NAME"),
		"manufacturer": OS.get_environment("BT_SCREEN_MANUFACTURER"),
		"model": OS.get_environment("BT_SCREEN_MODEL"),
		"serial": OS.get_environment("BT_SCREEN_SERIAL"),
		"width_cm": width_cm,
		"height_cm": height_cm,
		"diagonal_in": diagonal_in,
		"screen_area_cm2": width_cm * height_cm,
		"expected_x": _environment_int("BT_SCREEN_POSITION_X", 0),
		"expected_y": _environment_int("BT_SCREEN_POSITION_Y", 0),
		"expected_godot_index": _environment_int("BT_SCREEN_GODOT_INDEX", -1),
		"native_width": _environment_int("BT_SCREEN_NATIVE_WIDTH", 0),
		"native_height": _environment_int("BT_SCREEN_NATIVE_HEIGHT", 0),
		"refresh_hz": _environment_int("BT_SCREEN_REFRESH_HZ", 0),
	}
	failures += _expect(width_cm > 0.0 and height_cm > 0.0, "EDID physical width and height are available")
	failures += _expect(not str(screen_metadata["device_key"]).is_empty(), "physical display device key is available")
	failures += _expect(measured_trials > 0 and warmup_trials >= 0, "trial counts are valid")
	DirAccess.make_dir_recursive_absolute(run_output_dir)


func _place_window_on_requested_screen() -> void:
	var expected_position := Vector2i(int(screen_metadata["expected_x"]), int(screen_metadata["expected_y"]))
	var expected_godot_index := int(screen_metadata["expected_godot_index"])
	var closest_distance := INF
	for screen_index in range(DisplayServer.get_screen_count()):
		var position := DisplayServer.screen_get_position(screen_index)
		print("BT_PHYSICAL_SCREEN_CANDIDATE index=%d position=%s size=%s dpi=%d scale=%.3f" % [
			screen_index, str(position), str(DisplayServer.screen_get_size(screen_index)),
			DisplayServer.screen_get_dpi(screen_index), DisplayServer.screen_get_scale(screen_index),
		])
		var distance := Vector2(position - expected_position).length()
		if distance < closest_distance:
			closest_distance = distance
			matched_screen_index = screen_index
	if expected_godot_index >= 0 and expected_godot_index < DisplayServer.get_screen_count():
		matched_screen_index = expected_godot_index
	failures += _expect(matched_screen_index >= 0, "Godot screen index is available for the requested physical display")
	if matched_screen_index < 0:
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_current_screen(matched_screen_index)
	var screen_position := DisplayServer.screen_get_position(matched_screen_index)
	var screen_size := DisplayServer.screen_get_size(matched_screen_index)
	var window_size := Vector2i(
		mini(normalized_viewport_size.x, screen_size.x),
		mini(normalized_viewport_size.y, screen_size.y)
	)
	DisplayServer.window_set_size(window_size)
	DisplayServer.window_set_position(screen_position + (screen_size - window_size) / 2)
	await process_frame
	await process_frame
	matched_screen_metadata = {
		"godot_screen_index": matched_screen_index,
		"godot_position": screen_position,
		"godot_size": screen_size,
		"godot_usable_rect": DisplayServer.screen_get_usable_rect(matched_screen_index),
		"godot_dpi": DisplayServer.screen_get_dpi(matched_screen_index),
		"godot_scale": DisplayServer.screen_get_scale(matched_screen_index),
	}
	failures += _expect(DisplayServer.window_get_current_screen() == matched_screen_index, "experiment window is on the requested physical display")


func _measure_physical_screen(view: BTEditorView, fixture: Dictionary, information_fields: int) -> Dictionary:
	var metrics := super._measure(view, fixture, information_fields)
	var rendered_cards := int(metrics["rendered_cards"])
	var cards_in_viewport := int(metrics["cards_in_viewport"])
	metrics["cards_in_viewport_before_fit"] = cards_in_viewport
	metrics["viewport_coverage_before_fit_ratio"] = _safe_ratio(float(cards_in_viewport), float(rendered_cards))
	metrics["context_retention_ratio"] = _safe_ratio(float(rendered_cards), float(fixture["card_count"]))
	metrics["card_area_cm2"] = float(metrics["card_area_px2"]) / (logical_units_per_cm * logical_units_per_cm)
	metrics["bounds_area_cm2"] = float(metrics["bounds_area_px2"]) / (logical_units_per_cm * logical_units_per_cm)
	metrics["graph_to_screen_area_ratio"] = _safe_ratio(
		float(metrics["bounds_area_cm2"]), float(screen_metadata["screen_area_cm2"])
	)
	var graph_canvas := view.graph_edit.get_global_rect()
	var target_center_error_ratio := -1.0
	for child in view.graph_edit.get_children():
		if child is BTGraphNode and child.node_resource.id == int(fixture["target_id"]):
			var graph_node: BTGraphNode = child
			var target_center: Vector2 = graph_node.get_global_rect().get_center()
			target_center_error_ratio = target_center.distance_to(graph_canvas.get_center()) / graph_canvas.size.length()
			break
	metrics["target_center_error_ratio"] = target_center_error_ratio
	return metrics


func _raw_header() -> PackedStringArray:
	return PackedStringArray([
		"session", "device_key", "gdi_name", "manufacturer", "model", "serial",
		"width_cm", "height_cm", "diagonal_in", "screen_area_cm2", "logical_units_per_cm",
		"normalized_canvas_width", "normalized_canvas_height", "godot_screen_index",
		"trial", "size_sequence_position", "condition_sequence_position", "tree_size", "condition",
		"resource_nodes", "rendered_cards", "decorators", "context_retention_ratio",
		"cards_in_viewport_before_fit", "viewport_coverage_before_fit_ratio",
		"cards_in_viewport_after_fit", "fit_viewport_coverage_ratio", "fit_zoom",
		"bounds_area_cm2", "graph_to_screen_area_ratio", "card_area_cm2", "overlap_pairs",
		"min_parent_child_gap_px", "information_fields", "dimmed_cards", "target_in_viewport",
		"target_center_error_ratio", "interaction_ms", "engine_version", "renderer", "gpu",
	])


func _physical_raw_row(trial: int, size_position: int, condition_position: int, tree_size: int, condition: String, metrics: Dictionary, interaction_ms: float) -> PackedStringArray:
	return PackedStringArray([
		str(screen_metadata["session"]), str(screen_metadata["device_key"]), str(screen_metadata["gdi_name"]),
		str(screen_metadata["manufacturer"]), str(screen_metadata["model"]), str(screen_metadata["serial"]),
		str(screen_metadata["width_cm"]), str(screen_metadata["height_cm"]), str(screen_metadata["diagonal_in"]),
		str(screen_metadata["screen_area_cm2"]), str(logical_units_per_cm),
		str(normalized_viewport_size.x), str(normalized_viewport_size.y), str(matched_screen_index),
		str(trial), str(size_position), str(condition_position), str(tree_size), condition,
		str(metrics["resource_nodes"]), str(metrics["rendered_cards"]), str(metrics["decorators"]),
		str(metrics["context_retention_ratio"]), str(metrics["cards_in_viewport_before_fit"]),
		str(metrics["viewport_coverage_before_fit_ratio"]), str(metrics["cards_in_viewport_after_fit"]),
		str(metrics["fit_viewport_coverage_ratio"]), str(metrics["fit_zoom"]), str(metrics["bounds_area_cm2"]),
		str(metrics["graph_to_screen_area_ratio"]), str(metrics["card_area_cm2"]), str(metrics["overlap_pairs"]),
		str(metrics["min_parent_child_gap_px"]), str(metrics["information_fields"]), str(metrics["dimmed_cards"]),
		str(metrics["target_in_viewport"]), str(metrics["target_center_error_ratio"]), str(interaction_ms),
		str(Engine.get_version_info().get("string", "unknown")), RenderingServer.get_current_rendering_method(),
		RenderingServer.get_video_adapter_name(),
	])


func _build_physical_summary_rows(samples_by_key: Dictionary, metrics_by_key: Dictionary) -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	rows.append(PackedStringArray([
		"device_key", "model", "diagonal_in", "screen_area_cm2", "tree_size", "condition", "n",
		"rendered_cards", "context_reduction_percent", "cards_before_fit", "coverage_before_fit_percent",
		"cards_after_fit", "coverage_after_fit_percent", "fit_zoom", "graph_to_screen_area_ratio",
		"card_area_cm2", "card_area_reduction_percent", "dimmed_cards", "target_in_viewport",
		"target_center_error_ratio", "overlap_max", "min_parent_child_gap_px", "median_interaction_ms",
	]))
	for size_variant in TREE_SIZES:
		var tree_size := int(size_variant)
		var baseline: Dictionary = metrics_by_key[_key(tree_size, "Baseline")]
		for condition_variant in CONDITIONS:
			var condition := str(condition_variant)
			var key := _key(tree_size, condition)
			var metrics: Dictionary = metrics_by_key[key]
			var samples: Array[float] = samples_by_key[key]
			rows.append(PackedStringArray([
				str(screen_metadata["device_key"]), str(screen_metadata["model"]), str(screen_metadata["diagonal_in"]),
				str(screen_metadata["screen_area_cm2"]), str(tree_size), condition, str(samples.size()),
				str(metrics["rendered_cards"]),
				str(_reduction(float(metrics["rendered_cards"]), float(baseline["rendered_cards"]))),
				str(metrics["cards_in_viewport_before_fit"]), str(float(metrics["viewport_coverage_before_fit_ratio"]) * 100.0),
				str(metrics["cards_in_viewport_after_fit"]), str(float(metrics["fit_viewport_coverage_ratio"]) * 100.0),
				str(metrics["fit_zoom"]), str(metrics["graph_to_screen_area_ratio"]), str(metrics["card_area_cm2"]),
				str(_reduction(float(metrics["card_area_cm2"]), float(baseline["card_area_cm2"]))),
				str(metrics["dimmed_cards"]), str(metrics["target_in_viewport"]), str(metrics["target_center_error_ratio"]),
				str(metrics["overlap_pairs"]), str(metrics["min_parent_child_gap_px"]), str(_median(samples)),
			]))
	return rows


func _capture_physical_evidence(view: BTEditorView, viewport: SubViewport, fixtures: Dictionary) -> void:
	var screenshot_dir := run_output_dir.path_join("screenshots")
	DirAccess.make_dir_recursive_absolute(screenshot_dir)
	for size_variant in EVIDENCE_TREE_SIZES:
		var tree_size := int(size_variant)
		var fixture: Dictionary = fixtures[tree_size]
		await _activate_tree(view, fixture)
		for condition_variant in EVIDENCE_CONDITIONS:
			var condition := str(condition_variant)
			await _restore_baseline(view, fixture["tree"])
			await _apply_condition(view, fixture, condition)
			if condition != "Optimized Search":
				view._fit_visible_tree()
				await _settle_frames()
			viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			RenderingServer.force_draw(false, 0.0)
			await process_frame
			var image := viewport.get_texture().get_image()
			var filename := "%03d_%s.png" % [tree_size, condition.to_lower().replace(" ", "_")]
			var save_error := image.save_png(screenshot_dir.path_join(filename))
			failures += _expect(save_error == OK, "%d-node %s physical-screen screenshot saves" % [tree_size, condition])


func _geometry_signature(metrics: Dictionary) -> String:
	return "|".join(PackedStringArray([
		str(metrics["rendered_cards"]), str(metrics["cards_in_viewport_before_fit"]),
		str(metrics["cards_in_viewport_after_fit"]), str(metrics["fit_zoom"]),
		str(metrics["bounds_area_px2"]), str(metrics["card_area_px2"]),
		str(metrics["overlap_pairs"]), str(metrics["min_parent_child_gap_px"]),
		str(metrics["dimmed_cards"]), str(metrics["target_in_viewport"]),
		str(metrics["target_center_error_ratio"]),
	]))


func _write_run_manifest() -> void:
	var manifest := {
		"schema_version": 1,
		"created_at": Time.get_datetime_string_from_system(true),
		"git_commit": OS.get_environment("BT_SCREEN_GIT_COMMIT"),
		"screen": screen_metadata,
		"matched_screen": matched_screen_metadata,
		"normalized_canvas": {
			"logical_units_per_cm": logical_units_per_cm,
			"width": normalized_viewport_size.x,
			"height": normalized_viewport_size.y,
		},
		"tree_sizes": TREE_SIZES,
		"conditions": CONDITIONS,
		"warmups": warmup_trials,
		"measured_trials": measured_trials,
		"observation_count": TREE_SIZES.size() * CONDITIONS.size() * measured_trials,
		"failures": failures,
		"engine_version": str(Engine.get_version_info().get("string", "unknown")),
		"renderer": RenderingServer.get_current_rendering_method(),
		"gpu": RenderingServer.get_video_adapter_name(),
	}
	var file := FileAccess.open(run_output_dir.path_join("manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "  "))
	file.close()


func _write_absolute_rows(path: String, rows: Array[PackedStringArray]) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	failures += _expect(file != null, "CSV output opens: %s" % path.get_file())
	if file == null:
		return
	for row in rows:
		file.store_csv_line(row)
	file.close()


func _environment_int(name: String, default_value: int) -> int:
	var value := OS.get_environment(name)
	return value.to_int() if not value.is_empty() else default_value


func _environment_float(name: String, default_value: float) -> float:
	var value := OS.get_environment(name)
	return value.to_float() if not value.is_empty() else default_value


func _safe_ratio(numerator: float, denominator: float) -> float:
	return numerator / denominator if denominator > 0.0 else 0.0
