extends Node2D

## 수동 플레이용 — 마을(안전)에서 오른쪽으로 걸어가면 초원(덩굴이+수풀)으로
## 카메라 limit가 바뀌며 넘어간다. 조작은 playground.tscn과 동일.

var _player: Player
var _zone_ctrl: ZoneCameraController
var _status_label: Label
var _log_label: Label
var _log_lines: Array[String] = []

## 아직 그래픽이 없어서 존 경계를 색 배경 + 경계선으로 눈에 보이게 표시한다.
var _village_bounds := Rect2(0, 0, 800, 600)
var _field_bounds := Rect2(800, 0, 900, 700)


func _draw() -> void:
	draw_rect(_village_bounds, Color(0.15, 0.15, 0.28))
	draw_rect(_field_bounds, Color(0.12, 0.26, 0.14))
	draw_rect(Rect2(_village_bounds.end.x - 5, 0, 10, _village_bounds.size.y), Color(1.0, 1.0, 0.3))


func _ready() -> void:
	_player = Player.new()
	_player.global_position = Vector2(400, 300)
	add_child(_player)

	var camera := Camera2D.new()
	camera.zoom = Vector2(1.3, 1.3)
	_player.add_child(camera)
	camera.make_current()

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
	_zone_ctrl.zone_changed.connect(func(zone): _log("%s 진입" % (zone.zone_name if zone else "경계 밖")))

	var vine1 := VineEnemy.new()
	vine1.global_position = Vector2(1000, 250)
	add_child(vine1)
	var vine2 := VineEnemy.new()
	vine2.global_position = Vector2(1150, 400)
	add_child(vine2)

	var grass1 := GrassPatch.new()
	grass1.global_position = Vector2(1050, 500)
	add_child(grass1)
	var grass2 := GrassPatch.new()
	grass2.global_position = Vector2(1250, 250)
	add_child(grass2)

	var ui := CanvasLayer.new()
	add_child(ui)

	var help := Label.new()
	help.position = Vector2(20, 20)
	help.add_theme_font_size_override("font_size", 16)
	help.text = "방향키 이동 · Z 칼(수풀도 벨 수 있음) · X 활 · Tab 화살속성 전환\n마을(안전)에서 오른쪽으로 걸어가면 초원(덩굴이+수풀)"
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

	_player.item_collected.connect(func(item_id, count): _log("아이템 획득 +%d" % count))


func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		return
	var zone_name := _zone_ctrl.current_zone.zone_name if _zone_ctrl.current_zone else "?"
	_status_label.text = "현재 구역: %s | 하트: %.1f/%.1f | 화살: %d" % [
		zone_name, _player.hearts, _player.max_hearts, _player.inventory.get_count(ItemIds.ARROW)
	]


func _log(msg: String) -> void:
	_log_lines.append(msg)
	if _log_lines.size() > 5:
		_log_lines.pop_front()
	_log_label.text = "\n".join(_log_lines)
