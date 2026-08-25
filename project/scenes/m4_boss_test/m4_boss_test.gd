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
	add_child(_dummy_player_at(Vector2(900, 250)))
	await get_tree().physics_frame
	await get_tree().create_timer(0.6).timeout

	_check("F 화염구 공격 -> 명중 대상 착화(엠버 패턴 재사용)", target.state == ChemTypes.State.BURNING)

	boss.queue_free()
	target.queue_free()
	await get_tree().create_timer(0.1).timeout


## ChaosCore가 플레이어 방향을 조준하려면 그룹 "player"에 뭔가 있어야 한다 -
## 실제 Player 대신 위치만 맞춘 더미로 충분(화염구 조준 대상 역할만 필요).
func _dummy_player_at(pos: Vector2) -> Node2D:
	var dummy := Node2D.new()
	dummy.global_position = pos
	dummy.add_to_group("player")
	return dummy


func _print_summary() -> void:
	var summary := "=== M4 보스(혼돈의 코어) 검증: PASS %d / FAIL %d ===" % [_pass_count, _fail_count]
	_log.append(summary)
	_refresh_label()
	print(summary)
	for line in _log:
		print(line)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _fail_count == 0 else 1)
