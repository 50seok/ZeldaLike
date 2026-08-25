extends Node2D

## 수동 플레이용 샌드박스. 자동 검증 씬(chem_test/m2_test)과 달리 여기선 직접 조작한다.
## 방향키 이동 / Z 칼 / X 활 / C 방패 토글 / Space 줍기·던지기 / Tab 화살 속성 전환(일반↔불).


func _ready() -> void:
	var player := Player.new()
	player.global_position = Vector2(400, 300)
	add_child(player)

	var camera := Camera2D.new()
	camera.zoom = Vector2(1.5, 1.5)
	player.add_child(camera)
	camera.make_current()

	var vine := VineEnemy.new()
	vine.global_position = Vector2(600, 300)
	add_child(vine)

	var campfire := ChemActor.new()
	campfire.chem_material = ChemTypes.MaterialTag.WOOD
	campfire.display_name = "화톳불"
	campfire.global_position = Vector2(250, 200)
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
