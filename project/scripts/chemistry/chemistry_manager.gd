extends Node

## 오토로드. 반응 규칙표를 로드해두고, 접촉한 두 ChemActor를 규칙표에 조회해 적용한다.
## §2.1: 반응은 하드코딩 분기가 아니라 이 조회 하나로만 결정된다.

const TABLE_PATH := "res://resources/reactions/mvp_reaction_table.tres"

var reaction_table: ReactionTable


func _ready() -> void:
	reaction_table = load(TABLE_PATH)
	if reaction_table == null:
		push_error("ChemistryManager: 반응 규칙표를 찾을 수 없습니다 - %s" % TABLE_PATH)


func resolve_contact(a: ChemActor, b: ChemActor) -> bool:
	if reaction_table == null:
		return false
	if not is_instance_valid(a) or not is_instance_valid(b):
		return false
	for rule in reaction_table.rules:
		if rule.try_apply(a, b):
			return true
	return false
