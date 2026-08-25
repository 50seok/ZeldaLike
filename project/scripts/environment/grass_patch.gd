class_name GrassPatch
extends ChemActor

## §4.2 초원 필드의 "수풀 다수" — 몬스터가 아니라 환경 오브젝트라 HP 없이
## 한 방에 파괴된다. 칼로 베거나(cut_down) 불태우면(ChemActor 소각 로직 그대로)
## §3.3 수풀 예시(기본 20%/20%, 태우면 없음) 드랍이 적용된다.

func _ready() -> void:
	super._ready()
	chem_material = ChemTypes.MaterialTag.GRASS
	burn_duration = 0.4
	add_to_group("cuttable_props")
	_setup_drops()


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


func cut_down() -> void:
	perform_drops()
	_on_destroyed()
