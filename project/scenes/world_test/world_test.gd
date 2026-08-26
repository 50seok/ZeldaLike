extends Node2D

## 수동 플레이용 — 마을(안전)에서 오른쪽으로 걸어가면 초원(덩굴이+수풀)으로
## 카메라 limit가 바뀌며 넘어간다. 조작은 playground.tscn과 동일.

var _player: Player
var _zone_ctrl: ZoneCameraController
var _status_label: Label
var _log_label: Label
var _log_lines: Array[String] = []

## 아직 그래픽이 없어서 존 경계를 색 배경 + 경계선으로 눈에 보이게 표시한다.
## 필드가 카메라 가시범위보다 충분히 커야 "화면 밖" 판정이 실제로 성립한다
## (900x700이었을 때는 존 안에서 카메라가 필드 전체를 거의 항상 보여줘서
## 리젠이 절대 안 되는 문제가 있었음 - 실측 확인).
var _village_bounds := Rect2(0, 0, 800, 608)
var _field_bounds := Rect2(800, 0, 1600, 1408)

## 실측 지적("배경이 조잡함 - 마을답게/던전답게/초원답게 보여야 함", "스타듀밸리처럼
## 집에 들어갔다 나갔다 했으면") - 마을은 반복 단일타일 대신 Tiny Town(§5) 타일로
## 실제 레벨(잔디+길+나무+집 2채)을 그린다. 좌표 단위는 "타일"(1칸=32유닛, 다른
## 모든 것과 동일 스케일) - 세계좌표로 쓰려면 *32.
const _CHIEF_HOUSE_DOOR_TILE := Vector2i(5, 3)
var _chief_house_door_world: Vector2
var _entered_chief_house := false

## §4.2 "필드를 지나 유적(던전)으로" - 초원 동쪽 끝에 던전 입구를 둔다. 씬 전환
## 방식(월드↔던전은 좌표공간이 완전히 달라 하나로 합치기보다 우선순위4까지의
## title/opening/ending과 동일한 change_scene_to_file 패턴을 그대로 재사용).
## 필드 폭은 몬스터 배치(1000~1900)에 맞춰 축소 - 원래 2400폭이라 아이언셸(1900)
## 이후 입구(3100)까지 아무것도 없는 1200px를 그냥 걸어야 했다(실측 지적:
## "몬스터 뭉친 곳에 비해 던전까지 너무 넓다").
var _dungeon_entrance_x := 2300.0
var _entered_dungeon := false

## 실측 지적: "초원맵등 던전처럼 제한이 있으면 좋겠음" - 지금까지 카메라만
## 존 경계에 맞춰 멈추고 플레이어 자신은 그 너머로 계속 걸어나갈 수 있었다
## (화면 밖 어둠 속으로 무한히 걸어가는 게 가능했음). 마을+초원을 감싸는
## 사각형으로 이동 자체를 막는다. 마을(0,0,800,600)과 초원(800,0,2400,1400)은
## 높이가 달라 정확히 합친 모양이 아니라 사각 경계 하나로 근사한다(빈 모서리가
## 살짝 남지만, "화면 밖으로 무한 이탈" 문제 해결이 목적이라 이걸로 충분).
var _world_bounds: Rect2


func _draw() -> void:
	draw_rect(Rect2(_village_bounds.end.x - 5, 0, 10, _village_bounds.size.y), Color(1.0, 1.0, 0.3))
	draw_rect(Rect2(_dungeon_entrance_x, 0, 100, _field_bounds.size.y), Color(0.3, 0.25, 0.15))


func _ready() -> void:
	Audio.play_bgm("village")

	# §5 "게임 배경화면" - 마을/초원 둘 다 Tiny Town 타일로 실제 레벨을 그린다.
	_build_village_tilemap()
	_build_field_tilemap()

	_player = Player.new()
	_player.global_position = Vector2(400, 300)
	add_child(_player)

	var camera := Camera2D.new()
	camera.zoom = Vector2(1.3, 1.3)
	_player.add_child(camera)
	camera.make_current()

	# UI를 먼저 만든다 — 아래 스폰/몬스터 배치 코드가 _log()를 바로 호출하는데,
	# UI(특히 _log_label)가 없는 상태에서 부르면 Nil 참조 에러가 난다(실측 확인).
	var ui := CanvasLayer.new()
	add_child(ui)

	# 실측 지적("초원에서 던전 가는 길을 모르겠음") 원인 - help/상태/로그/핫바를
	# 각자 손으로 계산한 Y좌표에 고정 배치해서, 안내문이 줄바꿈으로 늘어나면
	# 밑의 라벨들과 겹쳤다(위치 하드코딩은 텍스트 길이가 바뀔 때마다 다시 깨짐 -
	# QuestTracker와 겹쳤던 것과 같은 버그가 이번엔 자기들끼리 재발). VBoxContainer로
	# 묶어 실제 렌더 높이만큼 자동으로 다음 요소를 밀어내게 한다.
	var info_panel := VBoxContainer.new()
	info_panel.position = Vector2(20, 20)
	ui.add_child(info_panel)

	var help := Label.new()
	help.custom_minimum_size = Vector2(700, 0)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD
	help.add_theme_font_size_override("font_size", 16)
	help.text = "방향키 이동 · Z 칼(수풀도 벨 수 있음) · X 활 · Space 줍기/던지기/대화(대화 중엔 다음 줄) · V 내려놓기 · Tab 화살속성 전환(일반/불/전기)\n마을(안전, 회색 집에 촌장 있음, 문으로 들어가기) -> 초원(덩굴이+수풀, 리젠됨) -> 더 오른쪽: 우드가드(불화살로 방패 태우기, 방패 있어도 근접하면 반격함)/엠버(물항아리로 즉사)/아이언셸(물+전기 콤보로 스턴시킨 뒤 3방 더 때려야 처치)"
	info_panel.add_child(help)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 16)
	info_panel.add_child(_status_label)

	_log_label = Label.new()
	_log_label.add_theme_font_size_override("font_size", 14)
	_log_label.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	info_panel.add_child(_log_label)

	var dialogue_box := DialogueBox.new()
	ui.add_child(dialogue_box)
	dialogue_box.add_to_group("dialogue_box")

	var hotbar := Hotbar.new()
	hotbar.player = _player
	info_panel.add_child(hotbar)

	ui.add_child(PauseMenu.new())

	var quest_label := QuestTracker.new()
	quest_label.position = Vector2(750, 20)
	quest_label.size = Vector2(380, 60)
	quest_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	quest_label.steps = [
		{"flag": "met_chief", "text": "옹달마을 회색 지붕 집에 들어가 촌장에게 말을 걸어보자"},
		{"flag": "", "text": "초원을 계속 오른쪽(동쪽)으로 가면 유적 입구가 나온다"},
	]
	ui.add_child(quest_label)

	var item_banner := ItemGetBanner.new()
	ui.add_child(item_banner)

	_player.did_attack.connect(func(kind): _log("플레이어 %s 공격!" % kind))
	_player.damaged.connect(func(amount): _log("플레이어 피격 -%.1f" % amount))
	# 테스트 씬 전용 편의 기능 - 죽으면 플레이어가 그냥 사라지고 끝이라 재시작할 방법이
	# 없었다(실측 지적). 정식 게임오버 화면은 후순위(M4/M5) 스코프라, 지금은 씬 리로드로
	# 대체한다.
	_player.died.connect(func():
		_log("플레이어 사망... 2초 후 재시작")
		await get_tree().create_timer(2.0).timeout
		get_tree().reload_current_scene()
	)
	_player.item_collected.connect(func(item_id, count):
		_log("아이템 획득 +%d" % count)
		if ItemIds.is_notable(item_id):
			item_banner.show_item(ItemIds.display_name(item_id))
	)
	_player.did_interact.connect(func(result): _log("Space -> %s" % result))

	var village := WorldZone.new()
	village.zone_name = "옹달마을"
	village.bounds = _village_bounds
	village.is_safe = true

	var grassland := WorldZone.new()
	grassland.zone_name = "초원"
	grassland.bounds = _field_bounds
	grassland.is_safe = false

	_zone_ctrl = ZoneCameraController.new()
	_zone_ctrl.zones = [village, grassland]
	add_child(_zone_ctrl)
	_zone_ctrl.setup(camera, _player)
	_world_bounds = _village_bounds.merge(_field_bounds)
	# §3.4 세이브 - 던전 방이 아직 없어(우선순위6) "방 클리어 시 자동저장" 대신
	# 구역 진입을 체크포인트로 쓴다. 죽으면 씬을 리로드하는 기존 기능과 맞물려
	# "마지막 저장 지점에서 리스폰"(§3.6)이 추가 코드 없이 자연히 성립한다.
	_zone_ctrl.zone_changed.connect(func(zone):
		_log("%s 진입" % (zone.zone_name if zone else "경계 밖"))
		SaveManager.save_game(_player)
		_log("자동 저장됨")
	)

	var sp1 := SpawnPoint.new()
	sp1.entity_type = "vine"
	sp1.respawn_sec = 8.0  # 실제 기본값(45초)은 너무 길어 수동 테스트용으로 단축
	sp1.position = Vector2(1000, 250)
	add_child(sp1)
	var sp2 := SpawnPoint.new()
	sp2.entity_type = "vine"
	sp2.respawn_sec = 8.0
	sp2.position = Vector2(1150, 400)
	add_child(sp2)

	var spawn_mgr := FieldSpawnManager.new()
	spawn_mgr.spawn_points = [sp1, sp2]
	spawn_mgr.field_cap = 5
	add_child(spawn_mgr)
	spawn_mgr.setup(camera)
	spawn_mgr.entity_spawned.connect(_on_monster_spawned)

	var grass1 := GrassPatch.new()
	grass1.global_position = Vector2(1050, 500)
	add_child(grass1)
	var grass2 := GrassPatch.new()
	grass2.global_position = Vector2(1250, 250)
	add_child(grass2)

	# 우선순위3 신규 몬스터 미리보기 배치(실제 필드 배치는 우선순위6 던전/필드
	# 콘텐츠 작업에서 정리 - 지금은 동작 확인용 고정 배치)
	var guard := WoodGuard.new()
	guard.global_position = Vector2(1500, 300)
	add_child(guard)
	_on_monster_spawned(guard)

	var ember := Ember.new()
	ember.global_position = Vector2(1700, 500)
	add_child(ember)
	_on_monster_spawned(ember)

	var shell := IronShell.new()
	shell.global_position = Vector2(1900, 300)
	add_child(shell)
	_on_monster_spawned(shell)

	# 물항아리도 몬스터처럼 스폰포인트로 리젠시킨다 — 한 번 던져 없어지면 그걸로
	# 끝이라 계속 못 쓰던 문제(실측 지적: "항아리도 몬스터처럼 리젠돼야 할듯").
	# 몬스터 마릿수 상한을 나눠 먹지 않게 아이템 전용 매니저를 따로 둔다.
	var jar_sp1 := SpawnPoint.new()
	jar_sp1.entity_type = "water_jar"
	jar_sp1.respawn_sec = 10.0
	jar_sp1.position = Vector2(1650, 420)
	add_child(jar_sp1)
	var jar_sp2 := SpawnPoint.new()
	jar_sp2.entity_type = "water_jar"
	jar_sp2.respawn_sec = 10.0
	jar_sp2.position = Vector2(1850, 220)
	add_child(jar_sp2)

	var item_mgr := FieldSpawnManager.new()
	item_mgr.spawn_points = [jar_sp1, jar_sp2]
	item_mgr.field_cap = 2
	add_child(item_mgr)
	item_mgr.setup(camera)

	# 저장이 있으면 플레이어 상태+스토리 플래그를 여기서 덮어쓴다. 위치는 저장된
	# 씬이 이 씬 자신일 때만 신뢰한다 - 다른 씬(예: 던전) 좌표계에서 저장된 값을
	# 그대로 대입하면 엉뚱한 곳에 떨어진다(dungeon_test.gd에서 실측 확인된 문제와
	# 동일 - 지금은 던전->월드 복귀 경로가 없어 당장 터지진 않지만 대칭적으로 방지).
	if SaveManager.has_save():
		var came_from_this_scene := SaveManager.get_saved_scene_path() == scene_file_path
		var entry_position := _player.global_position
		SaveManager.load_game(_player)
		if not came_from_this_scene:
			_player.global_position = entry_position
		_log("저장된 게임을 이어서 불러왔습니다")

	# 실측 지적("집에서 나오면 화면 정가운데로 와버림 - 던전 나가는 느낌") -
	# 위 SaveManager 로직(하트·인벤토리·플래그 보존이 목적)보다 더 구체적인
	# "이 문 앞으로 정확히 돌아가라"는 힌트가 있으면 위치만 덮어쓴다.
	var spawn_override := SceneTransition.consume_spawn_for(scene_file_path)
	if spawn_override != Vector2.INF:
		_player.global_position = spawn_override

	# 실측 지적("스타듀밸리처럼 집에 들어갔다 나갔다") - 촌장은 이제 마을 밖이
	# 아니라 자기 집 안(village_house_chief.tscn)에 있다. 대화·sets_flag 로직은
	# 그 씬에 그대로(NPC 재사용, 새 시스템 0개).
	var villager := NPC.new()
	villager.npc_name = "마을 주민"
	villager.lines = ["요즘 원소가 폭주해서 무서워 죽겠어..."]
	villager.alt_lines = ["촌장님이 자네에게 부탁하셨다니, 마음이 좀 놓이는군."]
	villager.requires_flag = "met_chief"
	villager.sprite_texture = SpriteUtil.tile(SpriteUtil.TINY_DUNGEON, 99, SpriteUtil.TINY_DUNGEON_COLS)
	villager.global_position = Vector2(290, 170)
	add_child(villager)

	var entrance_label := Label.new()
	entrance_label.position = Vector2(_dungeon_entrance_x, -30)
	entrance_label.add_theme_font_size_override("font_size", 16)
	entrance_label.text = "유적 입구 →"
	add_child(entrance_label)


## Tiny Town 타일로 마을 레벨(잔디+길+집 2채+나무)을 그린다. 좌표는 "타일"
## 단위(TileMap 노드를 2배 스케일해서 1칸=32유닛 - 다른 모든 스프라이트와
## 동일). 배치는 PIL로 미리 그려서 눈으로 확인해본 배열을 그대로 옮김.
func _build_village_tilemap() -> void:
	var tm := TileMap.new()
	tm.tile_set = SpriteUtil.build_tileset(SpriteUtil.TINY_TOWN, SpriteUtil.TINY_TOWN_COLS, 11)
	tm.scale = Vector2(2, 2)
	tm.z_index = -10
	add_child(tm)

	var cols := 25
	var rows := 19
	var grass := _tt(0)
	for y in range(rows):
		for x in range(cols):
			tm.set_cell(0, Vector2i(x, y), 0, grass)

	# 자갈길(3x3 오토타일 블록 - 모서리/변/중앙) - 동서 대로 + 집으로 가는 지선.
	_paint_dirt_path(tm, 9, 10, 2, 24)
	_paint_dirt_path(tm, 4, 8, 5, 6)
	_paint_dirt_path(tm, 4, 8, 11, 12)

	var place_house := func(r0: int, c0: int, w: int, h: int, wall_idx: int, door_idx: int, door_col_offset: int, roof_idx: int):
		var wall := _tt(wall_idx)
		var roof := _tt(roof_idx)
		for yy in range(h):
			for xx in range(w):
				tm.set_cell(0, Vector2i(c0 + xx, r0 + yy), 0, wall)
		for xx in range(w):
			tm.set_cell(0, Vector2i(c0 + xx, r0), 0, roof)
		tm.set_cell(0, Vector2i(c0 + door_col_offset, r0 + h - 1), 0, _tt(door_idx))

	place_house.call(1, 4, 4, 3, 48, 78, 1, 63)   # 촌장 집(회색) - 입장 가능
	place_house.call(1, 10, 4, 3, 52, 74, 2, 67)  # 주민 집(붉은벽돌) - 장식용

	var trees := [3, 4, 5, 9]
	var tree_positions := [
		Vector2i(0, 0), Vector2i(2, 0), Vector2i(9, 0), Vector2i(16, 0), Vector2i(22, 0), Vector2i(24, 0),
		Vector2i(0, 18), Vector2i(3, 18), Vector2i(9, 18), Vector2i(15, 18), Vector2i(21, 18), Vector2i(24, 18),
		Vector2i(0, 5), Vector2i(0, 12), Vector2i(24, 5), Vector2i(24, 12),
	]
	for i in range(tree_positions.size()):
		var p: Vector2i = tree_positions[i]
		tm.set_cell(0, p, 0, _tt(trees[i % trees.size()]))

	# 촌장 집 문 = 입장 트리거 위치(세계좌표, 2배 스케일 반영).
	_chief_house_door_world = Vector2((_CHIEF_HOUSE_DOOR_TILE.x + 0.5) * 32.0, (_CHIEF_HOUSE_DOOR_TILE.y + 0.5) * 32.0)


## 3x3 오토타일 블록(모서리/변/중앙)으로 직사각형 자갈길을 그린다 - 마을·초원
## 양쪽에서 재사용.
func _paint_dirt_path(tm: TileMap, r0: int, r1: int, c0: int, c1: int) -> void:
	var path_tl := _tt(12); var path_t := _tt(13); var path_tr := _tt(14)
	var path_l := _tt(24); var path_c := _tt(25); var path_r := _tt(26)
	var path_bl := _tt(36); var path_b := _tt(37); var path_br := _tt(38)
	for y in range(r0, r1 + 1):
		for x in range(c0, c1 + 1):
			var t: Vector2i
			if y == r0 and x == c0: t = path_tl
			elif y == r0 and x == c1: t = path_tr
			elif y == r1 and x == c0: t = path_bl
			elif y == r1 and x == c1: t = path_br
			elif y == r0: t = path_t
			elif y == r1: t = path_b
			elif x == c0: t = path_l
			elif x == c1: t = path_r
			else: t = path_c
			tm.set_cell(0, Vector2i(x, y), 0, t)


## 실측 지적("초원도 마을처럼 레벨디자인") - 잔디 한 가지 색만 반복하는 대신
## 꽃 변형 타일을 드문드문 섞어 자연스러운 질감을 주고, 마을 대로와 같은 y
## 위치(행 9~10)에서 계속 이어지는 길을 내고, 가장자리에 나무를 둘러 "초원
## 답게" 보이도록 한다. 몬스터·스폰포인트 배치(§M3 우선순위3)는 그대로 - 이
## 타일맵은 순수 배경이라 위에 얹히는 것들과 좌표 충돌 없음.
func _build_field_tilemap() -> void:
	var tm := TileMap.new()
	tm.tile_set = SpriteUtil.build_tileset(SpriteUtil.TINY_TOWN, SpriteUtil.TINY_TOWN_COLS, 11)
	tm.position = Vector2(_field_bounds.position.x, 0)
	tm.scale = Vector2(2, 2)
	tm.z_index = -10
	add_child(tm)

	var cols := int(_field_bounds.size.x / 32.0)
	var rows := int(_field_bounds.size.y / 32.0)
	var grass_variants := [0, 0, 0, 0, 1, 2]
	for y in range(rows):
		for x in range(cols):
			var variant := 0
			if (x * 7 + y * 13) % 11 == 0:
				variant = grass_variants[(x + y) % grass_variants.size()]
			tm.set_cell(0, Vector2i(x, y), 0, _tt(variant))

	# 마을 대로(행 9~10)와 같은 높이로 계속 이어지는 길.
	_paint_dirt_path(tm, 9, 10, 0, cols - 1)

	var trees := [3, 4, 5, 9, 18]
	var tree_positions: Array[Vector2i] = []
	for x in range(2, cols - 2, 7):
		tree_positions.append(Vector2i(x, 0))
		tree_positions.append(Vector2i(x + 3, rows - 1))
	for i in range(tree_positions.size()):
		var p: Vector2i = tree_positions[i]
		tm.set_cell(0, p, 0, _tt(trees[i % trees.size()]))


func _tt(index: int) -> Vector2i:
	return Vector2i(index % SpriteUtil.TINY_TOWN_COLS, index / SpriteUtil.TINY_TOWN_COLS)


func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		return
	_player.global_position.x = clamp(_player.global_position.x, _world_bounds.position.x, _world_bounds.end.x)
	_player.global_position.y = clamp(_player.global_position.y, _world_bounds.position.y, _world_bounds.end.y)

	var zone_name := _zone_ctrl.current_zone.zone_name if _zone_ctrl.current_zone else "?"
	_status_label.text = "현재 구역: %s | 하트: %.1f/%.1f | 방패: %s" % [
		zone_name, _player.hearts, _player.max_hearts,
		("ON" if _player.shield_active else "OFF"),
	]

	if not _entered_dungeon and _player.global_position.x >= _dungeon_entrance_x:
		_entered_dungeon = true
		SaveManager.save_game(_player)  # 유적으로 넘어가는 순간 상태를 확정 저장
		get_tree().change_scene_to_file("res://scenes/dungeon_test/dungeon_test.tscn")

	# "집에 들어갔다 나갔다" - 문 타일에 닿으면 내부 씬으로 전환. 나올 때 상태
	# (하트/인벤토리/플래그)는 내부 씬이 나가기 직전에 저장하고, 위치는 world_test의
	# 기본 스폰으로 되돌아옴(문 앞 정확한 위치까지는 안 맞추는 대신 - Door처럼 새
	# 좌표 저장 체계를 또 안 만들어도 됨, dungeon_test.gd와 같은 이유).
	if not _entered_chief_house and _player.global_position.distance_to(_chief_house_door_world) < 20.0:
		_entered_chief_house = true
		get_tree().change_scene_to_file("res://scenes/village_house_chief/village_house_chief.tscn")


func _on_monster_spawned(monster: Node) -> void:
	_log("%s 등장" % monster.display_name)
	if monster.has_signal("damaged"):
		monster.damaged.connect(func(amount): _log("%s 피격 -%.1f" % [monster.display_name, amount]))
	if monster.has_signal("died"):
		monster.died.connect(func(): _log("%s 처치!" % monster.display_name))


func _log(msg: String) -> void:
	_log_lines.append(msg)
	if _log_lines.size() > 5:
		_log_lines.pop_front()
	_log_label.text = "\n".join(_log_lines)
