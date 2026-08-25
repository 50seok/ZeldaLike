extends Node2D

## M3 우선순위4 검증: NPC 대화 + 스토리 플래그(§3.4). 대화박스 타자 효과,
## 기능 NPC의 sets_flag, 주민 NPC의 requires_flag/alt_lines 교체를 확인한다.

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
	await _test_dialogue_typewriter()
	await _test_functional_npc_sets_flag()
	await _test_flavor_npc_line_swap()
	await _test_player_integration_multi_line()


func _test_dialogue_typewriter() -> void:
	var box := DialogueBox.new()
	box.chars_per_sec = 10.0
	add_child(box)
	await get_tree().process_frame

	box.start("테스트", ["안녕하세요"])
	_check("A 대화 시작 -> 박스 열림", box.is_open())
	await get_tree().create_timer(0.1).timeout
	_check("A 타자 진행 중 -> 아직 전체 텍스트 아님", box.get_visible_text().length() < "안녕하세요".length())

	box.advance()
	_check("A advance(진행중) -> 즉시 완성", box.get_visible_text() == "안녕하세요")

	box.advance()
	_check("A advance(완성 후, 마지막 줄) -> 박스 닫힘", not box.is_open())

	box.queue_free()
	await get_tree().create_timer(0.1).timeout


func _test_functional_npc_sets_flag() -> void:
	var box := DialogueBox.new()
	box.chars_per_sec = 9999.0
	add_child(box)

	var chief := NPC.new()
	chief.npc_name = "촌장"
	chief.lines = ["어서 오게."]
	chief.sets_flag = "met_chief"
	add_child(chief)
	await get_tree().process_frame

	_check("B 대화 전 -> 플래그 없음", not StoryFlags.has_flag("met_chief"))
	chief.talk(box)
	await get_tree().create_timer(0.05).timeout
	box.advance()
	await get_tree().create_timer(0.05).timeout
	_check("B 대화 종료 -> 플래그 세워짐(진행 게이트)", StoryFlags.has_flag("met_chief"))

	box.queue_free()
	chief.queue_free()
	await get_tree().create_timer(0.1).timeout


func _test_flavor_npc_line_swap() -> void:
	var box := DialogueBox.new()
	box.chars_per_sec = 9999.0
	add_child(box)

	var villager := NPC.new()
	villager.npc_name = "주민"
	villager.lines = ["요즘 원소가 폭주해서 걱정이야..."]
	villager.alt_lines = ["이제 좀 안심이 되는군!"]
	villager.requires_flag = "test_flag_for_villager"
	add_child(villager)
	await get_tree().process_frame

	_check("C 플래그 세우기 전 -> 확인용 플래그 없음", not StoryFlags.has_flag("test_flag_for_villager"))
	villager.talk(box)
	await get_tree().create_timer(0.05).timeout
	_check("C 플래그 없음 -> 기본 대사", box.get_visible_text() == "요즘 원소가 폭주해서 걱정이야...")
	box.advance()
	await get_tree().create_timer(0.05).timeout

	StoryFlags.set_flag("test_flag_for_villager")
	villager.talk(box)
	await get_tree().create_timer(0.05).timeout
	_check("C 플래그 세워짐 -> alt_lines로 1회 교체", box.get_visible_text() == "이제 좀 안심이 되는군!")
	box.advance()
	await get_tree().create_timer(0.05).timeout

	box.queue_free()
	villager.queue_free()
	await get_tree().create_timer(0.1).timeout


## 위 테스트들은 NPC.talk()/DialogueBox를 직접 호출해서 검증했는데, 실제 플레이는
## Player._unhandled_input()의 라우팅(대화 중엔 Space=advance, 아니면 interact_or_throw)을
## 거친다 - 사용자가 "여러 줄짜리 NPC가 첫 줄만 반복된다"고 보고해서, 그 실제 경로를
## 그대로 재현해 확인한다.
func _test_player_integration_multi_line() -> void:
	var box := DialogueBox.new()
	box.chars_per_sec = 9999.0
	add_child(box)
	box.add_to_group("dialogue_box")

	var player := Player.new()
	player.global_position = Vector2(900, 100)
	add_child(player)

	var chief := NPC.new()
	chief.npc_name = "촌장"
	chief.lines = ["첫 줄", "둘째 줄", "셋째 줄"]
	chief.sets_flag = "d_test_met_chief"
	chief.global_position = Vector2(900, 100)
	add_child(chief)
	await get_tree().physics_frame
	await get_tree().physics_frame

	player.interact_or_throw()  # 1번째 Space - 대화 시작
	await get_tree().create_timer(0.05).timeout
	_check("D 1번째 Space -> 대화 시작+첫 줄", box.get_visible_text() == "첫 줄")

	_check("D 대화 중 -> _is_dialogue_open() true", player._is_dialogue_open())
	player._dialogue_box.advance()  # 2번째 Space(대화 중이므로 실제로는 _unhandled_input이 advance를 호출)
	await get_tree().create_timer(0.05).timeout
	_check("D 2번째 Space -> 둘째 줄로 진행", box.get_visible_text() == "둘째 줄")

	player._dialogue_box.advance()  # 3번째 Space
	await get_tree().create_timer(0.05).timeout
	_check("D 3번째 Space -> 셋째 줄로 진행", box.get_visible_text() == "셋째 줄")

	player._dialogue_box.advance()  # 4번째 Space - 마지막 줄 이후라 닫힘+플래그
	await get_tree().create_timer(0.05).timeout
	_check("D 4번째 Space -> 대화 종료+플래그 세워짐", not box.is_open() and StoryFlags.has_flag("d_test_met_chief"))

	player.queue_free()
	chief.queue_free()
	box.queue_free()
	await get_tree().create_timer(0.1).timeout


func _print_summary() -> void:
	var summary := "=== M3 NPC대화+스토리플래그 검증: PASS %d / FAIL %d ===" % [_pass_count, _fail_count]
	_log.append(summary)
	_refresh_label()
	print(summary)
	for line in _log:
		print(line)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _fail_count == 0 else 1)
