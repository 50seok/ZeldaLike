extends Node2D

## M3 우선순위6 검증: 던전(자물쇠-열쇠 Door) + 화학 퍼즐(PuzzleSwitch, 얼음 녹이기)
## + 보물상자(TreasureChest). 방 자체(카메라 전환)는 기존 WorldZone/ZoneCameraController
## 그대로 재사용이라(§4.2) 여기선 새로 만든 조각들만 검증한다.

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


func _run_all_tests() -> void:
	await _test_key_door()
	await _test_puzzle_gate_door()
	await _test_puzzle_switch()
	await _test_treasure_chest()
	await _test_ice_melt_puzzle_wiring()
	await _test_switch_unlocks_door_integration()
	await _test_relock_boss_room_door()


func _spawn_player(pos: Vector2) -> Player:
	var p := Player.new()
	p.global_position = pos
	add_child(p)
	return p


func _test_key_door() -> void:
	var player := _spawn_player(Vector2(0, 0))
	var door := Door.new()
	door.required_key = ItemIds.SMALL_KEY
	door.bounds = Rect2(-16, -40, 32, 80)
	door.global_position = Vector2(100, 0)
	add_child(door)
	await get_tree().physics_frame

	player.global_position = Vector2(100, 0)  # 문 안으로 들어가려 시도(열쇠 없음)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check("A 열쇠 없이 진입 시도 -> 밀려나서 문 안쪽에 안 남음", not door.bounds.has_point(player.global_position - door.global_position))
	_check("A 문은 여전히 잠김", door.locked)

	player.inventory.add(ItemIds.SMALL_KEY, 1)
	player.global_position = Vector2(100, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check("A 열쇠 있을 때 진입 -> 문 열림", not door.locked)
	_check("A 통과하며 열쇠 소모됨", player.inventory.get_count(ItemIds.SMALL_KEY) == 0)

	player.queue_free()
	door.queue_free()
	await get_tree().create_timer(0.1).timeout


func _test_puzzle_gate_door() -> void:
	var player := _spawn_player(Vector2(0, 200))
	var door := Door.new()
	door.bounds = Rect2(-16, -40, 32, 80)
	door.global_position = Vector2(300, 200)
	add_child(door)
	await get_tree().physics_frame

	player.global_position = Vector2(300, 200)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check("B 열쇠 없는 문(퍼즐게이트) -> 아이템으로는 안 열림, 여전히 잠김", door.locked)

	door.unlock()
	_check("B unlock() 외부 호출 -> 열림", not door.locked)

	player.queue_free()
	door.queue_free()
	await get_tree().create_timer(0.1).timeout


func _test_puzzle_switch() -> void:
	var switch := PuzzleSwitch.new()
	switch.global_position = Vector2(500, 0)
	add_child(switch)
	await get_tree().physics_frame

	var fired := {"count": 0}
	switch.activated.connect(func(): fired.count += 1)

	switch.set_state(ChemTypes.State.WET)
	_check("C WET로만은 활성화 안 됨", fired.count == 0)

	switch.set_state(ChemTypes.State.CHARGED)
	_check("C CHARGED -> 1회 활성화", fired.count == 1)

	switch.set_state(ChemTypes.State.NONE)
	switch.set_state(ChemTypes.State.CHARGED)
	_check("C 재충전해도 중복 발동 안 함(퍼즐은 한 번 풀면 끝)", fired.count == 1)

	switch.queue_free()
	await get_tree().create_timer(0.1).timeout


func _test_treasure_chest() -> void:
	var player := _spawn_player(Vector2(700, 0))
	var chest := TreasureChest.new()
	chest.item_id = ItemIds.HEART_PIECE
	chest.count = 1
	chest.global_position = Vector2(700, 0)
	add_child(chest)
	await get_tree().process_frame

	var before := player.inventory.get_count(ItemIds.HEART_PIECE)
	var ok1 := chest.open(player)
	_check("D 첫 개봉 -> 성공+아이템 지급", ok1 and player.inventory.get_count(ItemIds.HEART_PIECE) == before + 1)

	var ok2 := chest.open(player)
	_check("D 재개봉 -> 실패(이미 열림)", not ok2)

	player.queue_free()
	chest.queue_free()
	await get_tree().create_timer(0.1).timeout


## 퍼즐 예시 ③("얼음 녹여 스위치 누르기") - 별도 클래스가 아니라 던전 씬에서 그대로
## 연결할 배선(chem_state_changed + 재질 확인)이라, 그 배선 자체가 맞는지 확인.
func _test_ice_melt_puzzle_wiring() -> void:
	var door := Door.new()
	door.global_position = Vector2(900, 0)
	add_child(door)

	var ice := ChemActor.new()
	ice.chem_material = ChemTypes.MaterialTag.ICE
	ice.global_position = Vector2(950, 0)
	ice.state = ChemTypes.State.FROZEN
	add_child(ice)
	await get_tree().physics_frame

	# 던전 씬에서 실제로 쓸 배선과 동일 - 녹아서 WATER/NONE이 되는 순간 문을 연다.
	ice.chem_state_changed.connect(func(new_state):
		if new_state == ChemTypes.State.NONE and ice.chem_material == ChemTypes.MaterialTag.WATER:
			door.unlock()
	)

	var fire := ChemActor.new()
	fire.chem_material = ChemTypes.MaterialTag.WOOD
	fire.global_position = Vector2(960, 0)
	add_child(fire)
	await get_tree().physics_frame
	fire.set_state(ChemTypes.State.BURNING)
	await get_tree().create_timer(0.2).timeout

	_check("E 얼음 접촉 -> 녹아서 물로 전환(반응표 재사용)", ice.chem_material == ChemTypes.MaterialTag.WATER)
	_check("E 얼음 녹임 -> 배선을 통해 문이 열림", not door.locked)

	door.queue_free()
	ice.queue_free()
	fire.queue_free()
	await get_tree().create_timer(0.1).timeout


## 퍼즐 예시 ②("물 뿌려 전기 회로 연결") 전체 통합 - 스위치가 실제로 문을 여는지.
func _test_switch_unlocks_door_integration() -> void:
	var door := Door.new()
	door.global_position = Vector2(1100, 0)
	add_child(door)

	var switch := PuzzleSwitch.new()
	switch.global_position = Vector2(1150, 0)
	add_child(switch)
	switch.activated.connect(door.unlock)
	await get_tree().physics_frame

	var conductor := ChemActor.new()
	conductor.chem_material = ChemTypes.MaterialTag.METAL
	conductor.global_position = Vector2(1160, 0)
	add_child(conductor)
	await get_tree().physics_frame
	conductor.set_state(ChemTypes.State.CHARGED)
	await get_tree().create_timer(0.2).timeout

	_check("F 스위치 전도(화학엔진) -> 활성화 -> 문 열림", not door.locked)

	door.queue_free()
	switch.queue_free()
	conductor.queue_free()
	await get_tree().create_timer(0.1).timeout


## §4.1 보스 방 관례("들어가면 격파 전까지 못 나감") - 실측 지적으로 추가된
## Door.lock(). 이미 열쇠로 한 번 열렸던 문(키 소모됨)도 다시 잠기고, 다시
## 밀어내는지 확인한다.
func _test_relock_boss_room_door() -> void:
	var player := Player.new()
	player.global_position = Vector2(1300, 100)
	add_child(player)

	var door := Door.new()
	door.required_key = ItemIds.BOSS_KEY
	door.global_position = Vector2(1300, 200)
	add_child(door)
	player.inventory.add(ItemIds.BOSS_KEY, 1)
	await get_tree().physics_frame

	player.global_position = Vector2(1300, 200)  # 열쇠로 최초 통과
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check("G 열쇠로 최초 통과 -> 문 열림+열쇠 소모", not door.locked and player.inventory.get_count(ItemIds.BOSS_KEY) == 0)

	player.global_position = Vector2(1400, 200)  # 문을 지나 반대편으로 이동
	door.lock()
	_check("G lock() 재호출 -> 다시 잠김(소모된 열쇠와 무관)", door.locked)

	player.global_position = Vector2(1300, 200)  # 다시 문으로 접근(나가려는 시도)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check("G 재잠금 후 -> 열쇠 없어 못 나가고 밀려남", door.locked and not door.bounds.has_point(player.global_position - door.global_position))

	player.queue_free()
	door.queue_free()
	await get_tree().create_timer(0.1).timeout


func _print_summary() -> void:
	var summary := "=== M3 던전(자물쇠-열쇠/퍼즐/보물상자) 검증: PASS %d / FAIL %d ===" % [_pass_count, _fail_count]
	_log.append(summary)
	_refresh_label()
	print(summary)
	for line in _log:
		print(line)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _fail_count == 0 else 1)
