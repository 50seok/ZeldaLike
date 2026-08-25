class_name Combatant
extends ChemActor

## 하트(HP)를 가진 화학 오브젝트. 플레이어·몬스터 공통 기반 —
## 화학엔진이 그대로 적용되면서(예: 풀 몬스터는 불에 타 죽음) 전투 피해도 받는다.

signal died
signal damaged(amount: float)

@export var max_hearts: float = 3.0
var hearts: float


func _ready() -> void:
	super._ready()
	hearts = max_hearts


func take_damage(amount: float) -> void:
	if hearts <= 0.0:
		return
	hearts = max(0.0, hearts - amount)
	damaged.emit(amount)
	if hearts <= 0.0:
		died.emit()
		perform_drops()
		queue_free()
