extends Node2D

## M5 "그래픽 에셋" 검증 - Kenney Tiny 시리즈 타일이 실제로 Sprite2D 자식으로
## 붙는지 확인한다(육안 확인은 이 헤드리스 환경에서 불가능해서, 최소한 구조가
## 맞는지만이라도 회귀 방지). 텍스처 파일 경로/인덱스 계산 실수(가장 흔한
## 회귀 - 오타난 res:// 경로, 열 수 틀림 등)를 조기에 잡는 게 목적.

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
	await _test_sprite_child_created()
	await _test_tile_region_math()


func _find_sprite(node: Node) -> Sprite2D:
	for child in node.get_children():
		if child is Sprite2D:
			return child
	return null


func _test_sprite_child_created() -> void:
	var player := Player.new()
	player.global_position = Vector2(2900, 100)
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame  # sprite_texture 적용은 call_deferred라 한 프레임 더 필요
	var player_sprite := _find_sprite(player)
	_check("A 플레이어 -> Sprite2D 자식 생성됨", player_sprite != null)
	_check("A 플레이어 -> 텍스처 설정됨", player_sprite != null and player_sprite.texture != null)
	player.queue_free()

	var vine := VineEnemy.new()
	vine.global_position = Vector2(2950, 100)
	add_child(vine)
	await get_tree().process_frame
	await get_tree().process_frame
	var vine_sprite := _find_sprite(vine)
	_check("A 덩굴이 -> Sprite2D 자식 생성됨", vine_sprite != null)

	var boss := ChaosCore.new()
	boss.global_position = Vector2(3000, 100)
	add_child(boss)
	await get_tree().process_frame
	await get_tree().process_frame
	var boss_sprite := _find_sprite(boss)
	_check("A 보스 -> Sprite2D 자식 생성됨", boss_sprite != null)

	vine.queue_free()
	boss.queue_free()
	await get_tree().create_timer(0.1).timeout


## 타일 인덱스->좌표 계산이 틀리면(열 수 오타 등) 엉뚱한 그림이 잘려 나온다 -
## 미리보기 이미지를 격자로 잘라 직접 확인한 인덱스(§CREDITS.txt)가 실제로
## 올바른 픽셀 영역을 가리키는지 수식으로 고정해둔다.
func _test_tile_region_math() -> void:
	var t := SpriteUtil.tile(SpriteUtil.TINY_DUNGEON, 13, 12)
	_check("B 인덱스 13(12열) -> row1,col1 좌표", t.region == Rect2(16, 16, 16, 16))

	var t2 := SpriteUtil.tile(SpriteUtil.TINY_CREATURES, 41, 10)
	_check("B 인덱스 41(10열) -> row4,col1 좌표", t2.region == Rect2(16, 64, 16, 16))


func _print_summary() -> void:
	var summary := "=== M5 그래픽(스프라이트) 검증: PASS %d / FAIL %d ===" % [_pass_count, _fail_count]
	_log.append(summary)
	_refresh_label()
	print(summary)
	for line in _log:
		print(line)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _fail_count == 0 else 1)
