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
@export var drop_table: DropTable

## §5 "그래픽 에셋" - 지정하면 재질색 사각형 대신 이 텍스처로 그린다(화학
## 상태 틴트/테두리는 그 위에 그대로 유지 - 그림이 생겨도 WET/BURNING 같은
## 게임플레이 신호는 계속 보여야 함).
@export var sprite_texture: Texture2D = null

var state: int = ChemTypes.State.NONE

var _burn_timer := 0.0
var _label: Label
var _sprite: Sprite2D

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
	# 자식 클래스(VineEnemy/Player 등)가 super._ready() 직후 자기 chem_material/display_name/
	# sprite_texture를 덮어쓰는 경우가 많아서, 그 덮어쓰기가 끝난 다음 프레임에 라벨·스프라이트를
	# 갱신한다 — 여기서 즉시 호출하면 자식이 덮어쓰기 전 기본값으로 굳어버린다(실측 확인).
	call_deferred("_setup_deferred_visuals")

	area_entered.connect(_on_area_entered)
	queue_redraw()


func _setup_deferred_visuals() -> void:
	_update_label()
	if sprite_texture and _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.texture = sprite_texture
		_sprite.scale = box_size / Vector2(SpriteUtil.TILE_SIZE, SpriteUtil.TILE_SIZE)
		add_child(_sprite)
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
			perform_drops()
			_on_destroyed()


## 파괴 지점을 하나로 모은다 — Combatant가 이걸 오버라이드해서 전투사망/소각사망
## 양쪽 다 died 신호가 나가게 한다(전에는 소각사망 때 died가 안 나가는 구멍이 있었음).
func _on_destroyed() -> void:
	_spawn_destroy_effect()
	queue_free()


## §3.2 "이펙트" - 죽을 때 재질 색 파편이 잠깐 튀는 연출. self가 이 프레임에
## queue_free되므로 파티클은 부모의 자식으로 따로 띄운다. finished 신호를
## 믿었다가 웹에서 SFX 정리가 안 됐던 것과 같은 부류의 문제를 피하려고
## (§오디오 교훈) 재생시간 기반 타이머로 직접 정리한다.
func _spawn_destroy_effect() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var particles := CPUParticles2D.new()
	particles.global_position = global_position
	particles.amount = 10
	particles.lifetime = 0.35
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.gravity = Vector2(0, 300)
	particles.initial_velocity_min = 50.0
	particles.initial_velocity_max = 110.0
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 5.0
	particles.color = MATERIAL_COLORS.get(chem_material, Color.WHITE)
	parent.add_child(particles)
	particles.emitting = true
	get_tree().create_timer(particles.lifetime + 0.2).timeout.connect(particles.queue_free)


## §3.3 드랍 — 파괴 시점의 상태(state)로 기본/BURNING 테이블 중 골라 굴리고,
## 유일한 플레이어(그룹 "player")에게 바로 지급한다(물리 픽업 오브젝트는 Post-MVP,
## 지금은 "접촉 즉시 획득" 관례를 인벤토리 직접 지급으로 단순화).
func perform_drops() -> void:
	if drop_table == null:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not player.has_method("collect_item"):
		return
	for drop in drop_table.roll(state):
		player.collect_item(drop["item_id"], drop["count"])


func _draw() -> void:
	if sprite_texture == null:
		var base: Color = MATERIAL_COLORS.get(chem_material, Color.GRAY)
		draw_rect(Rect2(-box_size / 2, box_size), base)
		draw_rect(Rect2(-box_size / 2, box_size), Color.BLACK, false, 2.0)
	if STATE_OVERLAY.has(state):
		draw_rect(Rect2(-box_size / 2, box_size), STATE_OVERLAY[state])


func _update_label() -> void:
	var mat_name: String = ChemTypes.MaterialTag.keys()[chem_material]
	var state_name: String = ChemTypes.State.keys()[state]
	var prefix := display_name + "\n" if display_name != "" else ""
	_label.text = "%s%s/%s" % [prefix, mat_name, state_name]
