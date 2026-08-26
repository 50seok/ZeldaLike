class_name Player
extends Combatant

## §3.1 플레이어 액션. 벽·room 충돌은 아직 없어서(M3에서 던전 생기면 추가) Area2D 위치 이동으로 충분.
## 조작(수동 플레이 시): 방향키=이동, Z=칼, X=활, C=방패 토글, Space=줍기/던지기, Tab=화살 속성 전환.

enum ToolType { NORMAL, FIRE, ELECTRIC }

## 공격/방어 그래픽이 없는 동안(M2) 조작 결과를 확인할 수 있게 하는 디버그용 신호.
signal did_attack(kind: String)
signal did_shield_toggle(active: bool)
signal item_collected(item_id: String, count: int)
signal did_interact(result: String)

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
var _dialogue_box: DialogueBox


@export var starting_arrows: int = 10


func _ready() -> void:
	super._ready()
	chem_material = ChemTypes.MaterialTag.CLOTH
	display_name = "플레이어"
	add_to_group("player")
	_spawn_equipped_weapon()
	inventory.add(ItemIds.ARROW, starting_arrows)


func _physics_process(delta: float) -> void:
	if _is_dialogue_open():
		return
	var move_vec := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	position += move_vec * move_speed * delta
	if move_vec != Vector2.ZERO:
		facing = move_vec.normalized()


## 대화박스는 씬이 만들어 그룹("dialogue_box")에 등록해두면 여기서 찾는다 -
## 매 프레임 그룹 조회를 피하려고 한 번 찾으면 캐싱한다(다른 몹들의 _player
## 캐싱과 동일 패턴).
func _is_dialogue_open() -> bool:
	if _dialogue_box == null or not is_instance_valid(_dialogue_box):
		_dialogue_box = get_tree().get_first_node_in_group("dialogue_box")
	return _dialogue_box != null and _dialogue_box.is_open()


## 대화 중엔 Space가 "다음 줄/닫기" 전용이 되고, 그 외 입력은 전부 막는다
## (대화 중에 칼을 휘두르거나 걸어 나가는 걸 막기 위함 - 젤다 관례).
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if _is_dialogue_open():
			if event.keycode == KEY_SPACE:
				_dialogue_box.advance()
			return
		match event.keycode:
			KEY_Z:
				perform_melee_attack()
			KEY_X:
				perform_bow_attack()
			KEY_C:
				toggle_shield()
			KEY_SPACE:
				interact_or_throw()
			KEY_V:
				put_down_item()
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
	Audio.play_sfx("attack")
	did_attack.emit("칼")
	for node in get_tree().get_nodes_in_group("combatant_enemies"):
		if is_instance_valid(node) and _is_in_melee_range(node):
			node.take_damage(sword_damage)
	# 수풀 등 환경 오브젝트는 HP가 없어 take_damage가 아니라 즉시 파괴(cut_down)
	for node in get_tree().get_nodes_in_group("cuttable_props"):
		if is_instance_valid(node) and _is_in_melee_range(node):
			node.cut_down()


## 아주 가까운 거리(point-blank)에서는 방향 벡터 길이가 0에 가까워져 dot product
## 방향 판정이 불안정해진다 — 딱 붙었을 때 오히려 안 맞는 것처럼 느껴지던 원인
## (실측 지적). 근접 반경(sword_range의 절반) 안에서는 방향 무관하게 명중으로 친다.
func _is_in_melee_range(node: Node2D) -> bool:
	var to_target: Vector2 = node.global_position - global_position
	var dist := to_target.length()
	if dist > sword_range:
		return false
	if dist <= sword_range * 0.5:
		return true
	return to_target.normalized().dot(facing) > 0.3


func perform_bow_attack() -> void:
	if inventory.get_count(ItemIds.ARROW) <= 0:
		did_attack.emit("활(화살 없음!)")
		return
	inventory.remove(ItemIds.ARROW, 1)
	var tool_names := {ToolType.NORMAL: "일반", ToolType.FIRE: "불", ToolType.ELECTRIC: "전기"}
	Audio.play_sfx("attack")
	did_attack.emit("활(%s)" % tool_names[current_tool])
	var arrow := Arrow.new()
	arrow.shooter = self
	arrow.direction = facing if facing != Vector2.ZERO else Vector2.RIGHT
	arrow.chem_material = ChemTypes.MaterialTag.WOOD if current_tool == ToolType.FIRE else ChemTypes.MaterialTag.METAL
	arrow.global_position = global_position + arrow.direction * 20.0
	get_parent().add_child(arrow)
	if current_tool == ToolType.FIRE:
		arrow.set_state(ChemTypes.State.BURNING)
	elif current_tool == ToolType.ELECTRIC:
		arrow.set_state(ChemTypes.State.CHARGED)


func toggle_shield() -> void:
	shield_active = not shield_active
	did_shield_toggle.emit(shield_active)


func cycle_tool() -> void:
	match current_tool:
		ToolType.NORMAL:
			current_tool = ToolType.FIRE
		ToolType.FIRE:
			current_tool = ToolType.ELECTRIC
		ToolType.ELECTRIC:
			current_tool = ToolType.NORMAL


func interact_or_throw() -> void:
	if _held_item:
		did_interact.emit("던짐")
		_held_item.throw(facing)
		_held_item = null
		return
	for area in get_overlapping_areas():
		if area is NPC:
			if _is_dialogue_open():
				return
			did_interact.emit("대화 시작")
			area.talk(_get_or_find_dialogue_box())
			return
	for area in get_overlapping_areas():
		if area is TreasureChest:
			if area.open(self):
				did_interact.emit("보물상자 개봉")
			else:
				did_interact.emit("이미 연 상자")
			return
	for area in get_overlapping_areas():
		if area is Throwable:
			did_interact.emit("주움")
			_held_item = area
			area.pick_up(self)
			return
	did_interact.emit("주울 것 없음")


func _get_or_find_dialogue_box() -> DialogueBox:
	if _dialogue_box == null or not is_instance_valid(_dialogue_box):
		_dialogue_box = get_tree().get_first_node_in_group("dialogue_box")
	return _dialogue_box


## Space(던지기)와 분리한 이유: 실수로 던지지 않고 제자리에 놓고 싶을 때
## 쓰는 별도 동작이라, 같은 키에 얹으면 헷갈린다(실측 지적: "내려놓기도 필요해 보임").
func put_down_item() -> void:
	if _held_item:
		_held_item.put_down()
		did_interact.emit("내려놓음")
		_held_item = null
	else:
		did_interact.emit("들고 있는 거 없음")


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
	Audio.play_sfx("pickup")
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


## §3.4 세이브 시스템(SaveManager)이 그대로 저장/복원하는 스냅샷. 방패on/off·현재
## 들고있는 투척물처럼 순간적인 상태는 제외 - 다시 시작해도 자연스럽게 리셋되면 됨.
func get_save_data() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y],
		"hearts": hearts,
		"max_hearts": max_hearts,
		"current_tool": current_tool,
		"inventory": inventory.to_dict(),
	}


## JSON을 거쳐온 데이터는 정수도 float로 들어오므로(Godot JSON 파서 특성),
## 인벤토리 수량·도구 enum처럼 int가 필요한 값은 명시적으로 int() 변환한다.
func apply_save_data(data: Dictionary) -> void:
	var pos: Array = data.get("position", [])
	if pos.size() == 2:
		global_position = Vector2(pos[0], pos[1])
	max_hearts = data.get("max_hearts", max_hearts)
	hearts = data.get("hearts", hearts)
	current_tool = int(data.get("current_tool", current_tool))

	var raw_inventory: Dictionary = data.get("inventory", {})
	var int_inventory: Dictionary = {}
	for item_id in raw_inventory:
		int_inventory[item_id] = int(raw_inventory[item_id])
	inventory.from_dict(int_inventory)
