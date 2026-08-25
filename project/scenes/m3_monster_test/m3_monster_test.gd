extends Node2D

## M3 우선순위3(몬스터 3종) 검증: §4.1의 검증 축 그대로 확인.
## 우드가드=방패 화학반응(불에 타 소실->무방비), 엠버=화염구+물 즉사,
## 아이언셸=평소 공격무효->감전 스턴 중에만 피해.

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


func _spawn_player(pos: Vector2) -> Player:
	var p := Player.new()
	p.global_position = pos
	add_child(p)
	return p


func _spawn_chem(mat: int, pos: Vector2, name_hint: String) -> ChemActor:
	var a := ChemActor.new()
	a.chem_material = mat
	a.display_name = name_hint
	a.global_position = pos
	add_child(a)
	return a


func _run_all_tests() -> void:
	await _test_wood_guard_shield()
	await _test_ember_fireball_and_water()
	await _test_iron_shell_stun()


func _test_wood_guard_shield() -> void:
	var player := _spawn_player(Vector2(100, 100))
	# 우드가드도 이제 사거리 안에서 접촉 피해를 준다(실측 지적으로 추가) - 이 테스트는
	# 방패 화학반응만 검증하는 목적이라, 그 접촉 피해로 플레이어가 중간에 죽어버려
	# 이후 검증이 조용히 스킵되는 걸 막기 위해 넉넉히 채워둔다.
	player.max_hearts = 999.0
	player.hearts = 999.0
	var guard := WoodGuard.new()
	guard.global_position = Vector2(100, 130)
	add_child(guard)
	await get_tree().physics_frame

	player.perform_melee_attack()
	await get_tree().create_timer(0.1).timeout
	_check("A 방패 있는 우드가드 -> 근접 피해 무효", guard.hearts == guard.max_hearts)

	guard._shield.set_state(ChemTypes.State.BURNING)
	await get_tree().create_timer(2.3).timeout
	_check("A 방패 소각 -> 무기 소실 확인", guard._shield == null)

	player.perform_melee_attack()
	await get_tree().create_timer(0.1).timeout
	_check("A 방패 소실 후 -> 근접 피해 적용", guard.hearts < guard.max_hearts)

	player.queue_free()
	if is_instance_valid(guard):
		guard.queue_free()
	await get_tree().create_timer(0.1).timeout


func _test_ember_fireball_and_water() -> void:
	var ember := Ember.new()
	ember.global_position = Vector2(300, 100)
	add_child(ember)
	var target := Combatant.new()
	target.max_hearts = 5.0
	target.global_position = Vector2(300, 250)
	add_child(target)
	await get_tree().physics_frame

	ember._fire_at(Vector2.DOWN)
	await get_tree().create_timer(0.6).timeout
	_check("B 엠버 화염구 -> 명중 대상 피해", target.hearts < 5.0)
	_check("B 엠버 화염구 -> 명중 대상 착화(화학 재사용)", target.state == ChemTypes.State.BURNING)

	var water := _spawn_chem(ChemTypes.MaterialTag.WATER, Vector2(300, 105), "물")
	await get_tree().create_timer(0.2).timeout
	_check("B 엠버 물 접촉 -> 즉사", not is_instance_valid(ember))

	target.queue_free()
	if is_instance_valid(water):
		water.queue_free()
	await get_tree().create_timer(0.1).timeout


func _test_iron_shell_stun() -> void:
	var player := _spawn_player(Vector2(500, 100))
	var shell := IronShell.new()
	shell.global_position = Vector2(500, 130)
	add_child(shell)
	await get_tree().physics_frame

	player.perform_melee_attack()
	await get_tree().create_timer(0.1).timeout
	_check("C 평소 근접 공격 -> 무효(튕김)", shell.hearts == shell.max_hearts)

	# 실측 버그 재발 방지: shell.set_state(WET)로 직접 강제하면 반응표 경로를 안 타서
	# "마른 대상에 물을 던져도 반응표에 매치되는 규칙이 없어 WET이 안 됨" 버그를
	# 못 잡았다(실측 확인: "물+전기화살 했는데 안 죽음"). 실제 물 오브젝트 접촉으로 검증.
	var water := _spawn_chem(ChemTypes.MaterialTag.WATER, shell.global_position + Vector2(5, 0), "물")
	await get_tree().create_timer(0.1).timeout
	_check("C 물 접촉(실제 반응표 경로) -> WET 부여", shell.state == ChemTypes.State.WET)
	water.queue_free()

	var charged := _spawn_chem(ChemTypes.MaterialTag.METAL, shell.global_position, "전도체")
	charged.set_state(ChemTypes.State.CHARGED)
	await get_tree().create_timer(0.2).timeout
	_check("C 물+전기 콤보 -> 감전 스턴 진입", shell.is_stunned())

	player.perform_melee_attack()
	await get_tree().create_timer(0.1).timeout
	_check("C 스턴 중 근접 공격 -> 피해 적용", shell.hearts < shell.max_hearts)

	await get_tree().create_timer(3.0).timeout
	_check("C 스턴 시간 경과 -> 다시 무효화", not shell.is_stunned())

	if is_instance_valid(player):
		player.queue_free()
	if is_instance_valid(shell):
		shell.queue_free()
	if is_instance_valid(charged):
		charged.queue_free()
	await get_tree().create_timer(0.1).timeout


func _print_summary() -> void:
	var summary := "=== M3 몬스터3종 검증: PASS %d / FAIL %d ===" % [_pass_count, _fail_count]
	_log.append(summary)
	_refresh_label()
	print(summary)
	for line in _log:
		print(line)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _fail_count == 0 else 1)
