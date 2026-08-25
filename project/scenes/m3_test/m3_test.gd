extends Node2D

## M3 인벤토리+드랍 테이블 검증. 확률 기반 드랍은 확정(chance=1.0) 테이블로
## 바꿔치기해서 결정적으로 확인한다(진짜 확률표는 이미 vine_enemy.gd에 있음).

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


func _make_certain_table(item_id: String, count: int, burning_item_id: String = "") -> DropTable:
	var table := DropTable.new()
	var entry := DropEntry.new()
	entry.item_id = item_id
	entry.chance = 1.0
	entry.min_count = count
	entry.max_count = count
	table.default_drops = [entry]
	if burning_item_id != "":
		var burn_entry := DropEntry.new()
		burn_entry.item_id = burning_item_id
		burn_entry.chance = 1.0
		table.burning_drops = [burn_entry]
	return table


func _spawn_player(pos: Vector2) -> Player:
	var p := Player.new()
	p.global_position = pos
	add_child(p)
	return p


func _spawn_vine(pos: Vector2) -> VineEnemy:
	var v := VineEnemy.new()
	v.global_position = pos
	add_child(v)
	return v


func _run_all_tests() -> void:
	await _test_normal_kill_drop()
	await _test_burning_kill_no_drop()
	_test_heart_piece_accumulation()
	_test_generic_item_stacking()


func _test_normal_kill_drop() -> void:
	var player := _spawn_player(Vector2(100, 100))
	var vine := _spawn_vine(Vector2(100, 130))
	await get_tree().physics_frame
	vine.drop_table = _make_certain_table(ItemIds.ARROW, 3)
	var before_arrows := player.inventory.get_count(ItemIds.ARROW)
	player.perform_melee_attack()
	await get_tree().create_timer(0.1).timeout
	_check("A 일반 처치 -> 확정 드랍 지급(화살+3)", player.inventory.get_count(ItemIds.ARROW) == before_arrows + 3)
	player.queue_free()
	if is_instance_valid(vine):
		vine.queue_free()
	await get_tree().create_timer(0.1).timeout


func _test_burning_kill_no_drop() -> void:
	var player := _spawn_player(Vector2(300, 100))
	var vine := _spawn_vine(Vector2(300, 130))
	# burning_drops를 비워둔 테이블 -> 태워 죽이면 드랍 없음(§3.3 수풀 예시)
	vine.drop_table = _make_certain_table(ItemIds.ARROW, 3)
	await get_tree().physics_frame
	var before_arrows := player.inventory.get_count(ItemIds.ARROW)
	vine.set_state(ChemTypes.State.BURNING)
	await get_tree().create_timer(0.6).timeout
	_check("B 태워 죽이면 -> 드랍 없음", player.inventory.get_count(ItemIds.ARROW) == before_arrows)
	player.queue_free()
	await get_tree().create_timer(0.1).timeout


func _test_heart_piece_accumulation() -> void:
	var player := _spawn_player(Vector2(500, 100))
	var start_max := player.max_hearts
	player.collect_item(ItemIds.HEART_PIECE, 4)
	_check("C 하트조각 4개 -> 최대 하트 +1", player.max_hearts == start_max + 1.0)
	_check("C 하트조각 4개 소모 -> 카운트 0", player.inventory.get_count(ItemIds.HEART_PIECE) == 0)
	_check("C 최대 하트 증가 -> 즉시 풀피", player.hearts == player.max_hearts)
	player.queue_free()


func _test_generic_item_stacking() -> void:
	var player := _spawn_player(Vector2(700, 100))
	player.collect_item(ItemIds.SMALL_KEY, 1)
	player.collect_item(ItemIds.SMALL_KEY, 1)
	_check("D 일반 아이템(열쇠) 누적", player.inventory.get_count(ItemIds.SMALL_KEY) == 2)
	player.queue_free()


func _print_summary() -> void:
	var summary := "=== M3 인벤토리+드랍 검증: PASS %d / FAIL %d ===" % [_pass_count, _fail_count]
	_log.append(summary)
	_refresh_label()
	print(summary)
	for line in _log:
		print(line)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _fail_count == 0 else 1)
