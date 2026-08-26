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
	await _test_notable_item_gets_jingle()
	await _test_hit_flash_and_destroy_effect()


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


## §3.2 "획득 연출·징글" - 흔한 소모품(하트/화살)까지 매번 배너+징글을 띄우면
## 성가시니, 진행에 의미 있는 아이템(열쇠류·하트조각)만 특별 취급해야 한다.
func _test_notable_item_gets_jingle() -> void:
	_check("C 작은 열쇠 -> 특별 취급", ItemIds.is_notable(ItemIds.SMALL_KEY))
	_check("C 보스 열쇠 -> 특별 취급", ItemIds.is_notable(ItemIds.BOSS_KEY))
	_check("C 하트조각 -> 특별 취급", ItemIds.is_notable(ItemIds.HEART_PIECE))
	_check("C 하트(흔한 소모품) -> 특별 취급 안 함", not ItemIds.is_notable(ItemIds.HEART))
	_check("C 화살(흔한 소모품) -> 특별 취급 안 함", not ItemIds.is_notable(ItemIds.ARROW))
	_check("C 표시 이름 매핑 존재", ItemIds.display_name(ItemIds.BOSS_KEY) == "보스 열쇠")
	_check("C jingle SFX 등록됨", Audio.SFX.has("jingle"))


## §3.2 "이펙트" - 피격 시 modulate 플래시, 파괴 시 파티클 버스트가 실제로
## 발생하는지 확인한다(공통 지점 하나에만 연결돼 있어 몬스터든 플레이어든 동일).
func _test_hit_flash_and_destroy_effect() -> void:
	var target := Combatant.new()
	target.chem_material = ChemTypes.MaterialTag.WOOD
	target.max_hearts = 5.0
	target.global_position = Vector2(2500, 100)
	add_child(target)
	await get_tree().physics_frame

	target.take_damage(1.0)
	_check("D 피격 즉시 -> modulate가 흰색이 아님(플래시 시작됨)", target.modulate != Color.WHITE)
	await get_tree().create_timer(0.3).timeout
	_check("D 플래시 시간 지난 뒤 -> modulate 원복", target.modulate.is_equal_approx(Color.WHITE))

	target.take_damage(999.0)  # 파괴 - target 자신은 이 프레임 안에 queue_free됨
	await get_tree().physics_frame
	var has_particles := false
	for child in get_children():
		if child is CPUParticles2D:
			has_particles = true
			break
	_check("D 파괴 시 -> 파티클 버스트가 부모(this)에 추가됨", has_particles)

	for child in get_children():
		if child is CPUParticles2D:
			child.queue_free()
	await get_tree().create_timer(0.1).timeout


func _print_summary() -> void:
	var summary := "=== M5 사운드/BGM 검증: PASS %d / FAIL %d ===" % [_pass_count, _fail_count]
	_log.append(summary)
	_refresh_label()
	print(summary)
	for line in _log:
		print(line)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _fail_count == 0 else 1)
