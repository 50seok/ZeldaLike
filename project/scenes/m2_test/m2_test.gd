extends Node2D

## M2 검증 씬. PRD M2 완료 기준 "무기 재질별 화학 반응 포함 전투 1판 성립"을
## 실제 입력 없이 메서드 직접 호출로 재현해 assert 스타일로 확인한다.
## 실제 조작감(반응성)은 이 스크립트로 검증 못 하므로, 에디터에서 수동 플레이도 별도로 해볼 것.

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


func _spawn_vine(pos: Vector2) -> VineEnemy:
	var v := VineEnemy.new()
	v.global_position = pos
	add_child(v)
	return v


func _spawn_chem(mat: int, pos: Vector2, name_hint: String) -> ChemActor:
	var a := ChemActor.new()
	a.chem_material = mat
	a.display_name = name_hint
	a.global_position = pos
	add_child(a)
	return a


func _run_all_tests() -> void:
	await _test_melee()
	await _test_bow_normal()
	await _test_bow_fire()
	await _test_weapon_chemistry()
	await _test_shield()
	await _test_pickup_throw()
	await _test_fire_right_self_safety()
	await _test_burn_is_damage_over_time()


func _test_melee() -> void:
	var player := _spawn_player(Vector2(100, 100))
	var vine := _spawn_vine(Vector2(100, 130))
	await get_tree().physics_frame
	player.perform_melee_attack()
	_check("A 근접공격(칼) -> 덩굴이 사망", vine.hearts <= 0.0)
	player.queue_free()
	vine.queue_free()
	await get_tree().create_timer(0.1).timeout


func _test_bow_normal() -> void:
	var player := _spawn_player(Vector2(300, 100))
	var vine := _spawn_vine(Vector2(300, 250))
	vine.max_hearts = 5.0
	vine.hearts = 5.0
	await get_tree().physics_frame
	player.perform_bow_attack()
	await get_tree().create_timer(0.6).timeout
	_check("B 활(일반 화살) -> 원거리 피해", vine.hearts < 5.0)
	player.queue_free()
	if is_instance_valid(vine):
		vine.queue_free()
	await get_tree().create_timer(0.1).timeout


func _test_bow_fire() -> void:
	var player := _spawn_player(Vector2(500, 100))
	var vine := _spawn_vine(Vector2(500, 250))
	vine.max_hearts = 5.0
	vine.hearts = 5.0
	player.cycle_tool()
	await get_tree().physics_frame
	player.perform_bow_attack()
	await get_tree().create_timer(0.6).timeout
	_check("C 불화살(도구) -> 착화(화학+전투 결합)", vine.state == ChemTypes.State.BURNING)
	player.queue_free()
	if is_instance_valid(vine):
		vine.queue_free()
	await get_tree().create_timer(0.1).timeout


func _test_weapon_chemistry() -> void:
	var player := _spawn_player(Vector2(700, 100))
	await get_tree().physics_frame
	var weapon_gone := {"v": false}
	player._equipped_weapon.weapon_destroyed.connect(func(): weapon_gone.v = true)
	var campfire := _spawn_chem(ChemTypes.MaterialTag.WOOD, player.global_position + Vector2(16, 0), "화톳불")
	campfire.set_state(ChemTypes.State.BURNING)
	await get_tree().create_timer(2.2).timeout
	_check("D 나무 검(장착무기) 불 노출 -> 무기 소실", weapon_gone.v)
	player.queue_free()
	if is_instance_valid(campfire):
		campfire.queue_free()
	await get_tree().create_timer(0.1).timeout


func _test_shield() -> void:
	var player := _spawn_player(Vector2(900, 100))
	await get_tree().physics_frame
	var before := player.hearts
	player.take_damage(1.0)
	var no_shield_loss := before - player.hearts
	player.toggle_shield()
	var before2 := player.hearts
	player.take_damage(1.0)
	var shield_loss := before2 - player.hearts
	_check("E 방패 활성화 -> 피해 절반", is_equal_approx(shield_loss, no_shield_loss * 0.5))
	player.queue_free()
	await get_tree().create_timer(0.1).timeout


func _test_pickup_throw() -> void:
	var player := _spawn_player(Vector2(1100, 100))
	var jar := Throwable.new()
	jar.chem_material = ChemTypes.MaterialTag.WATER
	jar.display_name = "물항아리"
	jar.global_position = player.global_position
	add_child(jar)
	await get_tree().create_timer(0.1).timeout

	player.interact_or_throw()  # 줍기
	await get_tree().create_timer(0.1).timeout
	var picked_up := player._held_item == jar

	player.facing = Vector2.RIGHT
	player.interact_or_throw()  # 던지기
	var target := _spawn_chem(ChemTypes.MaterialTag.WOOD, player.global_position + Vector2(120, 0), "타는장애물")
	target.set_state(ChemTypes.State.BURNING)
	await get_tree().create_timer(0.6).timeout

	_check("F 집기 -> 물항아리 획득", picked_up)
	_check("F 던지기 -> 명중 시 소화(WET)", target.state == ChemTypes.State.WET)
	player.queue_free()
	if is_instance_valid(target):
		target.queue_free()
	await get_tree().create_timer(0.1).timeout


func _test_fire_right_self_safety() -> void:
	# 오른쪽으로 쏘면 장착무기(플레이어 로컬 +16,0)와 화살 경로가 거의 겹친다 —
	# 실제 수동 플레이에서 이 방향으로 쐈을 때만 발사자가 죽는 버그가 나왔었다.
	var player := _spawn_player(Vector2(1300, 100))
	player.facing = Vector2.RIGHT
	player.cycle_tool()
	var vine := _spawn_vine(Vector2(1450, 100))
	vine.max_hearts = 5.0
	vine.hearts = 5.0
	await get_tree().physics_frame
	player.perform_bow_attack()
	await get_tree().create_timer(0.6).timeout
	_check("G 오른쪽 불화살 -> 발사자 생존", is_instance_valid(player) and player.hearts > 0.0)
	_check("G 오른쪽 불화살 -> 장착무기 무사", is_instance_valid(player) and player._equipped_weapon != null)
	_check("G 오른쪽 불화살 -> 대상 명중(착화)", is_instance_valid(vine) and vine.state == ChemTypes.State.BURNING)
	if is_instance_valid(player):
		player.queue_free()
	if is_instance_valid(vine):
		vine.queue_free()
	await get_tree().create_timer(0.1).timeout


## 실측 지적("불탔을때 대미지가 너무 강함, 무조건 죽는게 하드함") 재발 방지 -
## 하트가 있는 일반 Combatant는 불붙어도 즉사가 아니라 하트를 깎는 지속피해여야
## 한다(§4.1 "덩굴이"만 예외로 즉시 소멸 - burn_kills_instantly).
func _test_burn_is_damage_over_time() -> void:
	var target := Combatant.new()
	target.chem_material = ChemTypes.MaterialTag.CLOTH  # Player와 동일 재질
	target.max_hearts = 5.0
	target.global_position = Vector2(1600, 100)
	add_child(target)
	await get_tree().physics_frame

	target.set_state(ChemTypes.State.BURNING)
	await get_tree().create_timer(1.2).timeout  # 기본 tick 간격(1초) 최소 1회 경과
	_check("H 불붙음 -> 하트 수와 무관한 즉사 아님(생존)", is_instance_valid(target) and target.hearts > 0.0)
	_check("H 불붙음 -> 틱 데미지가 실제로 들어감", is_instance_valid(target) and target.hearts < 5.0)

	await get_tree().create_timer(2.0).timeout  # burn_duration(2.5초) 경과 - 다 타면 꺼지기만 해야 함
	_check("H 다 타면 -> 하트 남아있으면 파괴 안 되고 생존", is_instance_valid(target))
	if is_instance_valid(target):
		_check("H 다 타면 -> 상태만 꺼짐(NONE)", target.state == ChemTypes.State.NONE)

	if is_instance_valid(target):
		target.queue_free()
	await get_tree().create_timer(0.1).timeout


func _print_summary() -> void:
	var summary := "=== M2 전투+화학 검증: PASS %d / FAIL %d ===" % [_pass_count, _fail_count]
	_log.append(summary)
	_refresh_label()
	print(summary)
	for line in _log:
		print(line)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _fail_count == 0 else 1)
