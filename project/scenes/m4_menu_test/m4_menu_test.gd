extends Node2D

## M4 우선순위2 검증: 일시정지 메뉴(§3.1/§4) + 타이틀 화면(§4, 새 게임/이어하기).
## 실제 씬 전환(change_scene_to_file)은 테스트 자신의 트리를 갈아치우므로
## 트리거하지 않고, 상태 준비/토글 로직만 직접 호출해 확인한다.

const TEST_SAVE_PATH := "user://test_savegame_menu.json"

@onready var _label: Label = $DebugLabel

var _log: Array[String] = []
var _pass_count := 0
var _fail_count := 0


func _ready() -> void:
	await get_tree().process_frame
	var original_path := SaveManager.save_path
	SaveManager.save_path = TEST_SAVE_PATH
	await _run_all_tests()
	SaveManager.save_path = original_path
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
	_print_summary()


func _check(label: String, condition: bool) -> void:
	if condition:
		_pass_count += 1
		_log.append("[PASS] %s" % label)
	else:
		_fail_count += 1
		_log.append("[FAIL] %s" % label)
	_refresh_label()


func _refresh_label() -> void:
	_label.text = "\n".join(_log)


func _run_all_tests() -> void:
	await _test_pause_toggle()
	await _test_title_new_game_vs_continue()


func _test_pause_toggle() -> void:
	var menu := PauseMenu.new()
	add_child(menu)
	await get_tree().process_frame

	_check("A 초기 상태 -> 메뉴 안 보임, 게임 정지 아님", not menu.visible and not get_tree().paused)

	menu.toggle_pause()
	_check("A ESC(토글) -> 메뉴 표시+게임 정지", menu.visible and get_tree().paused)

	menu.toggle_pause()
	_check("A 다시 토글 -> 메뉴 숨김+게임 재개", not menu.visible and not get_tree().paused)

	# go_to_title()은 실제 씬 전환을 안 걸어보고, 대상 경로가 유효한지만 확인.
	_check("A 타이틀 씬 경로가 실제로 존재함", ResourceLoader.exists(menu.title_scene_path))

	menu.queue_free()
	get_tree().paused = false  # 혹시 남아있으면 이후 테스트에 영향 없게 원복
	await get_tree().create_timer(0.1).timeout


func _test_title_new_game_vs_continue() -> void:
	var title := Node2D.new()
	title.set_script(load("res://scenes/title/title.gd"))
	add_child(title)
	await get_tree().process_frame

	StoryFlags.set_flag("menu_test_flag")
	var dummy_player := Player.new()
	SaveManager.save_game(dummy_player)  # 저장 파일이 실제로 존재하는 상태를 만든다
	dummy_player.free()

	title._refresh_label()
	_check("B 저장 있음 -> 라벨에 이어하기 안내", title._label.text.contains("이어하기"))

	title.prepare_new_game()
	_check("B 새 게임 준비 -> 저장 삭제됨", not SaveManager.has_save())
	_check("B 새 게임 준비 -> 스토리 플래그 초기화됨", not StoryFlags.has_flag("menu_test_flag"))

	title._refresh_label()
	_check("B 저장 없음 -> 라벨에 안내 문구", title._label.text.contains("저장된 게임 없음"))

	title.queue_free()
	await get_tree().create_timer(0.1).timeout


func _print_summary() -> void:
	var summary := "=== M4 메뉴(일시정지/타이틀) 검증: PASS %d / FAIL %d ===" % [_pass_count, _fail_count]
	_log.append(summary)
	_refresh_label()
	print(summary)
	for line in _log:
		print(line)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _fail_count == 0 else 1)
