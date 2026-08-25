extends Node2D

## M3 우선순위5 검증: 세이브/로드(§3.4). 플레이어 스냅샷(위치·하트·도구·인벤토리)과
## 스토리 플래그가 실제 파일 왕복(JSON)을 거쳐 정확히 복원되는지 확인한다.
## 실제 유저 세이브 파일을 건드리지 않게 SaveManager.save_path를 테스트 전용
## 경로로 바꿔서 실행하고 끝나면 원복한다.

const TEST_SAVE_PATH := "user://test_savegame.json"

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
	await _test_player_save_data_roundtrip()
	await _test_save_manager_file_roundtrip()


## 파일 I/O 없이 Player.get_save_data()/apply_save_data() 자체의 왕복만 먼저 확인.
func _test_player_save_data_roundtrip() -> void:
	var original := Player.new()
	original.global_position = Vector2(555, 321)
	original.max_hearts = 5.0
	add_child(original)
	await get_tree().process_frame
	# Combatant._ready()가 add_child 시점에 hearts=max_hearts로 초기화하므로,
	# 임의값 검증을 위한 덮어쓰기는 반드시 add_child 이후에 해야 한다(이 프로젝트에서
	# 반복된 "add_child 전 필드 설정이 _ready()에 덮여씌워짐" 패턴 - 테스트에서도 동일).
	original.hearts = 2.5
	original.current_tool = Player.ToolType.ELECTRIC
	var starting_arrows := original.inventory.get_count(ItemIds.ARROW)  # Player._ready()가 지급한 기본 화살
	original.inventory.add(ItemIds.ARROW, 7)
	original.inventory.add(ItemIds.SMALL_KEY, 2)

	var data := original.get_save_data()

	var restored := Player.new()
	add_child(restored)
	await get_tree().process_frame
	restored.apply_save_data(data)

	_check("A 위치 복원", restored.global_position.is_equal_approx(Vector2(555, 321)))
	_check("A 하트/최대하트 복원", restored.hearts == 2.5 and restored.max_hearts == 5.0)
	_check("A 도구 복원", restored.current_tool == Player.ToolType.ELECTRIC)
	_check("A 인벤토리 복원", restored.inventory.get_count(ItemIds.ARROW) == starting_arrows + 7 and restored.inventory.get_count(ItemIds.SMALL_KEY) == 2)

	original.queue_free()
	restored.queue_free()
	await get_tree().create_timer(0.1).timeout


## 실제 SaveManager.save_game()/load_game() - JSON 파일 왕복까지 포함해서 확인.
## JSON은 int도 float로 돌려주는 특성이 있어서(Godot 파서), 그 변환이 제대로
## 처리되는지가 핵심(안 하면 인벤토리 수량이 소수로 깨짐).
func _test_save_manager_file_roundtrip() -> void:
	StoryFlags.reset()

	var original := Player.new()
	original.global_position = Vector2(1234, 88)
	original.max_hearts = 4.0
	add_child(original)
	await get_tree().process_frame
	original.hearts = 1.0
	original.current_tool = Player.ToolType.FIRE
	var starting_arrows := original.inventory.get_count(ItemIds.ARROW)
	original.inventory.add(ItemIds.ARROW, 12)
	StoryFlags.set_flag("save_test_flag")

	SaveManager.save_game(original)
	_check("B 저장 후 -> has_save() true", SaveManager.has_save())

	StoryFlags.reset()
	var loaded := Player.new()
	add_child(loaded)
	await get_tree().process_frame

	var ok := SaveManager.load_game(loaded)
	_check("B load_game() 성공", ok)
	_check("B 위치 복원(파일 왕복)", loaded.global_position.is_equal_approx(Vector2(1234, 88)))
	_check("B 도구 복원(파일 왕복)", loaded.current_tool == Player.ToolType.FIRE)
	_check("B 인벤토리 수량이 정수로 복원(JSON float->int 변환)", loaded.inventory.get_count(ItemIds.ARROW) == starting_arrows + 12)
	_check("B 스토리 플래그도 같이 복원", StoryFlags.has_flag("save_test_flag"))

	original.queue_free()
	loaded.queue_free()
	StoryFlags.reset()
	await get_tree().create_timer(0.1).timeout


func _print_summary() -> void:
	var summary := "=== M3 세이브/로드 검증: PASS %d / FAIL %d ===" % [_pass_count, _fail_count]
	_log.append(summary)
	_refresh_label()
	print(summary)
	for line in _log:
		print(line)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _fail_count == 0 else 1)
