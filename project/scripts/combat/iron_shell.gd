class_name IronShell
extends Combatant

## §4.1 "아이언셸" — 중장갑 몹. 평소엔 칼 공격이 튕겨 나가고(무효), 물+전기 콤보로
## 감전(shocked, ChemActor/반응표에 이미 있는 신호 재사용)됐을 때만 스턴 상태로
## 전투 피해가 들어간다 — 보스전 콤보(§3.5)의 예행연습.

@export var move_speed: float = 25.0
@export var contact_damage: float = 1.0
@export var contact_cooldown: float = 1.0
@export var stun_duration: float = 3.0

var _player: Node2D
var _contact_cooldown_left := 0.0
var _stun_timer := 0.0


func _ready() -> void:
	super._ready()
	chem_material = ChemTypes.MaterialTag.METAL
	max_hearts = 3.0
	hearts = 3.0
	display_name = "아이언셸"
	add_to_group("combatant_enemies")
	_setup_drops()
	shocked.connect(_on_shocked)


## MVP는 폐허 개체(화살 5) 기준 — 던전 배치 개체는 스폰 시 drop_table을
## 작은 열쇠 확정 테이블로 덮어쓰면 된다(§4.1, 데이터만 교체).
func _setup_drops() -> void:
	var table := DropTable.new()
	var arrow_drop := DropEntry.new()
	arrow_drop.item_id = ItemIds.ARROW
	arrow_drop.chance = 1.0
	arrow_drop.min_count = 5
	arrow_drop.max_count = 5
	table.default_drops = [arrow_drop]
	drop_table = table


func _on_shocked() -> void:
	_stun_timer = stun_duration


func is_stunned() -> bool:
	return _stun_timer > 0.0


func take_damage(amount: float) -> void:
	if not is_stunned():
		return
	super.take_damage(amount)


func _physics_process(delta: float) -> void:
	if _stun_timer > 0.0:
		_stun_timer -= delta
		return

	if _contact_cooldown_left > 0.0:
		_contact_cooldown_left -= delta

	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return

	var to_player: Vector2 = _player.global_position - global_position
	if to_player.length() > 20.0:
		position += to_player.normalized() * move_speed * delta
	if to_player.length() < 28.0 and _contact_cooldown_left <= 0.0 and _player.has_method("take_damage"):
		_player.take_damage(contact_damage)
		_contact_cooldown_left = contact_cooldown
