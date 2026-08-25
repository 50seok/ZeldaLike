class_name VineEnemy
extends Combatant

## §4.1 "덩굴이" — 가장 단순한 몬스터. 발견하면 직선 돌진, 접촉 피해.
## AI는 PRD 방침대로 단순 FSM(대기/추적)이고, 화학(풀+불=즉사)은 코드 없이 이미 동작한다.

enum AIState { IDLE, CHASE }

@export var move_speed: float = 60.0
@export var detect_radius: float = 120.0
@export var contact_damage: float = 0.5
@export var contact_cooldown: float = 1.0

var _state: AIState = AIState.IDLE
var _player: Node2D
var _cooldown_left := 0.0


func _ready() -> void:
	super._ready()
	chem_material = ChemTypes.MaterialTag.GRASS
	max_hearts = 1.0
	hearts = 1.0
	burn_duration = 0.4  # "불에 즉시 연소 사망" 체감 — 다른 재질보다 짧게
	display_name = "덩굴이"
	add_to_group("combatant_enemies")


func _physics_process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left -= delta

	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return

	var to_player: Vector2 = _player.global_position - global_position
	if to_player.length() <= detect_radius:
		_state = AIState.CHASE

	if _state == AIState.CHASE and to_player.length() > 1.0:
		position += to_player.normalized() * move_speed * delta
		if to_player.length() < 24.0 and _cooldown_left <= 0.0 and _player.has_method("take_damage"):
			_player.take_damage(contact_damage)
			_cooldown_left = contact_cooldown
