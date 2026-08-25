extends Node2D

## M4 우선순위4 검증: 석판(§3.5 유적 내력) + 정령 구출. 둘 다 기존 NPC/대화/
## 스토리플래그 시스템을 재사용하는 거라, 여기선 재사용이 실제로 맞물리는지만
## 확인한다 - StoneTablet이 NPC 대화 그대로 동작하는지, 정령 구출(sets_flag)이
## flag_changed 신호를 통해 문을 여는 배선까지 이어지는지.

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
	await _test_stone_tablet_is_npc_reuse()
	await _test_spirit_rescue_unlocks_door()


func _test_stone_tablet_is_npc_reuse() -> void:
	var box := DialogueBox.new()
	box.chars_per_sec = 9999.0
	add_child(box)

	var tablet := StoneTablet.new()
	tablet.npc_name = "석판 1"
	tablet.lines = ["유적의 내력 한 조각."]
	add_child(tablet)
	await get_tree().process_frame

	_check("A 석판 -> NPC를 그대로 상속(새 대화시스템 아님)", tablet is NPC)
	tablet.talk(box)
	await get_tree().create_timer(0.05).timeout
	_check("A 석판 -> 대사가 대화박스에 그대로 표시", box.get_visible_text() == "유적의 내력 한 조각.")

	box.queue_free()
	tablet.queue_free()
	await get_tree().create_timer(0.1).timeout


## §3.5 "정령 구출(플래그)하면... 보스 방이 열림" - dungeon_test.gd와 동일한
## 배선(flag_changed -> door.unlock())을 재현해서 확인한다.
func _test_spirit_rescue_unlocks_door() -> void:
	var box := DialogueBox.new()
	box.chars_per_sec = 9999.0
	add_child(box)

	var door := Door.new()
	door.global_position = Vector2(500, 500)
	add_child(door)

	var spirit := NPC.new()
	spirit.npc_name = "원소 정령"
	spirit.lines = ["구해줘서 고맙다.", "보스의 약점은 물+전기다."]
	spirit.sets_flag = "test_spirit_rescued"
	add_child(spirit)
	await get_tree().process_frame

	StoryFlags.flag_changed.connect(func(flag_name):
		if flag_name == "test_spirit_rescued":
			door.unlock()
	)

	_check("B 대화 전 -> 문은 잠긴 채", door.locked)

	spirit.talk(box)
	await get_tree().create_timer(0.05).timeout
	box.advance()  # 1번째 줄 완성 -> 2번째(마지막) 줄로
	await get_tree().create_timer(0.05).timeout
	box.advance()  # 마지막 줄 완성 -> 닫기(대화 종료)
	await get_tree().create_timer(0.05).timeout
	_check("B 정령 대화 종료 -> 구출 플래그 세워짐", StoryFlags.has_flag("test_spirit_rescued"))
	_check("B 구출 플래그 -> flag_changed 배선으로 문이 열림", not door.locked)

	box.queue_free()
	door.queue_free()
	spirit.queue_free()
	await get_tree().create_timer(0.1).timeout


func _print_summary() -> void:
	var summary := "=== M4 석판+정령구출 검증: PASS %d / FAIL %d ===" % [_pass_count, _fail_count]
	_log.append(summary)
	_refresh_label()
	print(summary)
	for line in _log:
		print(line)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _fail_count == 0 else 1)
