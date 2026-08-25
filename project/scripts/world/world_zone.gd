class_name WorldZone
extends Resource

## §4.2 "필드 = 스크롤 맵(Camera2D limit)". 존 하나 = 이름 + 경계 + 안전지대 여부.
## 별도 씬 로딩 없이, 플레이어 위치가 이 경계 안에 들어오면 카메라 limit을 맞춘다.

@export var zone_name: String = ""
@export var bounds: Rect2 = Rect2(0, 0, 800, 600)
@export var is_safe: bool = false
