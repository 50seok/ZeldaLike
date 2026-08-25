class_name DialogueBox
extends CanvasLayer

## §3.2/3.4 대화박스(타자 효과, 분기 없음). NPC.talk()이 start()를 호출하면
## 한 줄씩 타자 효과로 보여주고, advance()(상호작용 키)로 즉시완성/다음줄/닫기.

signal closed

@export var chars_per_sec: float = 30.0

var _label: Label
var _name_label: Label
var _lines: Array[String] = []
var _line_index := 0
var _timer := 0.0
var _revealing := false


func _ready() -> void:
	visible = false

	var panel := Panel.new()
	panel.position = Vector2(40, 480)
	panel.size = Vector2(600, 100)
	add_child(panel)

	_name_label = Label.new()
	_name_label.position = Vector2(16, 8)
	_name_label.add_theme_font_size_override("font_size", 16)
	panel.add_child(_name_label)

	_label = Label.new()
	_label.position = Vector2(16, 32)
	_label.size = Vector2(560, 60)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_label.add_theme_font_size_override("font_size", 16)
	panel.add_child(_label)


func start(speaker: String, lines: Array[String]) -> void:
	_name_label.text = speaker
	_lines = lines
	_line_index = 0
	visible = true
	_show_current_line()


func _show_current_line() -> void:
	_timer = 0.0
	_revealing = true
	_label.text = ""


func _process(delta: float) -> void:
	if not _revealing:
		return
	var full := _lines[_line_index]
	_timer += delta
	var char_count: int = min(int(_timer * chars_per_sec), full.length())
	_label.text = full.substr(0, char_count)
	if char_count >= full.length():
		_revealing = false


## 상호작용 키로 호출 - 타자 진행 중이면 즉시 완성, 이미 완성됐으면 다음 줄로
## (마지막 줄이면 닫기).
func advance() -> void:
	if not visible:
		return
	if _revealing:
		_label.text = _lines[_line_index]
		_revealing = false
		return
	_line_index += 1
	if _line_index >= _lines.size():
		visible = false
		closed.emit()
		return
	_show_current_line()


func is_open() -> bool:
	return visible


func get_visible_text() -> String:
	return _label.text
