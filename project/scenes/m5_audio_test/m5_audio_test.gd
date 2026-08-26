extends Node2D

## M5 우선순위2 검증: 사운드/BGM. Audio 오토로드가 (1) 같은 트랙 재요청엔
## 재시작 안 하고 (2) 다른 트랙 요청엔 전환하고 (3) SFX는 재생 후 스스로
## 정리되는지 확인한다.
##
## 실측 지적("보스전 중 사망하면 멈춘 채로 재시작도 안 됨") 조사 중 발견 -
## AudioStreamPlayer.finished는 웹(HTML5) 압축 포맷에서 안 터지는 경우가
## 알려져 있어, 그것만 믿으면 SFX 노드가 계속 쌓여 긴 전투에서 프레임이
## 죽을 수 있다. Audio.play_sfx()에 재생 길이 기반 강제 정리를 보험으로
## 추가했고(finished 자체가 안 터지는 상황은 네이티브 환경에서 재현이 안 돼
## 직접 격리 검증은 못 하지만), 다수 재생 후 일정 시간 내에 노드가 실제로
## 정리되는지는 확인해둔다(회귀 방지).

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
	await _test_bgm_switch_and_dedup()
	await _test_sfx_cleans_up_after_playing()


func _test_bgm_switch_and_dedup() -> void:
	Audio.play_bgm("village")
	await get_tree().process_frame
	var stream1 := Audio._bgm_player.stream
	_check("A village BGM 재생 시작", stream1 == Audio.BGM["village"])

	Audio.play_bgm("village")  # 같은 트랙 재요청 -> 처음부터 다시 재생하면 안 됨
	await get_tree().process_frame
	_check("A 같은 트랙 재요청 -> 재시작 안 함(_current_bgm 유지)", Audio._current_bgm == "village")

	Audio.play_bgm("boss")
	await get_tree().process_frame
	_check("A 다른 트랙 요청 -> 실제로 전환됨", Audio._bgm_player.stream == Audio.BGM["boss"])


## SFX 재생마다 임시 AudioStreamPlayer가 생기는데, 재생이 끝나면(혹은 웹에서
## finished가 안 터져도 길이 기반 보험으로) 결국 정리돼야 한다 - 안 그러면
## 긴 전투에서 계속 쌓여 성능이 서서히 죽는다(실측 지적과 연결된 회귀 방지).
func _test_sfx_cleans_up_after_playing() -> void:
	var before := Audio.get_child_count()
	for i in range(10):
		Audio.play_sfx("hit")
	var right_after := Audio.get_child_count()
	_check("B SFX 10회 재생 -> 임시 플레이어 생성됨", right_after >= before + 10)

	await get_tree().create_timer(1.0).timeout  # 가장 긴 sfx(knifeSlice, ~0.6초)보다 넉넉히
	_check("B 재생 끝난 뒤 -> 임시 플레이어 전부 정리됨(원상 복귀)", Audio.get_child_count() == before)


func _print_summary() -> void:
	var summary := "=== M5 사운드/BGM 검증: PASS %d / FAIL %d ===" % [_pass_count, _fail_count]
	_log.append(summary)
	_refresh_label()
	print(summary)
	for line in _log:
		print(line)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _fail_count == 0 else 1)
