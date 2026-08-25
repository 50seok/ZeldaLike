extends Node2D

## 수동 플레이용 — 우선순위6(던전+퍼즐+비밀장소, §4) 최소 구현.
## 방 5개(입구→퍼즐방→전기스위치방→보스열쇠방→보스방 placeholder) + 비밀 방 1개.
## 방 전환 카메라는 새로 안 만들고 기존 WorldZone/ZoneCameraController를 그대로
## 재사용한다(방 크기를 화면 크기에 맞춰 배치하면 "방 단위 전환"처럼 보임).
##
## 조작은 world_test.tscn과 동일: Z 칼 · X 활 · Space 줍기/던지기/대화/상자 열기 ·
## V 내려놓기 · Tab 화살속성 전환.

var _player: Player
var _zone_ctrl: ZoneCameraController
var _status_label: Label
var _log_label: Label
var _log_lines: Array[String] = []

var _room_a := Rect2(0, 0, 800, 600)      # 입구 - 마른 수풀이 길을 막음
var _room_b := Rect2(800, 0, 800, 600)    # 작은 열쇠 방
var _room_c := Rect2(1600, 0, 800, 600)   # 전기 스위치 + 얼음 비밀통로
var _room_d := Rect2(2400, 0, 800, 600)   # 보스 열쇠 방
var _room_boss := Rect2(3200, 0, 800, 600) # 보스 방(placeholder, M4 스코프)
var _room_secret := Rect2(1600, 600, 800, 600) # 비밀 방(하트조각)

## world_test.gd와 동일한 이유 - 카메라 존 경계만으로는 플레이어 자신의 이동을
## 못 막아서 화면 밖으로 무한히 걸어나갈 수 있었다(실측 지적). 전체 방 사각형을
## 감싸는 경계로 이동을 막는다.
var _world_bounds: Rect2


func _draw() -> void:
	draw_rect(_room_a, Color(0.2, 0.18, 0.1))
	draw_rect(_room_b, Color(0.18, 0.2, 0.14))
	draw_rect(_room_c, Color(0.14, 0.18, 0.22))
	draw_rect(_room_d, Color(0.22, 0.16, 0.1))
	draw_rect(_room_boss, Color(0.25, 0.08, 0.08))
	draw_rect(_room_secret, Color(0.25, 0.2, 0.05))


func _ready() -> void:
	_player = Player.new()
	_player.global_position = Vector2(400, 300)
	add_child(_player)

	var camera := Camera2D.new()
	camera.zoom = Vector2(1.3, 1.3)
	_player.add_child(camera)
	camera.make_current()

	var ui := CanvasLayer.new()
	add_child(ui)

	var help := Label.new()
	help.position = Vector2(20, 20)
	help.add_theme_font_size_override("font_size", 16)
	help.text = "방향키 이동 · Z 칼(수풀도 벨 수 있음) · X 활 · Space 줍기/던지기/상자 열기/대화(대화 중엔 다음 줄) · V 내려놓기 · Tab 화살속성 전환\n입구(수풀 태우기, 석판1)->작은열쇠방(석판2)->전기스위치방(얼음 녹이면 남쪽 비밀방=정령)->보스열쇠방(석판3)->보스방(혼돈의 코어, 물+전기 콤보로 스턴시킨 뒤 칼로 3회)"
	ui.add_child(help)

	_status_label = Label.new()
	_status_label.position = Vector2(20, 70)
	_status_label.add_theme_font_size_override("font_size", 16)
	ui.add_child(_status_label)

	_log_label = Label.new()
	_log_label.position = Vector2(20, 100)
	_log_label.add_theme_font_size_override("font_size", 14)
	_log_label.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	ui.add_child(_log_label)

	var hotbar := Hotbar.new()
	hotbar.position = Vector2(20, 210)
	hotbar.player = _player
	ui.add_child(hotbar)

	ui.add_child(PauseMenu.new())

	var dialogue_box := DialogueBox.new()
	ui.add_child(dialogue_box)
	dialogue_box.add_to_group("dialogue_box")

	_player.did_attack.connect(func(kind): _log("플레이어 %s 공격!" % kind))
	_player.damaged.connect(func(amount): _log("플레이어 피격 -%.1f" % amount))
	_player.died.connect(func():
		_log("플레이어 사망... 2초 후 재시작")
		await get_tree().create_timer(2.0).timeout
		get_tree().reload_current_scene()
	)
	_player.item_collected.connect(func(item_id, count): _log("%s 획득! (+%d)" % [_item_display_name(item_id), count]))
	_player.did_interact.connect(func(result): _log("Space -> %s" % result))

	var zones: Array[WorldZone] = []
	for entry in [
		["입구", _room_a], ["작은 열쇠 방", _room_b], ["전기 스위치 방", _room_c],
		["보스 열쇠 방", _room_d], ["보스 방", _room_boss], ["비밀 방", _room_secret],
	]:
		var zone := WorldZone.new()
		zone.zone_name = entry[0]
		zone.bounds = entry[1]
		zones.append(zone)

	_zone_ctrl = ZoneCameraController.new()
	_zone_ctrl.zones = zones
	add_child(_zone_ctrl)
	_zone_ctrl.setup(camera, _player)
	_world_bounds = _room_a.merge(_room_b).merge(_room_c).merge(_room_d).merge(_room_boss).merge(_room_secret)
	_zone_ctrl.zone_changed.connect(func(zone):
		_log("%s 진입" % (zone.zone_name if zone else "경계 밖"))
		SaveManager.save_game(_player)
	)

	# world_test.tscn과 동일한 이어하기 방식 - 저장이 있으면(월드에서 넘어왔거나
	# 타이틀 "이어하기"로 던전 도중부터 시작하는 경우) 여기서 상태를 덮어쓴다.
	if SaveManager.has_save():
		SaveManager.load_game(_player)
		_log("저장된 게임을 이어서 불러왔습니다")

	# 퍼즐 ① - 입구를 막은 마른 수풀. 베거나 태우면 사라져 다음 방으로 갈 수 있다.
	var blockage := GrassPatch.new()
	blockage.global_position = Vector2(790, 300)
	add_child(blockage)

	# 작은 열쇠 방 - 상자에서 열쇠를 얻어 다음 방 문을 연다.
	var key_chest := TreasureChest.new()
	key_chest.item_id = ItemIds.SMALL_KEY
	key_chest.count = 1
	key_chest.global_position = Vector2(1000, 300)
	add_child(key_chest)

	var key_door := Door.new()
	key_door.required_key = ItemIds.SMALL_KEY
	key_door.global_position = Vector2(1595, 300)
	add_child(key_door)

	# 전기 스위치 방 - 퍼즐 ②("전기 회로 연결"). 스위치를 전기로 충전하면
	# 보스 열쇠 방으로 가는 문이 열린다.
	var switch := PuzzleSwitch.new()
	switch.global_position = Vector2(1900, 200)
	add_child(switch)

	var switch_door := Door.new()
	switch_door.global_position = Vector2(2395, 300)
	add_child(switch_door)
	switch.activated.connect(func():
		switch_door.unlock()
		_log("스위치 활성화 -> 문 열림")
	)

	# 얼음 비밀통로 - 퍼즐 ③("얼음 녹이기"). 녹이면 남쪽 비밀 방으로 가는
	# 문이 열린다(비밀 장소, §4 - 하트조각 보상).
	var ice_block := ChemActor.new()
	ice_block.chem_material = ChemTypes.MaterialTag.ICE
	ice_block.display_name = "얼음 벽"
	ice_block.global_position = Vector2(1900, 550)
	add_child(ice_block)
	ice_block.set_state(ChemTypes.State.FROZEN)

	var secret_door := Door.new()
	secret_door.global_position = Vector2(1900, 600)
	add_child(secret_door)
	ice_block.chem_state_changed.connect(func(new_state):
		if new_state == ChemTypes.State.NONE and ice_block.chem_material == ChemTypes.MaterialTag.WATER:
			secret_door.unlock()
			_log("얼음이 녹아 비밀 통로가 열렸다!")
	)

	var secret_chest := TreasureChest.new()
	secret_chest.item_id = ItemIds.HEART_PIECE
	secret_chest.count = 1
	secret_chest.global_position = Vector2(1900, 850)
	add_child(secret_chest)

	# 보스 열쇠 방 - 보스 방으로 가는 마지막 문.
	var boss_key_chest := TreasureChest.new()
	boss_key_chest.item_id = ItemIds.BOSS_KEY
	boss_key_chest.count = 1
	boss_key_chest.global_position = Vector2(2600, 300)
	add_child(boss_key_chest)

	var boss_door := Door.new()
	boss_door.required_key = ItemIds.BOSS_KEY
	boss_door.global_position = Vector2(3195, 300)
	add_child(boss_door)

	# 보스 방 - boss_test.tscn에서 검증한 그대로: 보스 + 물웅덩이 2곳(항아리 리필,
	# §4.1 "보스 방 고정 배치"). 격파되면 엔딩으로 넘어간다.
	var boss := ChaosCore.new()
	boss.global_position = Vector2(3600, 300)
	add_child(boss)
	boss.phase_changed.connect(func(new_phase):
		var phase_names := {ChaosCore.Phase.TWO: "2(얼음+덩굴이 소환)", ChaosCore.Phase.THREE: "3(속도+탄막 증가)"}
		_log("혼돈의 코어 -> 페이즈 %s 돌입!" % phase_names.get(new_phase, str(new_phase)))
	)
	boss.defeated.connect(func():
		_log("혼돈의 코어 격파! 승리!")
		get_tree().change_scene_to_file("res://scenes/ending/ending.tscn")
	)

	var boss_jar_sp1 := SpawnPoint.new()
	boss_jar_sp1.entity_type = "water_jar"
	boss_jar_sp1.respawn_sec = 5.0
	boss_jar_sp1.position = Vector2(3300, 500)
	add_child(boss_jar_sp1)
	var boss_jar_sp2 := SpawnPoint.new()
	boss_jar_sp2.entity_type = "water_jar"
	boss_jar_sp2.respawn_sec = 5.0
	boss_jar_sp2.position = Vector2(3850, 500)
	add_child(boss_jar_sp2)

	var boss_item_mgr := FieldSpawnManager.new()
	boss_item_mgr.spawn_points = [boss_jar_sp1, boss_jar_sp2]
	boss_item_mgr.field_cap = 2
	add_child(boss_item_mgr)
	boss_item_mgr.setup(camera)

	# 우선순위4 - 석판(§3.5 유적 내력) + 정령 구출. 기존 NPC/대화 시스템을 그대로
	# 재사용한다(석판=대사만 있는 NPC, 정령=sets_flag가 있는 NPC) - 새 시스템 없음.
	var tablet1 := StoneTablet.new()
	tablet1.npc_name = "석판 1"
	tablet1.lines = ["이 유적은 오래 전, 연금술사들이 네 원소의 폭주를 막기 위해 세운 봉인이었다."]
	tablet1.global_position = Vector2(200, 450)
	add_child(tablet1)

	var tablet2 := StoneTablet.new()
	tablet2.npc_name = "석판 2"
	tablet2.lines = ["원소는 본디 자유로웠으나, 다스릴 줄 모르는 자들의 손에서 마을을 몇 번이고 집어삼켰다."]
	tablet2.global_position = Vector2(1100, 450)
	add_child(tablet2)

	var tablet3 := StoneTablet.new()
	tablet3.npc_name = "석판 3"
	tablet3.lines = ["그리하여 선조들은 원소를 이곳 깊은 곳에 가두고, 조화를 지킬 자가 나타나기를 기다렸다."]
	tablet3.global_position = Vector2(2700, 450)
	add_child(tablet3)

	# §3.5 "중간에 갇힌 원소 정령을 구출(플래그②)하면 정령이 보스의 약점을
	# 알려주고 보스 방이 열림". 얼음 녹이기 비밀 방(이미 있는 화학 퍼즐)에
	# 갇혀 있던 걸로 자연스럽게 배치 - 새 잠금 기믹을 또 안 만들어도 됨.
	var spirit := NPC.new()
	spirit.npc_name = "원소 정령"
	spirit.lines = [
		"...누구냐...",
		"오랫동안 갇혀 있었다. 네가 나를 자유롭게 해주었구나.",
		"혼돈의 코어는 강해 보이나, 어떤 원소도 무적은 아니다. 서로 다른 힘이 만나면 반드시 틈이 생기지.",
		"가라, 견습 연금술사여. 균형을 되찾아다오.",
	]
	spirit.sets_flag = "spirit_rescued"
	spirit.global_position = Vector2(2100, 850)
	add_child(spirit)

	# 정령을 구출하면 보스 열쇠와 별개로도 보스 방이 열린다(§3.5 그대로) - 이미
	# 만들어둔 boss_door.unlock()을 재사용, Door는 둘 중 뭐가 먼저 오든 안전
	# (한 번 열리면 unlock()이 멱등).
	StoryFlags.flag_changed.connect(func(flag_name):
		if flag_name == "spirit_rescued":
			boss_door.unlock()
			_log("정령이 자유로워졌다 - 보스 방이 열렸다!")
	)


func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		return
	_player.global_position.x = clamp(_player.global_position.x, _world_bounds.position.x, _world_bounds.end.x)
	_player.global_position.y = clamp(_player.global_position.y, _world_bounds.position.y, _world_bounds.end.y)

	var zone_name := _zone_ctrl.current_zone.zone_name if _zone_ctrl.current_zone else "?"
	_status_label.text = "현재 구역: %s | 하트: %.1f/%.1f" % [zone_name, _player.hearts, _player.max_hearts]


func _item_display_name(item_id: String) -> String:
	match item_id:
		ItemIds.HEART: return "하트"
		ItemIds.ARROW: return "화살"
		ItemIds.SMALL_KEY: return "작은 열쇠"
		ItemIds.BOSS_KEY: return "보스 열쇠"
		ItemIds.HEART_PIECE: return "하트조각"
		_: return item_id


func _log(msg: String) -> void:
	_log_lines.append(msg)
	if _log_lines.size() > 5:
		_log_lines.pop_front()
	_log_label.text = "\n".join(_log_lines)
