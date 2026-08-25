class_name ChaosCore
extends Combatant

## §3.5/§4.1 보스 "혼돈의 코어". §4.1 명시대로 하트 표시 없음 - 아이언셸에서
## 검증한 스턴 격파 콤보(물+전기 → 감전 스턴 → 스턴 중 공격 1회 = 페이즈 진행)를
## 3회 반복해야 격파된다. 감전(shocked 신호)은 재질 무관 반응표를 그대로 재사용
## (material_a/b가 둘 다 wildcard라 chem_material=NONE인 보스에도 그대로 적용됨) -
## 새 반응규칙 0개. 스턴당 유효 타격은 1회뿐 - 연속 콤보로 한 번에 다 못 넘기게
## 스턴을 즉시 소모하고, 다음 타격 전엔 다시 물+전기를 걸어야 한다.

signal phase_changed(new_phase: int)
signal defeated

enum Phase { ONE, TWO, THREE }

@export var move_speed: float = 20.0
@export var fireball_cooldown: float = 2.0
@export var fireball_damage: float = 0.5
@export var stun_duration: float = 3.0
@export var chase_distance: float = 60.0
## dungeon_test.tscn의 실제 보스방(800x600)에 보스를 방 정중앙에 두면, 가장
## 가까운 옆방과의 벽까지 거리가 400이다 - 650은 그보다 커서 옆방까지 계속
## 새어나갔다(실측 재확인: "문 고치니 다시 옆방 몬스터가 공격함" - 문 자체
## 문제가 아니라 감지범위가 방 하나보다 컸던 게 원인). 400보다 확실히 작은
## 값으로 낮춘다 - boss_test.tscn의 물웅덩이(거리~390)에서도 잠깐 안전해지는
## 효과가 생기지만, 그건 자원 보충 지점이 안전해지는 거라 오히려 자연스럽다.
@export var detect_radius: float = 380.0

var phase: Phase = Phase.ONE
var hit_count: int = 0

var _player: Node2D
var _fire_cooldown_left := 0.0
var _stun_timer := 0.0


func _ready() -> void:
	super._ready()
	chem_material = ChemTypes.MaterialTag.NONE
	display_name = "혼돈의 코어"
	max_hearts = 1.0  # 실제 격파 판정엔 안 쓰임 - take_damage를 hit_count 기반으로 완전히 대체
	hearts = 1.0
	add_to_group("combatant_enemies")
	shocked.connect(_on_shocked)


func _on_shocked() -> void:
	_stun_timer = stun_duration


func is_stunned() -> bool:
	return _stun_timer > 0.0


func take_damage(_amount: float) -> void:
	if not is_stunned():
		return
	_stun_timer = 0.0
	hit_count += 1
	if hit_count >= 3:
		_defeat()
		return
	phase = hit_count
	phase_changed.emit(phase)
	if phase == Phase.TWO:
		_enter_phase_two()
	_update_label()


## §4.1 "바닥 일부를 FROZEN으로 얼림 + 덩굴이 2마리 소환". 얼음 장애물의
## "이동 제한" 연출은 스코프 최소화를 위해 생략한다(ponytail: 실제 완주 테스트에서
## 답답하면 그때 Door와 같은 차단 방식을 얼음에도 붙인다) - 얼음이 보스 자신의
## 불덩이로도 녹는다는 화학 상호작용(§4.1)은 반응표 재사용이라 별도 코드 불필요.
func _enter_phase_two() -> void:
	for i in range(2):
		var vine := VineEnemy.new()
		vine.global_position = global_position + Vector2(50 if i == 0 else -50, 40)
		get_parent().add_child(vine)


func _defeat() -> void:
	defeated.emit()
	queue_free()


func _physics_process(delta: float) -> void:
	if _stun_timer > 0.0:
		_stun_timer -= delta
		return

	if _fire_cooldown_left > 0.0:
		_fire_cooldown_left -= delta

	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return

	var to_player: Vector2 = _player.global_position - global_position
	# "방"이 실제 벽이 아니라 카메라 존일 뿐이라(§4.2), 감지 범위가 없으면 플레이어가
	# 몇 개 방 떨어져 있어도 계속 조준+사격해서 화염구가 문/벽을 그냥 관통해 다른
	# 방까지 날아가 버렸다(실측 확인: 전기 스위치 방에 있는데 보스방 화염구에 맞음).
	if to_player.length() > detect_radius:
		return

	var speed_mult := 1.5 if phase == Phase.THREE else 1.0
	if to_player.length() > chase_distance:
		position += to_player.normalized() * move_speed * speed_mult * delta

	var cooldown_mult := 0.5 if phase == Phase.THREE else 1.0
	if _fire_cooldown_left <= 0.0:
		var dir := to_player.normalized() if to_player.length() > 0.0 else Vector2.DOWN
		_fire_at(dir)
		_fire_cooldown_left = fireball_cooldown * cooldown_mult


## §4.1 "페이즈1: 불덩이 탄막(엠버 패턴 확장)" - Ember의 화염구 코드 그대로 재사용.
func _fire_at(direction: Vector2) -> void:
	var fireball := Arrow.new()
	fireball.shooter = self
	fireball.direction = direction
	fireball.damage = fireball_damage
	fireball.chem_material = ChemTypes.MaterialTag.WOOD
	fireball.global_position = global_position + direction * 20.0
	get_parent().add_child(fireball)
	fireball.set_state(ChemTypes.State.BURNING)


## §4.1 "하트 표시 없음" - Combatant의 HP 라벨을 격파 진행도로 대체한다.
func _update_label() -> void:
	var mat_name: String = ChemTypes.MaterialTag.keys()[chem_material]
	var state_name: String = ChemTypes.State.keys()[state]
	_label.text = "%s\n%s/%s\n격파 진행 %d/3" % [display_name, mat_name, state_name, hit_count]
