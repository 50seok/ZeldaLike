class_name ReactionRule
extends Resource

## 반응 규칙표(§2.1) 한 줄. NONE = 와일드카드. affects_x=false면 그쪽 액터는 건드리지 않음
## (양쪽 다 매칭에 쓰이므로 순서 상관없이 접촉하면 성립).
##
## 타입은 int로 선언한다 — ChemTypes의 enum을 값(ChemTypes.MaterialTag.WOOD 등)으로는 쓰지만
## 다른 스크립트의 nested enum을 타입 힌트로 쓰면 Godot 4.7에서 파싱 오류가 난다(실측 확인).

@export var material_a: int = ChemTypes.MaterialTag.NONE
@export var state_a: int = ChemTypes.State.NONE
@export var material_b: int = ChemTypes.MaterialTag.NONE
@export var state_b: int = ChemTypes.State.NONE

@export var affects_a: bool = false
@export var result_state_a: int = ChemTypes.State.NONE
@export var convert_material_a: int = ChemTypes.MaterialTag.NONE
@export var shock_a: bool = false

@export var affects_b: bool = false
@export var result_state_b: int = ChemTypes.State.NONE
@export var convert_material_b: int = ChemTypes.MaterialTag.NONE
@export var shock_b: bool = false

@export_multiline var description: String = ""


func try_apply(x: ChemActor, y: ChemActor) -> bool:
	if _side_matches(material_a, state_a, x.chem_material, x.state) and _side_matches(material_b, state_b, y.chem_material, y.state):
		_apply(x, affects_a, result_state_a, convert_material_a, shock_a)
		_apply(y, affects_b, result_state_b, convert_material_b, shock_b)
		return true
	if _side_matches(material_a, state_a, y.chem_material, y.state) and _side_matches(material_b, state_b, x.chem_material, x.state):
		_apply(y, affects_a, result_state_a, convert_material_a, shock_a)
		_apply(x, affects_b, result_state_b, convert_material_b, shock_b)
		return true
	return false


func _side_matches(rule_mat: int, rule_state: int, actual_mat: int, actual_state: int) -> bool:
	var mat_ok := rule_mat == ChemTypes.MaterialTag.NONE or rule_mat == actual_mat
	var state_ok := rule_state == ChemTypes.State.NONE or rule_state == actual_state
	return mat_ok and state_ok


func _apply(actor: ChemActor, affects: bool, result_state: int, convert_material: int, shock: bool) -> void:
	if not affects:
		return
	# 재질을 먼저 바꾸고 상태를 나중에 바꾼다 — set_state()가 라벨을 갱신하는데,
	# 순서가 반대면 "재질은 이미 바뀌었지만 라벨은 옛 재질로 갱신"되는 버그가 난다
	# (실측 확인: 얼음이 물로 바뀌었는데 라벨은 "ICE/NONE"으로 남음).
	if convert_material != ChemTypes.MaterialTag.NONE:
		actor.chem_material = convert_material
	actor.set_state(result_state)
	if shock:
		actor.shocked.emit()
