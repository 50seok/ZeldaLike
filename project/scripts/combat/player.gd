class_name Player
extends Combatant

## §3.1 플레이어 액션. 벽·room 충돌은 아직 없어서(M3에서 던전 생기면 추가) Area2D 위치 이동으로 충분.
## 조작(수동 플레이 시): 방향키=이동, Z=칼, X=활, C=방패 토글, Space=줍기/던지기, Tab=화살 속성 전환.

enum ToolType { NORMAL, FIRE }

## 공격/방어 그래픽이 없는 동안(M2) 조작 결과를 확인할 수 있게 하는 디버그용 신호.
signal did_attack(kind: String)
signal did_shield_toggle(active: bool)

@export var move_speed: float = 140.0
@export var sword_material: int = ChemTypes.MaterialTag.WOOD
@export var sword_damage: float = 1.0
@export var sword_range: float = 40.0
@export var shield_material: int = ChemTypes.MaterialTag.WOOD

var facing := Vector2.DOWN
var shield_active := false
var current_tool: ToolType = ToolType.NORMAL

var _equipped_weapon: EquippedWeapon
var _held_item: Throwable


func _ready() -> void:
	super._ready()
	chem_material = ChemTypes.MaterialTag.CLOTH
	display_name = "플레이어"
	add_to_group("player")
	_spawn_equipped_weapon()


func _physics_process(delta: float) -> void:
	var move_vec := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	position += move_vec * move_speed * delta
	if move_vec != Vector2.ZERO:
		facing = move_vec.normalized()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_Z:
				perform_melee_attack()
			KEY_X:
				perform_bow_attack()
			KEY_C:
				toggle_shield()
			KEY_SPACE:
				interact_or_throw()
			KEY_TAB:
				cycle_tool()


func take_damage(amount: float) -> void:
	var final_amount := amount
	if shield_active:
		final_amount *= 0.5
	super.take_damage(final_amount)


func perform_melee_attack() -> void:
	did_attack.emit("칼")
	for node in get_tree().get_nodes_in_group("combatant_enemies"):
		if not is_instance_valid(node):
			continue
		var to_target: Vector2 = node.global_position - global_position
		if to_target.length() <= sword_range and to_target.normalized().dot(facing) > 0.3:
			node.take_damage(sword_damage)


func perform_bow_attack() -> void:
	did_attack.emit("활(%s)" % ("불" if current_tool == ToolType.FIRE else "일반"))
	var arrow := Arrow.new()
	arrow.shooter = self
	arrow.direction = facing if facing != Vector2.ZERO else Vector2.RIGHT
	arrow.chem_material = ChemTypes.MaterialTag.WOOD if current_tool == ToolType.FIRE else ChemTypes.MaterialTag.METAL
	arrow.global_position = global_position + arrow.direction * 20.0
	get_parent().add_child(arrow)
	if current_tool == ToolType.FIRE:
		arrow.set_state(ChemTypes.State.BURNING)


func toggle_shield() -> void:
	shield_active = not shield_active
	did_shield_toggle.emit(shield_active)


func cycle_tool() -> void:
	current_tool = ToolType.FIRE if current_tool == ToolType.NORMAL else ToolType.NORMAL


func interact_or_throw() -> void:
	if _held_item:
		_held_item.throw(facing)
		_held_item = null
		return
	for area in get_overlapping_areas():
		if area is Throwable:
			_held_item = area
			area.pick_up(self)
			return


func _spawn_equipped_weapon() -> void:
	_equipped_weapon = EquippedWeapon.new()
	_equipped_weapon.chem_material = sword_material
	_equipped_weapon.display_name = "장착무기"
	_equipped_weapon.box_size = Vector2(10, 10)
	_equipped_weapon.burn_duration = 1.5
	_equipped_weapon.position = Vector2(16, 0)
	add_child(_equipped_weapon)
	_equipped_weapon.weapon_destroyed.connect(_on_weapon_destroyed)


func _on_weapon_destroyed() -> void:
	print("무기가 불타 사라졌다!")
	_equipped_weapon = null
