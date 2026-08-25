extends Node2D

## M1 검증 씬. PRD §2.4 필수 반응 6종을 순서대로 트리거하고 결과를 assert 스타일로 확인한다.
## 이 스크립트 자체가 "화학엔진이 제대로 동작하는가"에 대한 실행 가능한 체크다.

@onready var _label: Label = $DebugLabel

var _log: Array[String] = []
var _pass_count := 0
var _fail_count := 0


func _ready() -> void:
	await get_tree().process_frame
	await _run_all_tests()
	_print_summary()


func _spawn(mat: int, pos: Vector2, name_hint: String) -> ChemActor:
	var actor := ChemActor.new()
	actor.chem_material = mat
	actor.display_name = name_hint
	actor.position = pos
	add_child(actor)
	return actor


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


func _run_all_tests() -> void:
	# 1. 불 + 풀 -> 착화
	var fire_seed := _spawn(ChemTypes.MaterialTag.WOOD, Vector2(100, 100), "불씨")
	var grass := _spawn(ChemTypes.MaterialTag.GRASS, Vector2(130, 100), "풀")
	fire_seed.set_state(ChemTypes.State.BURNING)
	await get_tree().create_timer(0.2).timeout
	_check("① 불+풀 접촉 -> 풀 착화", grass.state == ChemTypes.State.BURNING)

	# 2. 불붙은 풀 -> 인접 풀 연쇄 (바람 방향 배치 연출)
	var grass2 := _spawn(ChemTypes.MaterialTag.GRASS, Vector2(160, 100), "풀2")
	await get_tree().create_timer(0.2).timeout
	_check("② 풀 연쇄 전파(바람 방향 배치)", grass2.state == ChemTypes.State.BURNING)

	# 3. 물 + 불붙음 -> 소화 + WET
	var water := _spawn(ChemTypes.MaterialTag.WATER, Vector2(300, 100), "물")
	var burning_wood := _spawn(ChemTypes.MaterialTag.WOOD, Vector2(330, 100), "타는나무")
	burning_wood.set_state(ChemTypes.State.BURNING)
	await get_tree().create_timer(0.2).timeout
	_check("③ 물+불 접촉 -> 소화 후 WET", burning_wood.state == ChemTypes.State.WET)

	# 3-1. 물 + 마른 대상(불 안 붙음) -> 그래도 WET (물+전기 콤보의 전제 조건)
	var dry_metal := _spawn(ChemTypes.MaterialTag.METAL, Vector2(400, 100), "마른금속")
	var water2 := _spawn(ChemTypes.MaterialTag.WATER, Vector2(430, 100), "물2")
	await get_tree().create_timer(0.2).timeout
	_check("③-1 물+마른 대상 접촉 -> WET 부여(불 안 붙어도)", dry_metal.state == ChemTypes.State.WET)

	# 4. 전기 + 금속 -> 전도
	var charged_metal := _spawn(ChemTypes.MaterialTag.METAL, Vector2(500, 100), "전도체")
	var metal2 := _spawn(ChemTypes.MaterialTag.METAL, Vector2(530, 100), "금속2")
	charged_metal.set_state(ChemTypes.State.CHARGED)
	await get_tree().create_timer(0.2).timeout
	_check("④ 전기+금속 접촉 -> 전도", metal2.state == ChemTypes.State.CHARGED)

	# 5. 전기(전도된 금속2) + 젖음 -> 감전
	var wet_target := _spawn(ChemTypes.MaterialTag.CLOTH, Vector2(560, 100), "젖은천")
	wet_target.set_state(ChemTypes.State.WET)
	var shocked_flag := {"v": false}
	wet_target.shocked.connect(func(): shocked_flag.v = true)
	await get_tree().create_timer(0.2).timeout
	_check("⑤ 전기+젖음 접촉 -> 감전 신호", shocked_flag.v)

	# 6. 불 + 얼음 -> 해빙
	var ice := _spawn(ChemTypes.MaterialTag.ICE, Vector2(700, 100), "얼음")
	ice.set_state(ChemTypes.State.FROZEN)
	var fire2 := _spawn(ChemTypes.MaterialTag.WOOD, Vector2(730, 100), "불2")
	fire2.set_state(ChemTypes.State.BURNING)
	await get_tree().create_timer(0.2).timeout
	_check("⑥ 불+얼음 접촉 -> FROZEN 해제", ice.state == ChemTypes.State.NONE)
	_check("⑥ 불+얼음 접촉 -> 물로 전환", ice.chem_material == ChemTypes.MaterialTag.WATER)


func _print_summary() -> void:
	var summary := "=== Chemistry Engine 검증: PASS %d / FAIL %d ===" % [_pass_count, _fail_count]
	_log.append(summary)
	_refresh_label()
	print(summary)
	for line in _log:
		print(line)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _fail_count == 0 else 1)
