class_name Inventory
extends RefCounted

## §3.3 "데이터 모델은 처음부터 확장형" — 아이템 ID(String) + 수량 딕셔너리.
## MVP UI는 핫바/카운터뿐이지만, 이 구조 그대로 나중에 그리드 인벤토리 UI만
## 얹을 수 있다(§9 Post-MVP). to_dict/from_dict는 세이브 시스템에서 그대로 재사용.

signal changed(item_id: String, count: int)

var _items: Dictionary = {}


func add(item_id: String, amount: int = 1) -> void:
	_items[item_id] = get_count(item_id) + amount
	changed.emit(item_id, _items[item_id])


func remove(item_id: String, amount: int = 1) -> bool:
	var current := get_count(item_id)
	if current < amount:
		return false
	_items[item_id] = current - amount
	changed.emit(item_id, _items[item_id])
	return true


func get_count(item_id: String) -> int:
	return _items.get(item_id, 0)


func to_dict() -> Dictionary:
	return _items.duplicate()


func from_dict(data: Dictionary) -> void:
	_items = data.duplicate()
