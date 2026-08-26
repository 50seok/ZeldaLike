class_name PauseMenu
extends CanvasLayer

## §3.1/§4 "일시정지 메뉴(재개/타이틀로)". get_tree().paused를 그대로 써서 게임
## 로직 전체를 멈춘다(각 몬스터/플레이어 스크립트에 개별 일시정지 처리를 넣을
## 필요가 없다 - 엔진 기능 재사용). 이 메뉴 자신만 process_mode=ALWAYS로 둬서
## 멈춘 동안에도 계속 입력을 받는다(자식은 process_mode가 기본 INHERIT라
## 부모를 따라 자동으로 같이 적용됨).

@export var title_scene_path: String = "res://scenes/title/title.tscn"

var _panel: Panel
var _label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_panel = Panel.new()
	_panel.position = Vector2(400, 200)
	_panel.size = Vector2(350, 160)
	add_child(_panel)

	_label = Label.new()
	_label.position = Vector2(20, 20)
	_label.add_theme_font_size_override("font_size", 18)
	_panel.add_child(_label)
	_refresh_label()


func _refresh_label() -> void:
	_label.text = "일시정지\n\nESC: 재개\nT: 타이틀로 나가기\nM: BGM 음량 (%s)" % Audio.bgm_volume_label()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_ESCAPE:
		toggle_pause()
	elif visible and event.keycode == KEY_T:
		go_to_title()
	elif visible and event.keycode == KEY_M:
		Audio.cycle_bgm_volume()
		_refresh_label()


func toggle_pause() -> void:
	if visible:
		resume()
	else:
		open_pause()


func open_pause() -> void:
	visible = true
	get_tree().paused = true


func resume() -> void:
	visible = false
	get_tree().paused = false


func go_to_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(title_scene_path)
