extends SceneTree

const BehaviorTreeRunner = preload("res://addons/behavior_tree_editor/runtime/behavior_tree_runner.gd")
const BTNodeResource = preload("res://addons/behavior_tree_editor/bt_node_resource.gd")
const BTTreeResource = preload("res://addons/behavior_tree_editor/bt_tree_resource.gd")
const BTStatus = preload("res://addons/behavior_tree_editor/runtime/bt_status.gd")

const TREE_SIZES := [31, 121, 364]
const NPC_COUNTS := [1, 10, 50]
const SAMPLE_COUNT := 7
const OUTPUT_PATH := "res://test_results/runtime_profile.csv"

var passed := 0
var failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test_results"))
	var csv := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	csv.store_csv_line(["tree_nodes", "npc_count", "cache_enabled", "sample", "ticks_per_runner", "total_ticks", "elapsed_ms", "mean_tick_us", "terminal_status"])
	for tree_size in TREE_SIZES:
		var tree := _make_profile_tree(tree_size)
		_expect(tree.nodes.size() == tree_size and tree.validate_tree().is_empty(), "%d-node runtime profile tree is valid" % tree_size)
		for npc_count in NPC_COUNTS:
			var ticks_per_runner := _ticks_per_runner(tree_size, npc_count)
			var medians: Dictionary = {}
			for cache_enabled in [false, true]:
				var runners := _make_runners(tree, npc_count, cache_enabled)
				for runner in runners:
					_expect(runner.tick(0.016) == BTStatus.SUCCESS, "%d-node %d-NPC cache=%s warmup preserves SUCCESS" % [tree_size, npc_count, str(cache_enabled)])
				var timings: Array[float] = []
				for sample in range(SAMPLE_COUNT):
					var start := Time.get_ticks_usec()
					var status := BTStatus.FAILURE
					for unused in range(ticks_per_runner):
						for runner in runners:
							status = runner.tick(0.016)
					var elapsed_ms := float(Time.get_ticks_usec() - start) / 1000.0
					var total_ticks: int = ticks_per_runner * int(npc_count)
					var mean_tick_us := elapsed_ms * 1000.0 / float(total_ticks)
					timings.append(mean_tick_us)
					csv.store_csv_line([tree_size, npc_count, cache_enabled, sample + 1, ticks_per_runner, total_ticks, "%.4f" % elapsed_ms, "%.4f" % mean_tick_us, status])
					_expect(status == BTStatus.SUCCESS, "%d-node %d-NPC cache=%s measured ticks preserve SUCCESS" % [tree_size, npc_count, str(cache_enabled)])
				medians[cache_enabled] = _median(timings)
				for runner in runners:
					runner.free()
			var uncached_us: float = medians[false]
			var cached_us: float = medians[true]
			var improvement := (uncached_us - cached_us) / uncached_us * 100.0 if uncached_us > 0.0 else 0.0
			print("RUNTIME_PROFILE tree=%d npc=%d uncached_us=%.3f cached_us=%.3f improvement_pct=%.2f" % [tree_size, npc_count, uncached_us, cached_us, improvement])
			_expect(cached_us < uncached_us, "%d-node %d-NPC runtime cache improves median tick latency" % [tree_size, npc_count])
	csv.close()
	_test_cache_invalidation()
	print("BT_RUNTIME_PROFILE_SUMMARY passed=%d failed=%d output=%s" % [passed, failed, OUTPUT_PATH])
	quit(0 if failed == 0 else 1)


func _make_profile_tree(node_count: int) -> BTTreeResource:
	var tree := BTTreeResource.new()
	tree.tree_name = "Runtime Profile %d" % node_count
	tree.root_node_id = 1
	var root_node := _node(1, BTNodeResource.TYPE_ROOT, -1, 0.0)
	var sequence := _node(2, BTNodeResource.TYPE_SEQUENCE, 1, 0.0)
	tree.nodes = [root_node, sequence]
	for id in range(3, node_count + 1):
		var condition := _node(id, BTNodeResource.TYPE_CONDITION, 2, float(id) * 20.0)
		condition.parameters = {"mode": "blackboard", "blackboard_key": "profile_ready", "operator": "equals", "value": true}
		tree.nodes.append(condition)
	return tree


func _node(id: int, type_name: String, parent_id: int, x: float) -> BTNodeResource:
	var node := BTNodeResource.new()
	node.id = id
	node.node_type = type_name
	node.parent_id = parent_id
	node.title = "%s %d" % [type_name, id]
	node.position = Vector2(x, float(parent_id + 1) * 200.0)
	return node


func _make_runners(tree: BTTreeResource, count: int, cache_enabled: bool) -> Array[BehaviorTreeRunner]:
	var runners: Array[BehaviorTreeRunner] = []
	for unused in range(count):
		var runner := BehaviorTreeRunner.new()
		runner.tick_on_process = false
		runner.tick_on_physics = false
		runner.debug_enabled = false
		runner.editor_debug_bridge_enabled = false
		runner.use_runtime_cache = cache_enabled
		runner.blackboard = {"profile_ready": true}
		runner.behavior_tree = tree
		runners.append(runner)
	return runners


func _ticks_per_runner(tree_size: int, npc_count: int) -> int:
	var target_node_visits := 30000
	return maxi(1, target_node_visits / maxi(1, tree_size * npc_count))


func _median(values: Array[float]) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2]


func _test_cache_invalidation() -> void:
	var tree := _make_profile_tree(31)
	var runner := _make_runners(tree, 1, true)[0]
	_expect(runner.tick() == BTStatus.SUCCESS and runner._node_cache.size() == 31, "runtime cache indexes the first assigned tree")
	var node3 := tree.find_node(3)
	var node4 := tree.find_node(4)
	node3.position.x = 1000.0
	node4.position.x = 10.0
	_expect(runner.tick() == BTStatus.SUCCESS and runner._children_cache[2][0].id == 4, "same-size child reorder invalidates runtime cache")
	node3.parent_id = 4
	_expect(runner.tick() == BTStatus.SUCCESS and runner._children_cache.has(4) and runner._children_cache[4][0].id == 3, "same-size parent mutation invalidates runtime cache")
	node3.parent_id = 2
	node3.decorator_parent_id = 4
	node3.parameters = {"mode": "blackboard", "blackboard_key": "profile_ready", "operator": "equals", "value": true}
	_expect(runner.tick() == BTStatus.SUCCESS and runner._decorator_cache.has(4) and runner._decorator_cache[4][0].id == 3, "same-size Decorator ownership mutation invalidates runtime cache")
	var replacement_node := node3.duplicate(true) as BTNodeResource
	tree.nodes[2] = replacement_node
	_expect(runner.tick() == BTStatus.SUCCESS and runner._node_cache[3] == replacement_node, "same-ID node instance replacement invalidates runtime cache")
	var replacement := _make_profile_tree(5)
	runner.behavior_tree = replacement
	_expect(runner._node_cache.is_empty() and runner.tick() == BTStatus.SUCCESS and runner._node_cache.size() == 5, "tree replacement invalidates and rebuilds runtime cache")
	runner.use_runtime_cache = false
	_expect(runner._node_cache.is_empty() and runner.tick() == BTStatus.SUCCESS, "runtime cache switch safely restores uncached execution")
	runner.free()


func _expect(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS: %s" % label)
	else:
		failed += 1
		printerr("FAIL: %s" % label)
