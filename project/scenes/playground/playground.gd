extends Node2D

## 수동 플레이용 샌드박스. 자동 검증 씬(chem_test/m2_test)과 달리 여기선 직접 조작한다.
## 방향키 이동 / Z 칼 / X 활 / C 방패 토글 / Space 줍기·던지기 / Tab 화살 속성 전환(일반↔불).
## 공격/전투 그래픽이 아직 없어서(M2), 상태창+이벤트 로그로 대신 확인한다.

var _player: Player
var _vine: VineEnemy
var _status_label: Label
var _log_label: Label
var _log_lines: Array[String] = []


func _ready() -> void:
	_player = Player.new()
	_player.global_position = Vector2(400, 300)
	add_child(_player)

	var camera := Camera2D.new()
	camera.zoom = Vector2(1.5, 1.5)
	_player.add_child(camera)
	camera.make_current()

	_vine = VineEnemy.new()
	_vine.global_position = Vector2(600, 300)
	add_child(_vine)

	var campfire := ChemActor.new()
	campfire.chem_material = ChemTypes.MaterialTag.WOOD
	campfire.display_name = "화톳불"
	campfire.global_position = Vector2(250, 200)
	campfire.burn_duration = 30.0  # 샌드박스에서 오래 테스트할 수 있게 기본(2.5초)보다 길게
	add_child(campfire)
	campfire.set_state(ChemTypes.State.BURNING)

	var metal_box := ChemActor.new()
	metal_box.chem_material = ChemTypes.MaterialTag.METAL
	metal_box.display_name = "금속상자"
	metal_box.global_position = Vector2(250, 420)
	add_child(metal_box)

	var ice_block := ChemActor.new()
	ice_block.chem_material = ChemTypes.MaterialTag.ICE
	ice_block.display_name = "얼음"
	ice_block.global_position = Vector2(560, 460)
	add_child(ice_block)
	ice_block.set_state(ChemTypes.State.FROZEN)

	var jar := Throwable.new()
	jar.chem_material = ChemTypes.MaterialTag.WATER
	jar.display_name = "물항아리"
	jar.global_position = Vector2(450, 250)
	add_child(jar)

	var ui := CanvasLayer.new()
	add_child(ui)

	var help := Label.new()
	help.position = Vector2(20, 20)
	help.add_theme_font_size_override("font_size", 16)
	help.text = "방향키 이동 · Z 칼 · X 활 · C 방패 토글 · Space 줍기/던지기 · Tab 화살속성 전환(일반↔불)\n덩굴이=풀(불에 약함) / 화톳불=나무(BURNING) / 금속상자 / 얼음(FROZEN) / 물항아리=던지면 화학반응"
	ui.add_child(help)

	_status_label = Label.new()
	_status_label.position = Vector2(20, 80)
	_status_label.add_theme_font_size_override("font_size", 16)
	ui.add_child(_status_label)

	_log_label = Label.new()
	_log_label.position = Vector2(20, 110)
	_log_label.add_theme_font_size_override("font_size", 14)
	_log_label.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	ui.add_child(_log_label)

	_player.did_attack.connect(func(kind): _log("플레이어 %s 공격!" % kind))
	_player.did_shield_toggle.connect(func(active): _log("방패 %s" % ("ON" if active else "OFF")))
	_player.damaged.connect(func(amount): _log("플레이어 피격 -%.1f" % amount))
	_player.died.connect(func(): _log("플레이어 사망..."))
	_vine.damaged.connect(func(amount): _log("덩굴이 피격 -%.1f" % amount))
	_vine.died.connect(func(): _log("덩굴이 처치!"))


func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		return
	var tool_name := "불" if _player.current_tool == Player.ToolType.FIRE else "일반"
	_status_label.text = "하트: %.1f/%.1f | 방패: %s | 화살: %s" % [
		_player.hearts, _player.max_hearts,
		("ON" if _player.shield_active else "OFF"),
		tool_name,
	]


func _log(msg: String) -> void:
	_log_lines.append(msg)
	if _log_lines.size() > 6:
		_log_lines.pop_front()
	_log_label.text = "\n".join(_log_lines)
