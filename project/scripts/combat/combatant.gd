class_name Combatant
extends ChemActor

## 하트(HP)를 가진 화학 오브젝트. 플레이어·몬스터 공통 기반 —
## 화학엔진이 그대로 적용되면서(예: 풀 몬스터는 불에 타 죽음) 전투 피해도 받는다.

signal died
signal damaged(amount: float)

@export var max_hearts: float = 3.0
var hearts: float

## ChemActor의 기본 소각 로직은 "burn_duration이 지나면 하트 수와 무관하게
## 무조건 파괴"라 환경 오브젝트(수풀·무기)엔 맞지만, 하트가 있는 전투 유닛에
## 그대로 적용하면 "불붙으면 무조건 즉사"가 돼버린다(실측 지적: "불탔을때
## 피격 대미지가 너무 강함, 무조건 죽는게 하드함"). 기본값은 지속피해로 바꾸고,
## §4.1 "덩굴이"처럼 "불=즉시 소멸"이 의도된 연출인 경우만 켜서 예전 동작을 쓴다.
@export var burn_kills_instantly: bool = false
@export var burn_damage_per_tick: float = 1.0
@export var burn_tick_interval: float = 1.0

var _burn_tick_timer := 0.0


func _ready() -> void:
	super._ready()
	hearts = max_hearts


func _process(delta: float) -> void:
	if state != ChemTypes.State.BURNING or chem_material not in FLAMMABLE:
		_burn_tick_timer = 0.0
		return

	if burn_kills_instantly:
		_burn_timer += delta
		if _burn_timer >= burn_duration:
			burned_out.emit()
			perform_drops()
			_on_destroyed()
		return

	_burn_tick_timer += delta
	if _burn_tick_timer >= burn_tick_interval:
		_burn_tick_timer -= burn_tick_interval
		take_damage(burn_damage_per_tick)

	_burn_timer += delta
	if _burn_timer >= burn_duration:
		burned_out.emit()
		set_state(ChemTypes.State.NONE)


func take_damage(amount: float) -> void:
	if hearts <= 0.0:
		return
	hearts = max(0.0, hearts - amount)
	Audio.play_sfx("hit")
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
