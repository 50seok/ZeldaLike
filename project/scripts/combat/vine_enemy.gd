class_name VineEnemy
extends Combatant

## §4.1 "덩굴이" — 가장 단순한 몬스터. 발견하면 직선 돌진, 접촉 피해.
## AI는 PRD 방침대로 단순 FSM(대기/추적)이고, 화학(풀+불=즉사)은 코드 없이 이미 동작한다.

enum AIState { IDLE, CHASE }

@export var move_speed: float = 60.0
@export var detect_radius: float = 120.0
@export var contact_damage: float = 0.75  # 밸런싱(M5-우선순위4, 실측 지적 "너무 쉬움") - 0.5→0.75
@export var contact_cooldown: float = 1.0
## "방"이 실제 벽이 아니라 카메라 존일 뿐이라(§4.2), 한 번 쫓아오기 시작하면
## 끝없이 따라와 옆방까지 넘어올 수 있었다(실측 지적: "몬스터들은 따라오지
## 못하게 해야할듯" - 보스 페이즈2가 소환하는 덩굴이가 보스방 밖으로 새는 경우).
## 스폰 지점에서 이 거리 밖으로는 추적해도 실제로 움직이지 않는다("목줄").
@export var leash_distance: float = 300.0

var _state: AIState = AIState.IDLE
var _player: Node2D
var _cooldown_left := 0.0
var _spawn_position: Vector2


func _ready() -> void:
	super._ready()
	chem_material = ChemTypes.MaterialTag.GRASS
	max_hearts = 1.0
	hearts = 1.0
	burn_duration = 0.4  # "불에 즉시 연소 사망" 체감 — 다른 재질보다 짧게
	burn_kills_instantly = true  # §4.1 "덩굴이" = 불에 태우면 하트 수 무관 즉시 소멸(의도된 연출)
	display_name = "덩굴이"
	sprite_texture = SpriteUtil.tile(SpriteUtil.TINY_CREATURES, 76, SpriteUtil.TINY_CREATURES_COLS)
	add_to_group("combatant_enemies")
	_setup_drops()
	_spawn_position = global_position


## §3.3 수풀 예시 그대로: 기본 파괴=하트/화살 20%, 태워 죽이면 드랍 없음(재만 남음).
func _setup_drops() -> void:
	var table := DropTable.new()
	var heart_drop := DropEntry.new()
	heart_drop.item_id = ItemIds.HEART
	heart_drop.chance = 0.2
	var arrow_drop := DropEntry.new()
	arrow_drop.item_id = ItemIds.ARROW
	arrow_drop.chance = 0.2
	table.default_drops = [heart_drop, arrow_drop]
	drop_table = table


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
		if global_position.distance_to(_spawn_position) < leash_distance:
			position += to_player.normalized() * move_speed * delta

	# 접촉 피해는 "아직 다가가는 중"과 무관하게 확인한다 — 이동 조건 안에 넣으면
	# 완전히 겹친 순간(거리<=1.0) 피해 판정 자체가 멈추는 버그가 생긴다(실측 확인).
	if _state == AIState.CHASE and to_player.length() < 24.0 and _cooldown_left <= 0.0 and _player.has_method("take_damage"):
		_player.take_damage(contact_damage)
		_cooldown_left = contact_cooldown
