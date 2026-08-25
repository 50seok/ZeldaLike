class_name StoryScreen
extends Node2D

## §3.4 "오프닝/엔딩 = 정지 일러스트 + 텍스트". 그래픽 에셋이 아직 없어(폴리시
## 단계) 배경색 + 텍스트로 슬라이드를 대신한다 - 나중엔 배경에 텍스처만 깔면
## 되는 구조. opening.gd/ending.gd가 slides/next_scene_path만 채워 넣고
## extends StoryScreen으로 재사용한다.

signal finished

@export var slides: Array[Dictionary] = []  # [{bg: Color, text: String}, ...]
@export var next_scene_path: String = ""

var _index := 0
var _label: Label
var _bg: ColorRect


func _ready() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)

	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(_bg)

	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_label.add_theme_font_size_override("font_size", 22)
	ui.add_child(_label)

	var hint := Label.new()
	hint.position = Vector2(20, 600)
	hint.add_theme_font_size_override("font_size", 14)
	hint.text = "Space/Enter로 계속"
	ui.add_child(hint)

	if not slides.is_empty():
		_show_slide()


func _show_slide() -> void:
	var slide: Dictionary = slides[_index]
	_bg.color = slide.get("bg", Color.BLACK)
	_label.text = slide.get("text", "")


func advance() -> void:
	_index += 1
	if _index >= slides.size():
		_finish()
		return
	_show_slide()


func _finish() -> void:
	finished.emit()
	if next_scene_path != "":
		get_tree().change_scene_to_file(next_scene_path)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			advance()
