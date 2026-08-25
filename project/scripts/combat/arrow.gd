class_name Arrow
extends ChemActor

## 활 화살. 명중 시 전투 피해는 여기서 직접 주고, 화학 반응(불화살이 착화시키는 등)은
## ChemActor의 기존 접촉 처리를 그대로 상속해서 얻는다 — 원소 화살 = 코드 추가가 아니라
## chem_material/state를 다르게 세팅해서 쏘는 것뿐 (§2.1 데이터 주도 원칙).

@export var speed: float = 400.0
@export var damage: float = 1.0

var direction: Vector2 = Vector2.RIGHT
var shooter: Node = null


func _ready() -> void:
	# box_size는 super._ready()가 충돌 shape를 만들기 전에 정해야 한다 —
	# 순서가 반대면 화살이 기본 32x32 크기로 만들어져(실측 확인, 플레이어 자신도
	# 쏘자마자 맞을 만큼 큼) 의도한 작은 화살 판정이 적용되지 않는다.
	box_size = Vector2(14, 6)
	super._ready()


func _physics_process(delta: float) -> void:
	position += direction * speed * delta


func _on_area_entered(other: Area2D) -> void:
	if other == shooter:
		return
	super._on_area_entered(other)
	if other is Combatant:
		other.take_damage(damage)
		queue_free()
	elif other is ChemActor:
		queue_free()
