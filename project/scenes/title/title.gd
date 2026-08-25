extends Node2D

## §4 타이틀 화면(새 게임/이어하기). 그래픽 에셋이 아직 없어(폴리시 단계)
## 텍스트로만 구성 - 나중엔 배경 일러스트만 얹으면 되는 구조.
## 실제 던전 연결(우선순위5) 전까지는 world_test.tscn을 "메인 게임"으로 삼는다.

@export var main_game_scene_path: String = "res://scenes/world_test/world_test.tscn"

var _label: Label


func _ready() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)

	_label = Label.new()
	_label.position = Vector2(300, 200)
	_label.add_theme_font_size_override("font_size", 26)
	ui.add_child(_label)
	_refresh_label()


func _refresh_label() -> void:
	var continue_line := "C: 이어하기" if SaveManager.has_save() else "(저장된 게임 없음)"
	_label.text = "ZeldaLike (가제)\n\nEnter: 새 게임\n%s" % continue_line


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		start_new_game()
	elif event.keycode == KEY_C and SaveManager.has_save():
		continue_game()


## 실제 씬 전환과 분리해둔 이유 - 자동테스트가 "새 게임 시작 시 상태가 제대로
## 초기화되는지"만 검증하고 싶을 때, 씬 전환(change_scene_to_file)까지 실제로
## 트리거하면 테스트 씬 자신이 통째로 갈아치워져 버린다.
func prepare_new_game() -> void:
	SaveManager.delete_save()
	StoryFlags.reset()


func start_new_game() -> void:
	prepare_new_game()
	get_tree().change_scene_to_file(main_game_scene_path)


func continue_game() -> void:
	get_tree().change_scene_to_file(main_game_scene_path)
