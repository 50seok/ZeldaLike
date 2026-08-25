extends Node2D

## M4 우선순위5 검증: 전체 연결(§4 "타이틀→마을→던전→보스→엔딩"). 씬 전환
## 자체(world_test<->dungeon_test<->ending)는 실제로 트리거하면 테스트 씬
## 자신이 갈아치워지므로, 여기선 "이어하기가 저장된 씬으로 정확히 돌아가는지"
## 를 뒷받침하는 SaveManager.get_saved_scene_path()만 확인한다. 던전 입구
## 트리거·보스방 배치는 world_test.tscn/dungeon_test.tscn에서 수동 플레이로
## 확인(플레이어 위치 기반 실제 씬 전환이라 자동화하면 테스트 트리 자체가 깨짐).

const TEST_SAVE_PATH := "user://test_savegame_connect.json"

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
	await _test_saved_scene_path_roundtrip()


func _test_saved_scene_path_roundtrip() -> void:
	_check("A 저장 없음 -> 씬 경로 빈 문자열", SaveManager.get_saved_scene_path() == "")

	var dummy_player := Player.new()
	SaveManager.save_game(dummy_player)
	dummy_player.free()

	# 이 테스트 씬 자체가 지금 get_tree().current_scene이므로, 저장된 씬 경로도
	# 그와 일치해야 한다 - "이어하기"가 던전 도중에 저장해도 던전으로 돌아가는
	# 근거(실측: 예전엔 씬 경로를 안 남겨서 이어하기가 항상 마을부터 시작했음).
	var expected_path := get_tree().current_scene.scene_file_path
	_check("B 저장 후 -> 현재 씬 경로가 기록됨", SaveManager.get_saved_scene_path() == expected_path)

	SaveManager.delete_save()
	_check("C 저장 삭제 후 -> 다시 빈 문자열", SaveManager.get_saved_scene_path() == "")

	await get_tree().create_timer(0.1).timeout


func _print_summary() -> void:
	var summary := "=== M4 전체연결(이어하기 씬 복원) 검증: PASS %d / FAIL %d ===" % [_pass_count, _fail_count]
	_log.append(summary)
	_refresh_label()
	print(summary)
	for line in _log:
		print(line)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _fail_count == 0 else 1)
