extends Node2D

## M4 우선순위1 검증: 보스 "혼돈의 코어"(§3.5/§4.1). 스턴 격파 루프(물+전기 콤보
## → 감전 스턴 → 스턴 중 공격 1회 = 페이즈 진행) 3회 반복 격파, 페이즈2 소환,
## 화염구 탄막을 확인한다.

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


func _spawn_chem(mat: int, pos: Vector2, name_hint: String) -> ChemActor:
	var a := ChemActor.new()
	a.chem_material = mat
	a.display_name = name_hint
	a.global_position = pos
	add_child(a)
	return a


func _run_all_tests() -> void:
	await _test_full_defeat_loop()
	await _test_fireball_attack()
	await _test_out_of_range_does_not_attack()
	await _test_detect_radius_fits_dungeon_room_size()


## 콤보 3회(물+전기 스턴 → 공격 1회) 전체 흐름을 하나로 이어서 확인 -
## 스턴당 1회만 유효한지, 페이즈2 소환, 최종 격파까지.
func _test_full_defeat_loop() -> void:
	var boss := ChaosCore.new()
	boss.global_position = Vector2(500, 500)
	add_child(boss)
	await get_tree().physics_frame

	boss.take_damage(1.0)
	_check("A 평소(스턴 안 됨) -> 공격 무효", boss.hit_count == 0)

	# 1차 콤보 -> 페이즈2 진입 + 덩굴이 2마리 소환
	var enemies_before := get_tree().get_nodes_in_group("combatant_enemies").size()
	boss.set_state(ChemTypes.State.WET)
	var conductor1 := _spawn_chem(ChemTypes.MaterialTag.METAL, boss.global_position, "전도체1")
	conductor1.set_state(ChemTypes.State.CHARGED)
	await get_tree().create_timer(0.2).timeout
	_check("B 물+전기 콤보 -> 스턴 진입", boss.is_stunned())

	boss.take_damage(1.0)
	_check("B 스턴 중 공격 -> hit_count 1, 페이즈2 진입", boss.hit_count == 1 and boss.phase == ChaosCore.Phase.TWO)
	_check("B 페이즈2 진입 -> 덩굴이 2마리 소환", get_tree().get_nodes_in_group("combatant_enemies").size() == enemies_before + 2)

	boss.take_damage(1.0)
	_check("C 같은 스턴 윈도우 2번째 공격 -> 무효(스턴 이미 소모)", boss.hit_count == 1)

	conductor1.queue_free()
	await get_tree().create_timer(0.1).timeout

	# 2차 콤보 -> 페이즈3 진입 (재감전 필요 - 이전 스턴은 이미 소모됨)
	boss.set_state(ChemTypes.State.WET)
	var conductor2 := _spawn_chem(ChemTypes.MaterialTag.METAL, boss.global_position, "전도체2")
	conductor2.set_state(ChemTypes.State.CHARGED)
	await get_tree().create_timer(0.2).timeout
	_check("D 재감전 -> 다시 스턴 진입", boss.is_stunned())

	boss.take_damage(1.0)
	_check("D 2차 타격 -> hit_count 2, 페이즈3 진입", boss.hit_count == 2 and boss.phase == ChaosCore.Phase.THREE)

	conductor2.queue_free()
	await get_tree().create_timer(0.1).timeout

	# 3차 콤보 -> 격파
	var defeated_flag := {"v": false}
	boss.defeated.connect(func(): defeated_flag.v = true)
	boss.set_state(ChemTypes.State.WET)
	var conductor3 := _spawn_chem(ChemTypes.MaterialTag.METAL, boss.global_position, "전도체3")
	conductor3.set_state(ChemTypes.State.CHARGED)
	await get_tree().create_timer(0.2).timeout
	boss.take_damage(1.0)
	await get_tree().physics_frame
	_check("E 3차 타격 -> 격파(defeated 신호+인스턴스 제거)", defeated_flag.v and not is_instance_valid(boss))

	conductor3.queue_free()
	await get_tree().create_timer(0.1).timeout


func _test_fireball_attack() -> void:
	var boss := ChaosCore.new()
	boss.global_position = Vector2(900, 100)
	boss.fireball_cooldown = 0.1
	add_child(boss)

	var target := Combatant.new()
	target.chem_material = ChemTypes.MaterialTag.CLOTH
	target.max_hearts = 5.0
	target.global_position = Vector2(900, 250)
	add_child(target)
	# 그룹 "player"에 계속 남아있으면 이후 테스트(G)의 보스가 이 더미를 먼저
	# 찾아버려서 반드시 정리해야 한다(실측 확인 - G가 원인불명으로 계속 실패).
	var dummy_player := _dummy_player_at(Vector2(900, 250))
	add_child(dummy_player)
	await get_tree().physics_frame
	await get_tree().create_timer(0.6).timeout

	_check("F 화염구 공격 -> 명중 대상 착화(엠버 패턴 재사용)", target.state == ChemTypes.State.BURNING)

	boss.queue_free()
	target.queue_free()
	dummy_player.queue_free()
	_clear_fireballs()  # 0.6초 내내 쐈으니 아직 아무것도 못 맞히고 날아다니는 화염구가 남을 수 있음
	await get_tree().create_timer(0.1).timeout


## ChaosCore가 플레이어 방향을 조준하려면 그룹 "player"에 뭔가 있어야 한다 -
## 실제 Player 대신 위치만 맞춘 더미로 충분(화염구 조준 대상 역할만 필요).
func _clear_fireballs() -> void:
	for child in get_children():
		if child is Arrow:
			child.queue_free()


func _dummy_player_at(pos: Vector2) -> Node2D:
	var dummy := Node2D.new()
	dummy.global_position = pos
	dummy.add_to_group("player")
	return dummy


## 실측 지적("던전 다른 방에 있는데 보스 화염구에 맞음") 재발 방지 - "방"이
## 실제 벽이 아니라 카메라 존일 뿐이라, 감지 범위 없이는 보스가 몇 개 방
## 떨어진 플레이어도 계속 조준+사격했다. detect_radius 밖이면 추적도 사격도
## 안 해야 한다.
func _test_out_of_range_does_not_attack() -> void:
	var boss := ChaosCore.new()
	boss.global_position = Vector2(1300, 100)
	boss.fireball_cooldown = 0.05
	add_child(boss)

	var far_player := _dummy_player_at(Vector2(1300 + boss.detect_radius + 200, 100))
	add_child(far_player)
	await get_tree().physics_frame
	var pos_before := boss.global_position
	await get_tree().create_timer(0.3).timeout

	_check("G 감지 범위 밖 -> 추적 안 함", boss.global_position.is_equal_approx(pos_before))
	# _fire_at()은 항상 get_parent().add_child(fireball)이라, 보스의 부모(=이 테스트
	# 씬 자신)의 자식 목록에서 화염구(Arrow) 생성 여부를 직접 확인한다.
	var fireballs := get_children().filter(func(n): return n is Arrow)
	_check("G 감지 범위 밖 -> 화염구도 안 쏨", fireballs.is_empty())

	boss.queue_free()
	far_player.queue_free()
	await get_tree().create_timer(0.1).timeout


## 실측 재발("문 고치니 다시 옆방 몬스터가 공격함") 방지 - detect_radius 값
## 자체가 dungeon_test.tscn의 실제 보스방 크기(800x600, 보스는 방 정중앙)보다
## 커서 옆방까지 새던 문제였다. 그 정확한 기하 조건을 재현해 고정한다:
## 방 정중앙에 있는 보스 기준, 옆방과 맞닿은 벽(중앙에서 400 거리) 바로
## 너머는 반드시 범위 밖이어야 한다.
func _test_detect_radius_fits_dungeon_room_size() -> void:
	var room_half_width := 400.0  # dungeon_test.tscn 보스방(800 폭)의 절반 - 보스는 방 정중앙에 있음
	var boss := ChaosCore.new()
	boss.global_position = Vector2(2000, 300)
	boss.fireball_cooldown = 0.05
	add_child(boss)

	# 옆방으로 살짝 넘어간 위치(벽+20) - 여기선 절대 반응하면 안 된다.
	var next_room_player := _dummy_player_at(boss.global_position + Vector2(room_half_width + 20, 0))
	add_child(next_room_player)
	await get_tree().physics_frame
	await get_tree().create_timer(0.2).timeout

	_check("H detect_radius < 방 절반거리(400) - 옆방 침범 안 함", boss.detect_radius < room_half_width)
	var fireballs := get_children().filter(func(n): return n is Arrow)
	_check("H 옆방으로 넘어간 위치 -> 화염구 안 날아옴", fireballs.is_empty())

	boss.queue_free()
	next_room_player.queue_free()
	_clear_fireballs()
	await get_tree().create_timer(0.1).timeout


func _print_summary() -> void:
	var summary := "=== M4 보스(혼돈의 코어) 검증: PASS %d / FAIL %d ===" % [_pass_count, _fail_count]
	_log.append(summary)
	_refresh_label()
	print(summary)
	for line in _log:
		print(line)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _fail_count == 0 else 1)
