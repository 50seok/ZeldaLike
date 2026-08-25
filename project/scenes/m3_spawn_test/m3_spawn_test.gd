extends Node2D

## M3 우선순위2(스폰포인트 리젠) 검증: 화면 밖+쿨다운 경과 시 재등장, 화면 안이면
## 재등장 보류, 필드 마릿수 상한 준수를 확인한다.

@onready var _label: Label = $DebugLabel

var _log: Array[String] = []
var _pass_count := 0
var _fail_count := 0


func _ready() -> void:
	await get_tree().process_frame
	await _run_all_tests()
	_print_summary()


func _check(label: String, condition: bool) -> void:
	if condition:
		_pass_count += 1
		_log.append("[PASS] %s" % label)
	else:
		_fail_count += 1
		_log.append("[FAIL] %s" % label)
	_refresh_label()


func _refresh_label() -> void:
	_label.text = "\n".join(_log)


func _make_manager(points: Array[SpawnPoint], cap: int, camera_pos: Vector2) -> Dictionary:
	var camera := Camera2D.new()
	camera.global_position = camera_pos
	add_child(camera)
	camera.make_current()

	var mgr := FieldSpawnManager.new()
	mgr.spawn_points = points
	mgr.field_cap = cap
	add_child(mgr)
	mgr.setup(camera)
	return {"camera": camera, "mgr": mgr}


func _run_all_tests() -> void:
	await _test_respawn_when_offscreen()
	await _test_no_respawn_when_onscreen()
	await _test_field_cap_holds()


func _test_respawn_when_offscreen() -> void:
	var sp := SpawnPoint.new()
	sp.entity_type = "vine"
	sp.respawn_sec = 0.2
	sp.max_alive = 1
	sp.position = Vector2(100, 100)
	add_child(sp)

	var setup := _make_manager([sp], 5, Vector2(5000, 5000))  # 카메라 멀리 = 화면 밖
	var mgr: FieldSpawnManager = setup["mgr"]
	await get_tree().process_frame

	var first := mgr._alive[sp][0] as Node
	_check("초기 배치 -> 스폰포인트에서 1마리 생성", is_instance_valid(first))

	first.call("take_damage", 999.0)
	await get_tree().create_timer(0.5).timeout
	_check("죽은 뒤 쿨다운 경과+화면 밖 -> 재등장", mgr._alive[sp].size() >= 1 and is_instance_valid(mgr._alive[sp][0]))

	for n in get_children():
		if n is VineEnemy:
			n.queue_free()
	sp.queue_free()
	mgr.queue_free()
	setup["camera"].queue_free()
	await get_tree().create_timer(0.1).timeout


func _test_no_respawn_when_onscreen() -> void:
	var sp := SpawnPoint.new()
	sp.entity_type = "vine"
	sp.respawn_sec = 0.2
	sp.max_alive = 1
	sp.position = Vector2(100, 100)
	add_child(sp)

	var setup := _make_manager([sp], 5, Vector2(100, 100))  # 카메라 = 스폰 지점(화면 안)
	var mgr: FieldSpawnManager = setup["mgr"]
	await get_tree().process_frame

	var first := mgr._alive[sp][0] as Node
	first.call("take_damage", 999.0)
	await get_tree().create_timer(0.5).timeout
	_check("죽은 뒤 쿨다운 경과했지만 화면 안 -> 재등장 보류", mgr._alive[sp].is_empty())

	for n in get_children():
		if n is VineEnemy:
			n.queue_free()
	sp.queue_free()
	mgr.queue_free()
	setup["camera"].queue_free()
	await get_tree().create_timer(0.1).timeout


func _test_field_cap_holds() -> void:
	var sp1 := SpawnPoint.new()
	sp1.entity_type = "vine"
	sp1.respawn_sec = 0.2
	sp1.position = Vector2(100, 100)
	add_child(sp1)

	var sp2 := SpawnPoint.new()
	sp2.entity_type = "vine"
	sp2.respawn_sec = 0.2
	sp2.position = Vector2(130, 100)
	add_child(sp2)

	var setup := _make_manager([sp1, sp2], 1, Vector2(5000, 5000))  # 상한 1, 화면 밖
	var mgr: FieldSpawnManager = setup["mgr"]
	await get_tree().process_frame

	_check("초기 배치 -> 상한(1) 안에서만 채워짐", _total_alive(mgr) == 1)

	# 둘 다 죽여서 동시에 쿨다운 만료되게 유도
	for sp in [sp1, sp2]:
		for n in mgr._alive[sp]:
			if is_instance_valid(n):
				n.call("take_damage", 999.0)
	await get_tree().create_timer(0.5).timeout
	_check("리젠 시점에도 상한 초과 안 함", _total_alive(mgr) <= 1)

	for n in get_children():
		if n is VineEnemy:
			n.queue_free()
	sp1.queue_free()
	sp2.queue_free()
	mgr.queue_free()
	setup["camera"].queue_free()
	await get_tree().create_timer(0.1).timeout


func _total_alive(mgr: FieldSpawnManager) -> int:
	var n := 0
	for sp in mgr._alive:
		for node in mgr._alive[sp]:
			if is_instance_valid(node):
				n += 1
	return n


func _print_summary() -> void:
	var summary := "=== M3 스폰리젠 검증: PASS %d / FAIL %d ===" % [_pass_count, _fail_count]
	_log.append(summary)
	_refresh_label()
	print(summary)
	for line in _log:
		print(line)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _fail_count == 0 else 1)
