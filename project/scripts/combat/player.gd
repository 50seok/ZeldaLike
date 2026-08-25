class_name Player
extends Combatant

## §3.1 플레이어 액션. 벽·room 충돌은 아직 없어서(M3에서 던전 생기면 추가) Area2D 위치 이동으로 충분.
## 조작(수동 플레이 시): 방향키=이동, Z=칼, X=활, C=방패 토글, Space=줍기/던지기, Tab=화살 속성 전환.

enum ToolType { NORMAL, FIRE }

## 공격/방어 그래픽이 없는 동안(M2) 조작 결과를 확인할 수 있게 하는 디버그용 신호.
signal did_attack(kind: String)
signal did_shield_toggle(active: bool)
signal item_collected(item_id: String, count: int)

var inventory := Inventory.new()

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


@export var starting_arrows: int = 10


func _ready() -> void:
	super._ready()
	chem_material = ChemTypes.MaterialTag.CLOTH
	display_name = "플레이어"
	add_to_group("player")
	_spawn_equipped_weapon()
	inventory.add(ItemIds.ARROW, starting_arrows)


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


## 자기가 쏜 화살과도 접촉 판정이 나서(Arrow는 shooter를 무시하지만 반대쪽인
## 플레이어는 몰랐음), 불화살 쏘면 CLOTH 재질인 자신에게 불이 옮아 타 죽던 버그
## 수정(실측 확인 - "불화살로 공격했는데 내가 죽음").
func _on_area_entered(other: Area2D) -> void:
	if other is Arrow and other.shooter == self:
		return
	super._on_area_entered(other)


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
	# 수풀 등 환경 오브젝트는 HP가 없어 take_damage가 아니라 즉시 파괴(cut_down)
	for node in get_tree().get_nodes_in_group("cuttable_props"):
		if not is_instance_valid(node):
			continue
		var to_target: Vector2 = node.global_position - global_position
		if to_target.length() <= sword_range and to_target.normalized().dot(facing) > 0.3:
			node.cut_down()


func perform_bow_attack() -> void:
	if inventory.get_count(ItemIds.ARROW) <= 0:
		did_attack.emit("활(화살 없음!)")
		return
	inventory.remove(ItemIds.ARROW, 1)
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


## §3.3 드랍 지급 진입점. ChemActor.perform_drops()가 그룹 "player"를 찾아 이걸 호출한다.
## 하트=즉시 회복(인벤토리에 안 쌓임), 하트조각=4개 모이면 최대 하트+1(젤다 관례),
## 나머지(화살·열쇠)는 그냥 인벤토리 수량으로 누적.
func collect_item(item_id: String, count: int) -> void:
	match item_id:
		ItemIds.HEART:
			hearts = min(max_hearts, hearts + count)
		ItemIds.HEART_PIECE:
			inventory.add(item_id, count)
			while inventory.get_count(ItemIds.HEART_PIECE) >= 4:
				inventory.remove(ItemIds.HEART_PIECE, 4)
				max_hearts += 1.0
				hearts = max_hearts
		_:
			inventory.add(item_id, count)
	item_collected.emit(item_id, count)


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
