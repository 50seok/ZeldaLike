class_name Ember
extends Combatant

## §4.1 "엠버" — 불꽃체(재질 없음), 거리를 유지하며 불덩이를 쏜다. 불덩이는
## Arrow를 그대로 재사용(재질 WOOD+BURNING)해서 맞은 대상을 자동 착화시킨다
## (플레이어의 나무 장비가 타는 유일한 적 — §2.4 화학 그대로 재사용).
## 물(WATER 재질)에 맞으면 즉사 — 이건 일반 반응표에 넣기엔 "전투 결과"라
## 여기서 직접 처리한다.

@export var move_speed: float = 26.0
@export var keep_distance: float = 150.0
@export var fire_cooldown: float = 2.0
@export var fireball_damage: float = 0.5
@export var detect_radius: float = 260.0

var _player: Node2D
var _cooldown := 0.0


func _ready() -> void:
	super._ready()
	chem_material = ChemTypes.MaterialTag.NONE
	max_hearts = 1.0
	hearts = 1.0
	display_name = "엠버"
	add_to_group("combatant_enemies")
	_setup_drops()


func _setup_drops() -> void:
	var table := DropTable.new()
	var heart_drop := DropEntry.new()
	heart_drop.item_id = ItemIds.HEART
	heart_drop.chance = 0.3
	table.default_drops = [heart_drop]
	drop_table = table


func _physics_process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta

	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return

	var to_player: Vector2 = _player.global_position - global_position
	var dist := to_player.length()
	if dist > detect_radius:
		return

	if dist < keep_distance - 20.0:
		position -= to_player.normalized() * move_speed * delta
	elif dist > keep_distance + 20.0:
		position += to_player.normalized() * move_speed * delta

	if _cooldown <= 0.0:
		_fire_at(to_player.normalized())
		_cooldown = fire_cooldown


func _fire_at(direction: Vector2) -> void:
	var fireball := Arrow.new()
	fireball.shooter = self
	fireball.direction = direction
	fireball.damage = fireball_damage
	fireball.chem_material = ChemTypes.MaterialTag.WOOD
	fireball.global_position = global_position + direction * 20.0
	get_parent().add_child(fireball)
	fireball.set_state(ChemTypes.State.BURNING)


func _on_area_entered(other: Area2D) -> void:
	if other is ChemActor and other.chem_material == ChemTypes.MaterialTag.WATER:
		perform_drops()
		_on_destroyed()
		return
	super._on_area_entered(other)
