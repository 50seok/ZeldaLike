class_name ChemActor
extends Area2D

## 화학엔진의 기본 오브젝트(§2.1). 재질 태그 + 상태를 갖고, 겹치는 다른 ChemActor와
## 자동으로 반응 규칙표를 조회한다. 새 오브젝트 = 이 스크립트를 붙이고 chem_material만 지정.
##
## 필드명이 chem_material/state(int)인 이유: "material"은 CanvasItem 내장 프로퍼티와
## 충돌하고, ChemTypes의 enum을 타입 힌트로 쓰면 Godot 4.7에서 파싱 오류가 난다(실측 확인).

signal shocked
signal chem_state_changed(new_state: int)
signal burned_out

@export var chem_material: int = ChemTypes.MaterialTag.WOOD
@export var display_name: String = ""
@export var burn_duration: float = 2.5
@export var box_size: Vector2 = Vector2(32, 32)

var state: int = ChemTypes.State.NONE

var _burn_timer := 0.0
var _label: Label

const FLAMMABLE := [ChemTypes.MaterialTag.WOOD, ChemTypes.MaterialTag.GRASS, ChemTypes.MaterialTag.CLOTH]

const MATERIAL_COLORS := {
	ChemTypes.MaterialTag.WOOD: Color(0.55, 0.35, 0.15),
	ChemTypes.MaterialTag.METAL: Color(0.6, 0.6, 0.65),
	ChemTypes.MaterialTag.GRASS: Color(0.25, 0.6, 0.2),
	ChemTypes.MaterialTag.CLOTH: Color(0.8, 0.8, 0.9),
	ChemTypes.MaterialTag.WATER: Color(0.2, 0.4, 0.8),
	ChemTypes.MaterialTag.ICE: Color(0.7, 0.9, 1.0),
}

const STATE_OVERLAY := {
	ChemTypes.State.BURNING: Color(1.0, 0.4, 0.0, 0.6),
	ChemTypes.State.WET: Color(0.1, 0.3, 1.0, 0.35),
	ChemTypes.State.CHARGED: Color(1.0, 1.0, 0.2, 0.5),
	ChemTypes.State.FROZEN: Color(0.6, 0.95, 1.0, 0.6),
}


func _ready() -> void:
	monitoring = true
	monitorable = true
	collision_layer = 1
	collision_mask = 1

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = box_size
	shape.shape = rect
	add_child(shape)

	_label = Label.new()
	_label.position = Vector2(-box_size.x / 2, -box_size.y / 2 - 34)
	_label.add_theme_font_size_override("font_size", 12)
	add_child(_label)
	# 자식 클래스(VineEnemy/Player 등)가 super._ready() 직후 자기 chem_material/display_name을
	# 덮어쓰는 경우가 많아서, 그 덮어쓰기가 끝난 다음 프레임에 라벨을 갱신한다 —
	# 여기서 즉시 호출하면 자식이 덮어쓰기 전 기본값(WOOD, 이름 없음)으로 굳어버린다(실측 확인).
	call_deferred("_update_label")

	area_entered.connect(_on_area_entered)
	queue_redraw()


func _on_area_entered(other: Area2D) -> void:
	if other is ChemActor:
		ChemistryManager.resolve_contact(self, other)


## 상태 변경 지점은 여기 하나뿐 — 여기서 겹친 이웃을 재조회하므로, set_state 호출만으로
## 화재/전기 전파가 연쇄된다(전파 로직을 따로 두지 않음).
func set_state(new_state: int) -> void:
	if state == new_state:
		return
	state = new_state
	_burn_timer = 0.0
	_update_label()
	queue_redraw()
	chem_state_changed.emit(state)
	for area in get_overlapping_areas():
		if area is ChemActor:
			ChemistryManager.resolve_contact(self, area)


func _process(delta: float) -> void:
	if state == ChemTypes.State.BURNING and chem_material in FLAMMABLE:
		_burn_timer += delta
		if _burn_timer >= burn_duration:
			burned_out.emit()
			queue_free()


func _draw() -> void:
	var base: Color = MATERIAL_COLORS.get(chem_material, Color.GRAY)
	draw_rect(Rect2(-box_size / 2, box_size), base)
	if STATE_OVERLAY.has(state):
		draw_rect(Rect2(-box_size / 2, box_size), STATE_OVERLAY[state])
	draw_rect(Rect2(-box_size / 2, box_size), Color.BLACK, false, 2.0)


func _update_label() -> void:
	var mat_name: String = ChemTypes.MaterialTag.keys()[chem_material]
	var state_name: String = ChemTypes.State.keys()[state]
	var prefix := display_name + "\n" if display_name != "" else ""
	_label.text = "%s%s/%s" % [prefix, mat_name, state_name]
