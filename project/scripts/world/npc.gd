class_name NPC
extends Area2D

## §3.4 NPC 두 계층 공통 기반.
## - 기능 NPC(촌장 등): sets_flag로 진행 게이트를 연다.
## - 주민 NPC(플레이버): requires_flag가 세워져 있으면 대사가 alt_lines로 1회 교체된다
##   (분기 없음, 선형 - PRD §3.4 "각 1~2줄×2벌").
## 화학엔진과는 무관해서 ChemActor가 아니라 Area2D를 직접 상속한다(반응표 조회 대상
## 아님 - 플레이어가 접촉 판정만 쓰면 되므로).

@export var npc_name: String = "주민"
@export var lines: Array[String] = ["..."]
@export var alt_lines: Array[String] = []
@export var requires_flag: String = ""
@export var sets_flag: String = ""
@export var box_size: Vector2 = Vector2(28, 28)


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

	var label := Label.new()
	label.position = Vector2(-box_size.x / 2, -box_size.y / 2 - 20)
	label.add_theme_font_size_override("font_size", 12)
	label.text = npc_name
	add_child(label)

	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-box_size / 2, box_size), Color(0.8, 0.7, 0.3))
	draw_rect(Rect2(-box_size / 2, box_size), Color.BLACK, false, 2.0)


func talk(dialogue_box: DialogueBox) -> void:
	var current_lines := lines
	if requires_flag != "" and StoryFlags.has_flag(requires_flag) and not alt_lines.is_empty():
		current_lines = alt_lines
	dialogue_box.start(npc_name, current_lines)
	await dialogue_box.closed
	if sets_flag != "":
		StoryFlags.set_flag(sets_flag)
