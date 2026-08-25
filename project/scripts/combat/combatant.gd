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
	_update_label()
	if hearts <= 0.0:
		perform_drops()
		_on_destroyed()


func _on_destroyed() -> void:
	died.emit()
	super._on_destroyed()


## 재질/상태 라벨만으로는 적 체력이 화면에 안 보여 피해가 들어가는지 확인할
## 방법이 없었다(실측 지적: "적은 하트가 없으니까 확인을 못하는데?").
func _update_label() -> void:
	super._update_label()
	_label.text += "\nHP %.0f/%.0f" % [hearts, max_hearts]
