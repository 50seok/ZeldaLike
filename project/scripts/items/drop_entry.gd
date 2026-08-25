class_name DropEntry
extends Resource

## 드랍 테이블 한 줄. §3.3 드랍 규칙표 형식(아이템, 확률)을 그대로 데이터로.

@export var item_id: String = ""
@export_range(0.0, 1.0) var chance: float = 1.0
@export var min_count: int = 1
@export var max_count: int = 1


func roll_count() -> int:
	if min_count >= max_count:
		return min_count
	return randi_range(min_count, max_count)
