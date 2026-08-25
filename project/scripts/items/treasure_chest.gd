class_name TreasureChest
extends Area2D

## §3.3/§4 "보물상자" - 접근해서 Space로 열면 아이템을 즉시 지급한다. 획득 연출
## (치켜들기+팡파레, §3.2)은 그래픽이 없는 지금 단계에선 생략하고 로그로 대신
## - 폴리시 단계(M5)에서 연출만 얹으면 된다. 한 번 열면 다시 못 연다.

@export var item_id: String = ""
@export var count: int = 1
@export var box_size: Vector2 = Vector2(24, 20)

var opened := false


func _ready() -> void:
	monitoring = false
	monitorable = true
	collision_layer = 1
	collision_mask = 1

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = box_size
	shape.shape = rect
	add_child(shape)

	queue_redraw()


func _draw() -> void:
	var color := Color(0.3, 0.3, 0.3) if opened else Color(0.6, 0.45, 0.1)
	draw_rect(Rect2(-box_size / 2, box_size), color)
	draw_rect(Rect2(-box_size / 2, box_size), Color.BLACK, false, 2.0)


func open(player: Node) -> bool:
	if opened:
		return false
	opened = true
	queue_redraw()
	if player.has_method("collect_item"):
		player.collect_item(item_id, count)
	return true
