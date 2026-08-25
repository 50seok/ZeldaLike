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
var _village_bounds := Rect2(0, 0, 800, 600)
var _field_bounds := Rect2(800, 0, 2400, 1400)


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

	# UI를 먼저 만든다 — 아래 스폰/몬스터 배치 코드가 _log()를 바로 호출하는데,
	# UI(특히 _log_label)가 없는 상태에서 부르면 Nil 참조 에러가 난다(실측 확인).
	var ui := CanvasLayer.new()
	add_child(ui)

	var help := Label.new()
	help.position = Vector2(20, 20)
	help.add_theme_font_size_override("font_size", 16)
	help.text = "방향키 이동 · Z 칼(수풀도 벨 수 있음) · X 활 · Tab 화살속성 전환(일반/불/전기)\n마을(안전)->초원(덩굴이+수풀, 리젠됨)->더 오른쪽: 우드가드(불화살로 방패 태우기)/엠버(물항아리로 즉사)/아이언셸(물+전기 콤보 스턴)"
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

	_player.did_attack.connect(func(kind): _log("플레이어 %s 공격!" % kind))
	_player.damaged.connect(func(amount): _log("플레이어 피격 -%.1f" % amount))
	_player.died.connect(func(): _log("플레이어 사망..."))
	_player.item_collected.connect(func(item_id, count): _log("아이템 획득 +%d" % count))

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

	var sp1 := SpawnPoint.new()
	sp1.monster_type = "vine"
	sp1.respawn_sec = 8.0  # 실제 기본값(45초)은 너무 길어 수동 테스트용으로 단축
	sp1.position = Vector2(1000, 250)
	add_child(sp1)
	var sp2 := SpawnPoint.new()
	sp2.monster_type = "vine"
	sp2.respawn_sec = 8.0
	sp2.position = Vector2(1150, 400)
	add_child(sp2)

	var spawn_mgr := FieldSpawnManager.new()
	spawn_mgr.spawn_points = [sp1, sp2]
	spawn_mgr.field_cap = 5
	add_child(spawn_mgr)
	spawn_mgr.setup(camera)
	spawn_mgr.monster_spawned.connect(_on_monster_spawned)

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

	# 마을 근처 항아리 하나뿐이면 여기까지 들고 오기 번거로우니 근처에 더 배치
	# (실측 지적 - "맵에 물 항아리가 없는데 어떻게 뿌려?")
	var jar_ember := Throwable.new()
	jar_ember.chem_material = ChemTypes.MaterialTag.WATER
	jar_ember.display_name = "물항아리"
	jar_ember.global_position = Vector2(1650, 420)
	add_child(jar_ember)

	var jar_shell := Throwable.new()
	jar_shell.chem_material = ChemTypes.MaterialTag.WATER
	jar_shell.display_name = "물항아리"
	jar_shell.global_position = Vector2(1850, 220)
	add_child(jar_shell)


func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		return
	var zone_name := _zone_ctrl.current_zone.zone_name if _zone_ctrl.current_zone else "?"
	_status_label.text = "현재 구역: %s | 하트: %.1f/%.1f | 화살: %d" % [
		zone_name, _player.hearts, _player.max_hearts, _player.inventory.get_count(ItemIds.ARROW)
	]


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
