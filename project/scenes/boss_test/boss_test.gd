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

var _arena_bounds := Rect2(-50, -50, 900, 700)


## world_test/dungeon_test와 달리 이 씬엔 바닥 배경이 없어서(실측 지적: "내가
## 어디있는지도 모르겠고 움직여지지도 않음") 어두운 기본 배경에 32px짜리
## 캐릭터만 떠 있어 위치/이동을 체감하기 어려웠다. 아레나 바닥+경계선을 그려
## 시각적 기준점을 준다.
func _draw() -> void:
	draw_rect(_arena_bounds, Color(0.16, 0.12, 0.12))
	draw_rect(_arena_bounds, Color(0.5, 0.15, 0.15), false, 4.0)


func _ready() -> void:
	_player = Player.new()
	_player.global_position = Vector2(400, 500)
	# 보스전을 실제로 "깰 수 있게" 장비를 넉넉히 갖추고 시작한다 - 콤보를
	# 3번 반복해야 하는데(재감전 필요) 기본 하트 3개/화살 10개로는 화염구+접촉
	# 피해 몇 번에 빠듯하다(실측 요청: "깰 수 있을만한 장비 준비해놓고 진행").
	_player.max_hearts = 6.0
	_player.starting_arrows = 30
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

	ui.add_child(PauseMenu.new())

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
		get_tree().change_scene_to_file("res://scenes/ending/ending.tscn")
	)

	# §4.1 "물 웅덩이 2곳(항아리 리필)" - 콤보 자원이 고갈돼 막히지 않게.
	var jar_sp1 := SpawnPoint.new()
	jar_sp1.entity_type = "water_jar"
	jar_sp1.respawn_sec = 5.0  # 콤보를 3번(페이즈마다 재감전) 반복해야 해서 넉넉히 짧게
	jar_sp1.position = Vector2(150, 500)
	add_child(jar_sp1)
	var jar_sp2 := SpawnPoint.new()
	jar_sp2.entity_type = "water_jar"
	jar_sp2.respawn_sec = 5.0
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
