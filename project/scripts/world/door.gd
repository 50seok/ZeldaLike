class_name Door
extends Node2D

## §4 "자물쇠-열쇠 구조". Player가 Area2D라 물리 충돌 반응이 없어서(§4 전투/이동
## 전부 위치 이동식), 잠긴 문의 사각형 안으로 들어오면 직전 위치로 밀어내는 방식으로
## 통행을 막는다. 두 가지 잠금 방식:
## - required_key != "" : 그 아이템을 인벤토리에 갖고 있으면 통과 시점에 자동 소모하며 열림
## - required_key == "" : 아이템으로는 안 열림, 외부(PuzzleSwitch 등)에서 unlock()을
##   호출해야만 열림 - "물 뿌려 전기 회로 연결" 같은 화학 퍼즐 게이트용

signal unlocked

@export var bounds: Rect2 = Rect2(-16, -40, 32, 80)
@export var required_key: String = ""

var locked := true
var _player: Node2D


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	if not locked:
		return
	draw_rect(bounds, Color(0.5, 0.35, 0.2))
	draw_rect(bounds, Color.BLACK, false, 2.0)


func _process(_delta: float) -> void:
	if not locked:
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return
	var local_pos: Vector2 = _player.global_position - global_position
	if not bounds.has_point(local_pos):
		return
	if required_key != "" and _player.inventory.get_count(required_key) > 0:
		_player.inventory.remove(required_key, 1)
		unlock()
		return
	_push_out(local_pos)


func unlock() -> void:
	if not locked:
		return
	locked = false
	queue_redraw()
	Audio.play_sfx("door")
	unlocked.emit()


## 보스 방처럼 "들어가면 격파 전까지 못 나가는" 문에 쓴다 - 이미 한 번 열렸던
## (그래서 required_key가 이미 소모된) 문도 다시 잠글 수 있다.
func lock() -> void:
	if locked:
		return
	locked = true
	queue_redraw()


## 가장 가까운 경계 쪽으로 최소 이동시켜 문 사각형 밖으로 밀어낸다. 정확히
## 경계선 위에 놓으면 Rect2.has_point()의 경계 포함 규칙 때문에 여전히 "안쪽"으로
## 판정될 수 있어(실측 확인), epsilon만큼 더 밀어 확실히 밖으로 낸다.
func _push_out(local_pos: Vector2) -> void:
	var d_left := local_pos.x - bounds.position.x
	var d_right := bounds.end.x - local_pos.x
	var d_top := local_pos.y - bounds.position.y
	var d_bottom := bounds.end.y - local_pos.y
	var min_d: float = min(d_left, min(d_right, min(d_top, d_bottom)))
	var push := local_pos
	var epsilon := 1.0
	if min_d == d_left:
		push.x = bounds.position.x - epsilon
	elif min_d == d_right:
		push.x = bounds.end.x + epsilon
	elif min_d == d_top:
		push.y = bounds.position.y - epsilon
	else:
		push.y = bounds.end.y + epsilon
	_player.global_position = global_position + push
