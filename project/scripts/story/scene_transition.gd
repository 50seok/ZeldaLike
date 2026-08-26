extends Node

## 오토로드. 실측 지적("집에서 나오면 화면 정가운데로 와버림 - 문이 아니라
## 던전 나가는 느낌") - world_test.gd/dungeon_test.gd가 원래 갖고 있던 "다른
## 씬에서 왔으면 기본 스폰 유지"(§save-position-mismatch 방지) 로직은 하트/
## 인벤토리/플래그를 지키는 데는 맞지만, 건물처럼 "정확히 이 문 앞으로
## 돌아와야 하는" 전환에는 부족하다. SaveManager(파일 저장)와는 별개로,
## 씬 전환 한 번만 유효한 "다음 스폰 위치" 힌트를 잠깐 들고 있는다.

var _pending_scene: String = ""
var _pending_position := Vector2.INF


func request_spawn_at(scene_path: String, world_position: Vector2) -> void:
	_pending_scene = scene_path
	_pending_position = world_position


## 지금 로드된 씬 경로와 일치할 때만 위치를 내주고 즉시 소모한다(다음 방문엔
## 다시 기본 로직을 타야 하므로).
func consume_spawn_for(scene_path: String) -> Vector2:
	if _pending_scene == scene_path and _pending_position != Vector2.INF:
		var pos := _pending_position
		_pending_scene = ""
		_pending_position = Vector2.INF
		return pos
	return Vector2.INF
