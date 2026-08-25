class_name Hotbar
extends Control

## §3.3 "MVP UI는 핫바(도구 전환) + 카운터(열쇠·화살·하트조각)만". 그래픽 에셋이
## 아직 없어(Kenney 도입은 폴리시 단계) 도구는 색상 사각형으로 대신 그린다 -
## 나중엔 텍스처만 교체하면 되는 구조.

var player: Player

const BOX_SIZE := 32.0
const BOX_GAP := 6.0

const TOOL_ORDER: Array = [Player.ToolType.NORMAL, Player.ToolType.FIRE, Player.ToolType.ELECTRIC]
const TOOL_COLORS := {
	Player.ToolType.NORMAL: Color(0.7, 0.7, 0.7),
	Player.ToolType.FIRE: Color(1.0, 0.4, 0.0),
	Player.ToolType.ELECTRIC: Color(1.0, 1.0, 0.2),
}
const TOOL_LABELS := {
	Player.ToolType.NORMAL: "일반",
	Player.ToolType.FIRE: "불",
	Player.ToolType.ELECTRIC: "전기",
}

var _counter_label: Label


func _ready() -> void:
	custom_minimum_size = Vector2(TOOL_ORDER.size() * (BOX_SIZE + BOX_GAP), BOX_SIZE + 44)

	for i in range(TOOL_ORDER.size()):
		var tool = TOOL_ORDER[i]
		var caption := Label.new()
		caption.position = Vector2(i * (BOX_SIZE + BOX_GAP), BOX_SIZE + 2)
		caption.add_theme_font_size_override("font_size", 12)
		caption.text = TOOL_LABELS[tool]
		add_child(caption)

	_counter_label = Label.new()
	_counter_label.position = Vector2(0, BOX_SIZE + 22)
	_counter_label.add_theme_font_size_override("font_size", 14)
	add_child(_counter_label)


func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	queue_redraw()
	_counter_label.text = "화살 %d · 작은열쇠 %d · 보스열쇠 %d · 하트조각 %d" % [
		player.inventory.get_count(ItemIds.ARROW),
		player.inventory.get_count(ItemIds.SMALL_KEY),
		player.inventory.get_count(ItemIds.BOSS_KEY),
		player.inventory.get_count(ItemIds.HEART_PIECE),
	]


func _draw() -> void:
	if not is_instance_valid(player):
		return
	for i in range(TOOL_ORDER.size()):
		var tool = TOOL_ORDER[i]
		var x := i * (BOX_SIZE + BOX_GAP)
		draw_rect(Rect2(x, 0, BOX_SIZE, BOX_SIZE), TOOL_COLORS[tool])
		var selected: bool = tool == player.current_tool
		draw_rect(Rect2(x, 0, BOX_SIZE, BOX_SIZE), Color.WHITE if selected else Color.BLACK, false, 3.0 if selected else 1.5)


## 자동테스트용 - _draw()는 픽셀 검사 없인 확인이 안 되니, 어느 칸이 선택됐는지를
## 코드로도 조회 가능하게 노출한다.
func get_selected_index() -> int:
	if not is_instance_valid(player):
		return -1
	return TOOL_ORDER.find(player.current_tool)
