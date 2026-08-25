class_name WoodGuard
extends Combatant

## §4.1 "우드가드" — 나무 방패를 든 몹. 몸통은 "일반"(비반응) 재질, 방패만 WOOD라
## 화학엔진 그대로 적용된다: 불화살이 방패에 닿으면 착화->소각(EquippedWeapon과
## 동일 패턴 재사용)돼서 무방비가 된다. 방패가 있는 동안은 전투 피해를 아예 무효화.

@export var move_speed: float = 40.0
@export var detect_radius: float = 140.0
@export var stop_distance: float = 36.0

var _player: Node2D
var _shield: EquippedWeapon


func _ready() -> void:
	super._ready()
	chem_material = ChemTypes.MaterialTag.NONE
	max_hearts = 2.0
	hearts = 2.0
	display_name = "우드가드"
	add_to_group("combatant_enemies")
	_setup_drops()
	_spawn_shield()


func _setup_drops() -> void:
	var table := DropTable.new()
	var arrow_drop := DropEntry.new()
	arrow_drop.item_id = ItemIds.ARROW
	arrow_drop.chance = 0.5
	table.default_drops = [arrow_drop]
	var heart_drop := DropEntry.new()
	heart_drop.item_id = ItemIds.HEART
	heart_drop.chance = 0.5
	table.burning_drops = [heart_drop]
	drop_table = table


func _spawn_shield() -> void:
	_shield = EquippedWeapon.new()
	_shield.chem_material = ChemTypes.MaterialTag.WOOD
	_shield.display_name = "방패"
	_shield.box_size = Vector2(14, 22)
	_shield.burn_duration = 2.0
	_shield.position = Vector2(20, 0)
	add_child(_shield)
	_shield.weapon_destroyed.connect(func(): _shield = null)


## 방패가 살아있으면 전투 피해를 아예 무효화한다.
## ponytail: PRD는 "정면 공격 반사/뒤로 돌아 베기"까지 언급하지만, 방향 판정에
## 필요한 몸 회전·시야각 계산은 이번 스코프에서 생략 — 방패 유무로만 단순화.
## 뒤쪽 공격을 구분해야 할 필요가 실제로 생기면(플레이테스트 피드백 등) 추가.
func take_damage(amount: float) -> void:
	if _shield != null and is_instance_valid(_shield):
		return
	super.take_damage(amount)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return
	var to_player: Vector2 = _player.global_position - global_position
	if to_player.length() <= detect_radius and to_player.length() > stop_distance:
		position += to_player.normalized() * move_speed * delta
