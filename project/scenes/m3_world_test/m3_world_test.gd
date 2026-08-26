extends Node2D

## M3 우선순위1(월드 구조) 검증: 존 전환 시 카메라 limit 갱신, 수풀 베기/태우기
## 드랍 차이, 그리고 이번에 고친 "소각사망도 died 신호가 나가는지"까지 확인.

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


func _make_certain_table(item_id: String, count: int) -> DropTable:
	var table := DropTable.new()
	var entry := DropEntry.new()
	entry.item_id = item_id
	entry.chance = 1.0
	entry.min_count = count
	entry.max_count = count
	table.default_drops = [entry]
	return table


func _run_all_tests() -> void:
	await _test_zone_switch()
	await _test_grass_cut_drop()
	await _test_grass_burn_no_drop()
	await _test_combatant_burn_death_signal()
	await _test_vine_leash_fits_village_boundary()


func _test_zone_switch() -> void:
	var player := Player.new()
	player.global_position = Vector2(400, 300)
	add_child(player)
	var camera := Camera2D.new()
	player.add_child(camera)
	camera.make_current()

	var village := WorldZone.new()
	village.zone_name = "마을"
	village.bounds = Rect2(0, 0, 800, 600)
	var field := WorldZone.new()
	field.zone_name = "초원"
	field.bounds = Rect2(800, 0, 900, 700)

	var ctrl := ZoneCameraController.new()
	ctrl.zones = [village, field]
	add_child(ctrl)
	ctrl.setup(camera, player)

	await get_tree().process_frame
	_check("존A(마을) 진입 -> 카메라 limit 일치", camera.limit_left == 0 and camera.limit_right == 800)

	player.global_position = Vector2(850, 300)
	await get_tree().process_frame
	_check("존B(초원) 진입 -> 카메라 limit 갱신", camera.limit_left == 800 and camera.limit_right == 1700)

	player.queue_free()
	ctrl.queue_free()
	await get_tree().create_timer(0.1).timeout


func _test_grass_cut_drop() -> void:
	var player := Player.new()
	player.global_position = Vector2(100, 100)
	add_child(player)
	var grass := GrassPatch.new()
	grass.global_position = Vector2(100, 130)
	add_child(grass)
	# add_child 이후에 덮어써야 한다 - GrassPatch._ready()가 자기 기본 드랍표로
	# 다시 덮어쓰기 때문에 add_child 전에 설정하면 무시된다(실측 확인).
	grass.drop_table = _make_certain_table(ItemIds.ARROW, 2)
	await get_tree().physics_frame
	var before := player.inventory.get_count(ItemIds.ARROW)
	player.perform_melee_attack()
	await get_tree().create_timer(0.1).timeout
	_check("수풀 베기 -> 확정 드랍 지급", player.inventory.get_count(ItemIds.ARROW) == before + 2)
	_check("수풀 베기 -> 노드 제거", not is_instance_valid(grass))
	player.queue_free()
	await get_tree().create_timer(0.1).timeout


func _test_grass_burn_no_drop() -> void:
	var player := Player.new()
	player.global_position = Vector2(300, 100)
	add_child(player)
	var grass := GrassPatch.new()
	grass.global_position = Vector2(300, 130)
	add_child(grass)
	grass.drop_table = _make_certain_table(ItemIds.ARROW, 2)
	await get_tree().physics_frame
	var before := player.inventory.get_count(ItemIds.ARROW)
	grass.set_state(ChemTypes.State.BURNING)
	await get_tree().create_timer(0.6).timeout
	_check("수풀 태우기 -> 드랍 없음", player.inventory.get_count(ItemIds.ARROW) == before)
	player.queue_free()
	await get_tree().create_timer(0.1).timeout


func _test_combatant_burn_death_signal() -> void:
	var vine := VineEnemy.new()
	vine.global_position = Vector2(500, 100)
	vine.burn_duration = 0.2
	add_child(vine)
	var died_flag := {"v": false}
	vine.died.connect(func(): died_flag.v = true)
	vine.set_state(ChemTypes.State.BURNING)
	await get_tree().create_timer(0.4).timeout
	_check("몬스터가 불타 죽어도 died 신호 발생", died_flag.v)


## 실측 지적("몬스터가 마을로 들어옴") - world_test.gd 초원 덩굴이 스폰
## (x=1000)이 마을 경계(x=800)에서 200 떨어져 있는데, 목줄(leash_distance)이
## 그보다 크면(예전 기본값 300) 마을 안까지 새어 들어갈 수 있었다. 보스
## detect_radius를 두 번 재보정했던 것과 같은 부류의 실수라(한 씬 기준
## 숫자가 다른 씬엔 안 맞음) 매직넘버 대신 실제 기하 관계를 고정해둔다.
func _test_vine_leash_fits_village_boundary() -> void:
	var spawn_x := 1000.0  # world_test.gd sp1.position.x
	var village_edge_x := 800.0  # world_test.gd _village_bounds.end.x
	var vine := VineEnemy.new()
	_check("초원 덩굴이 목줄 -> 마을 경계까지 거리(200)보다 작음(마을 침입 방지)", vine.leash_distance < spawn_x - village_edge_x)
	vine.queue_free()


func _print_summary() -> void:
	var summary := "=== M3 월드구조 검증: PASS %d / FAIL %d ===" % [_pass_count, _fail_count]
	_log.append(summary)
	_refresh_label()
	print(summary)
	for line in _log:
		print(line)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _fail_count == 0 else 1)
