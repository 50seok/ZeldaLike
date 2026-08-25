extends Node2D

## 수동 플레이용 — 보스 "혼돈의 코어" 단독 아레나(M4 우선순위1). 던전과는 아직
## 안 이어져 있음(전체 연결은 우선순위5). 물 웅덩이 2곳을 고정 배치해 항아리를
## 계속 리필할 수 있게 한다(§4.1 "보스 방 고정 배치").
##
## 조작은 world_test.tscn과 동일: Z 칼 · X 활 · Space 줍기/던지기 · V 내려놓기 ·
## Tab 화살속성 전환. 콤보: 물항아리로 적시고 -> 전기화살로 감전 -> 스턴 중 칼.

var _player: Player
var _boss: ChaosCore
var _status_label: Label
var _log_label: Label
var _log_lines: Array[String] = []


func _ready() -> void:
	_player = Player.new()
	_player.global_position = Vector2(400, 500)
	add_child(_player)

	var camera := Camera2D.new()
	camera.zoom = Vector2(1.1, 1.1)
	_player.add_child(camera)
	camera.make_current()

	var ui := CanvasLayer.new()
	add_child(ui)

	var help := Label.new()
	help.position = Vector2(20, 20)
	help.add_theme_font_size_override("font_size", 16)
	help.text = "방향키 이동 · Z 칼 · X 활 · Space 줍기/던지기 · V 내려놓기 · Tab 화살속성 전환\n콤보: 물항아리로 적시기 -> 전기화살로 감전 -> 스턴 중 칼로 타격 (3회 반복하면 격파)"
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

	_player.damaged.connect(func(amount): _log("플레이어 피격 -%.1f" % amount))
	_player.died.connect(func():
		_log("플레이어 사망... 2초 후 재시작")
		await get_tree().create_timer(2.0).timeout
		get_tree().reload_current_scene()
	)
	_player.did_interact.connect(func(result): _log("Space -> %s" % result))

	_boss = ChaosCore.new()
	_boss.global_position = Vector2(400, 200)
	add_child(_boss)
	_boss.phase_changed.connect(func(new_phase):
		var phase_names := {ChaosCore.Phase.TWO: "2(얼음+덩굴이 소환)", ChaosCore.Phase.THREE: "3(속도+탄막 증가)"}
		_log("혼돈의 코어 -> 페이즈 %s 돌입!" % phase_names.get(new_phase, str(new_phase)))
	)
	_boss.defeated.connect(func():
		_log("혼돈의 코어 격파! 승리!")
	)

	# §4.1 "물 웅덩이 2곳(항아리 리필)" - 콤보 자원이 고갈돼 막히지 않게.
	var jar_sp1 := SpawnPoint.new()
	jar_sp1.entity_type = "water_jar"
	jar_sp1.respawn_sec = 8.0
	jar_sp1.position = Vector2(150, 500)
	add_child(jar_sp1)
	var jar_sp2 := SpawnPoint.new()
	jar_sp2.entity_type = "water_jar"
	jar_sp2.respawn_sec = 8.0
	jar_sp2.position = Vector2(650, 500)
	add_child(jar_sp2)

	var item_mgr := FieldSpawnManager.new()
	item_mgr.spawn_points = [jar_sp1, jar_sp2]
	item_mgr.field_cap = 2
	add_child(item_mgr)
	item_mgr.setup(camera)


func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		return
	var boss_status := "격파됨" if not is_instance_valid(_boss) else "진행 %d/3 (페이즈 %d)" % [_boss.hit_count, _boss.phase + 1]
	_status_label.text = "하트: %.1f/%.1f | 보스: %s" % [_player.hearts, _player.max_hearts, boss_status]


func _log(msg: String) -> void:
	_log_lines.append(msg)
	if _log_lines.size() > 6:
		_log_lines.pop_front()
	_log_label.text = "\n".join(_log_lines)
