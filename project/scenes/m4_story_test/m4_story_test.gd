extends Node2D

## M4 우선순위3 검증: 오프닝/엔딩 일러스트+텍스트(§3.4/§3.5). StoryScreen의
## 슬라이드 진행/종료 로직과, opening.gd/ending.gd가 올바른 슬라이드+다음 씬
## 경로로 설정돼 있는지 확인한다. 실제 씬 전환은 테스트 자신의 트리를
## 갈아치우므로 끝까지 advance()하지 않고 next_scene_path 값만 확인한다.

@onready var _label: Label = $DebugLabel

var _log: Array[String] = []
var _pass_count := 0
var _fail_count := 0


func _ready() -> void:
	await get_tree().process_frame
	await _run_all_tests()
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
	await _test_story_screen_progression()
	await _test_opening_config()
	await _test_ending_config()


func _test_story_screen_progression() -> void:
	var screen := StoryScreen.new()
	screen.slides = [
		{"bg": Color.RED, "text": "첫 슬라이드"},
		{"bg": Color.BLUE, "text": "둘째 슬라이드"},
	]
	# next_scene_path는 비워둔다 - 실제 전환 없이 finished 신호만 확인하려고.
	add_child(screen)
	await get_tree().process_frame

	_check("A 시작 -> 첫 슬라이드 표시", screen._label.text == "첫 슬라이드")

	screen.advance()
	_check("A 1번째 advance -> 둘째 슬라이드로", screen._label.text == "둘째 슬라이드")

	var finished_flag := {"v": false}
	screen.finished.connect(func(): finished_flag.v = true)
	screen.advance()
	_check("A 마지막 슬라이드 이후 advance -> finished 신호", finished_flag.v)

	screen.queue_free()
	await get_tree().create_timer(0.1).timeout


func _test_opening_config() -> void:
	var opening := Node2D.new()
	opening.set_script(load("res://scenes/opening/opening.gd"))
	add_child(opening)
	await get_tree().process_frame

	_check("B 오프닝 -> 슬라이드 여러 장 구성됨", opening.slides.size() >= 3)
	_check("B 오프닝 -> 다음 씬은 월드(메인 게임)", opening.next_scene_path == "res://scenes/world_test/world_test.tscn")
	_check("B 오프닝 대상 씬 파일 실제 존재", ResourceLoader.exists(opening.next_scene_path))

	opening.queue_free()
	await get_tree().create_timer(0.1).timeout


func _test_ending_config() -> void:
	var ending := Node2D.new()
	ending.set_script(load("res://scenes/ending/ending.gd"))
	add_child(ending)
	await get_tree().process_frame

	_check("C 엔딩 -> 슬라이드 여러 장 구성됨", ending.slides.size() >= 3)
	_check("C 엔딩 -> 다음 씬은 타이틀", ending.next_scene_path == "res://scenes/title/title.tscn")
	_check("C 엔딩 대상 씬 파일 실제 존재", ResourceLoader.exists(ending.next_scene_path))

	ending.queue_free()
	await get_tree().create_timer(0.1).timeout


func _print_summary() -> void:
	var summary := "=== M4 오프닝/엔딩 검증: PASS %d / FAIL %d ===" % [_pass_count, _fail_count]
	_log.append(summary)
	_refresh_label()
	print(summary)
	for line in _log:
		print(line)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _fail_count == 0 else 1)
