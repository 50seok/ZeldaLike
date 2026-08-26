extends Node2D

## §3.4/§5 "촌장 집 내부" - 실측 지적("스타듀밸리처럼 집에 들어갔다 나갔다
## 했으면")으로 신설. 작은 방 하나(8x6칸) + 촌장 NPC(world_test에서 이동해옴,
## 대사·sets_flag 로직은 그대로 재사용 - 새 시스템 0개). 문으로 나가면
## world_test.tscn으로 복귀 - 정확히 문 앞 좌표로 돌아가진 않고 world_test의
## 기본 스폰으로 돌아간다(dungeon_test.gd와 같은 이유로 별도 "복귀 좌표" 체계를
## 안 만듦 - SaveManager.load_game()이 "저장된 씬 != 지금 씬"이면 위치는 스폰
## 유지+하트/인벤토리/플래그만 반영하는 기존 로직을 그대로 탐).

const ROOM_COLS := 8
const ROOM_ROWS := 6
const DOOR_COL := 3

var _player: Player
var _status_label: Label
var _log_label: Label
var _log_lines: Array[String] = []
var _exit_y_threshold := 0.0
var _exited := false


func _ready() -> void:
	Audio.play_bgm("village")

	_build_room_tilemap()

	_player = Player.new()
	_player.global_position = Vector2((DOOR_COL + 1) * 32.0, (ROOM_ROWS - 2) * 32.0)
	add_child(_player)

	var camera := Camera2D.new()
	camera.zoom = Vector2(3.0, 3.0)  # 작은 방이라 많이 확대해야 화면이 안 텅 비어 보임
	_player.add_child(camera)
	camera.make_current()

	var ui := CanvasLayer.new()
	add_child(ui)

	var info_panel := VBoxContainer.new()
	info_panel.position = Vector2(20, 20)
	ui.add_child(info_panel)

	var help := Label.new()
	help.custom_minimum_size = Vector2(700, 0)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD
	help.add_theme_font_size_override("font_size", 16)
	help.text = "방향키 이동 · Space 대화(대화 중엔 다음 줄) · 문(아래쪽)으로 다시 나가기"
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

	ui.add_child(PauseMenu.new())

	_player.did_interact.connect(func(result): _log("Space -> %s" % result))

	if SaveManager.has_save():
		var came_from_this_scene := SaveManager.get_saved_scene_path() == scene_file_path
		var entry_position := _player.global_position
		SaveManager.load_game(_player)
		if not came_from_this_scene:
			_player.global_position = entry_position
		_log("저장된 게임을 이어서 불러왔습니다")

	var chief := NPC.new()
	chief.npc_name = "촌장"
	chief.lines = [
		"어서 오게, 견습 연금술사여.",
		"마을 지하 유적의 봉인이 풀려 원소가 날뛰고 있다네.",
		"자네가 가서 좀 진정시켜 주게.",
	]
	chief.sets_flag = "met_chief"
	chief.sprite_texture = SpriteUtil.tile(SpriteUtil.TINY_DUNGEON, 84, SpriteUtil.TINY_DUNGEON_COLS)
	chief.global_position = Vector2(3 * 32.0, 2 * 32.0)
	add_child(chief)

	_exit_y_threshold = (ROOM_ROWS - 1.5) * 32.0


func _build_room_tilemap() -> void:
	var tm := TileMap.new()
	tm.tile_set = SpriteUtil.build_tileset(SpriteUtil.TINY_TOWN, SpriteUtil.TINY_TOWN_COLS, 11)
	tm.scale = Vector2(2, 2)
	tm.z_index = -10
	add_child(tm)

	var wall := _tt(48)
	var door := _tt(78)
	for y in range(ROOM_ROWS):
		for x in range(ROOM_COLS):
			var is_border := x == 0 or x == ROOM_COLS - 1 or y == 0 or y == ROOM_ROWS - 1
			if is_border:
				tm.set_cell(0, Vector2i(x, y), 0, wall)

	tm.set_cell(0, Vector2i(DOOR_COL, ROOM_ROWS - 1), 0, door)

	# 실내 바닥 - Tiny Dungeon 낱장 타일 재사용(따뜻한 색感 틴트로 "실내"임을 구분).
	var floor_area := Rect2(32, 32, (ROOM_COLS - 2) * 32.0, (ROOM_ROWS - 2) * 32.0)
	var floor_sprite := SpriteUtil.make_tiled_floor(SpriteUtil.FLOOR_STONE, floor_area, Color(1.1, 0.95, 0.8))
	add_child(floor_sprite)


func _tt(index: int) -> Vector2i:
	return Vector2i(index % SpriteUtil.TINY_TOWN_COLS, index / SpriteUtil.TINY_TOWN_COLS)


func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		return

	# 벽 타일 안쪽에만 머물게(다른 씬들의 world_bounds clamp와 같은 목적) -
	# 문 있는 아랫줄까지는 갈 수 있어야 하니 아래쪽은 살짝 더 열어둔다.
	_player.global_position.x = clamp(_player.global_position.x, 32.0, (ROOM_COLS - 1) * 32.0)
	_player.global_position.y = clamp(_player.global_position.y, 32.0, (ROOM_ROWS - 1) * 32.0)

	_status_label.text = "촌장의 집 | 하트: %.1f/%.1f" % [_player.hearts, _player.max_hearts]

	if not _exited and _player.global_position.y >= _exit_y_threshold:
		_exited = true
		SaveManager.save_game(_player)
		# world_test.gd의 _CHIEF_HOUSE_DOOR_TILE(5,3)과 짝을 이루는 값 - 문 바로
		# 앞(남쪽)으로 나오게. 두 값이 어긋나면 다시 정가운데로 돌아가버리니
		# world_test.gd 쪽 문 위치를 바꾸면 여기도 같이 바꿀 것.
		SceneTransition.request_spawn_at("res://scenes/world_test/world_test.tscn", Vector2(176, 160))
		get_tree().change_scene_to_file("res://scenes/world_test/world_test.tscn")


func _log(msg: String) -> void:
	_log_lines.append(msg)
	if _log_lines.size() > 5:
		_log_lines.pop_front()
	_log_label.text = "\n".join(_log_lines)
