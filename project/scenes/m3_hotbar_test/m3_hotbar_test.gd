extends Node2D

## M3 우선순위7 검증: 인벤토리 핫바 UI(§3.3 "핫바(도구 전환) + 카운터
## (열쇠·화살·하트조각)"). _draw()는 픽셀 검사 없인 확인이 안 되니, Hotbar가
## 노출하는 get_selected_index()와 카운터 라벨 텍스트로 확인한다.

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
	await _test_tool_selection_tracks_player()
	await _test_counters_reflect_inventory()


func _test_tool_selection_tracks_player() -> void:
	var player := Player.new()
	add_child(player)
	var hotbar := Hotbar.new()
	hotbar.player = player
	add_child(hotbar)
	await get_tree().process_frame

	_check("A 초기 도구(일반) 선택 인덱스 일치", hotbar.get_selected_index() == Hotbar.TOOL_ORDER.find(Player.ToolType.NORMAL))

	player.cycle_tool()  # NORMAL -> FIRE
	_check("A 도구 전환(불) 반영", hotbar.get_selected_index() == Hotbar.TOOL_ORDER.find(Player.ToolType.FIRE))

	player.cycle_tool()  # FIRE -> ELECTRIC
	_check("A 도구 전환(전기) 반영", hotbar.get_selected_index() == Hotbar.TOOL_ORDER.find(Player.ToolType.ELECTRIC))

	player.queue_free()
	hotbar.queue_free()
	await get_tree().create_timer(0.1).timeout


func _test_counters_reflect_inventory() -> void:
	var player := Player.new()
	add_child(player)
	var hotbar := Hotbar.new()
	hotbar.player = player
	add_child(hotbar)
	await get_tree().process_frame

	var starting_arrows := player.inventory.get_count(ItemIds.ARROW)
	player.inventory.add(ItemIds.SMALL_KEY, 2)
	player.inventory.add(ItemIds.BOSS_KEY, 1)
	player.inventory.add(ItemIds.HEART_PIECE, 3)
	await get_tree().process_frame

	var text: String = hotbar._counter_label.text
	_check("B 카운터에 화살 수량 표시", text.contains("화살 %d" % starting_arrows))
	_check("B 카운터에 작은열쇠 수량 표시", text.contains("작은열쇠 2"))
	_check("B 카운터에 보스열쇠 수량 표시", text.contains("보스열쇠 1"))
	_check("B 카운터에 하트조각 수량 표시", text.contains("하트조각 3"))

	player.queue_free()
	hotbar.queue_free()
	await get_tree().create_timer(0.1).timeout


func _print_summary() -> void:
	var summary := "=== M3 핫바 UI 검증: PASS %d / FAIL %d ===" % [_pass_count, _fail_count]
	_log.append(summary)
	_refresh_label()
	print(summary)
	for line in _log:
		print(line)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _fail_count == 0 else 1)
