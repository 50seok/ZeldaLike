class_name ZoneCameraController
extends Node

## 플레이어 위치로 현재 존을 찾아 카메라 limit_*을 그 존 경계로 맞춘다.
## Area2D/물리 신호를 안 쓰고 위치 폴링만으로 판정 — zone은 순수 데이터(Rect2)라
## 겹침 판정에 화학엔진 접촉 시스템(ChemActor)을 끌어들이지 않는다.

signal zone_changed(zone: WorldZone)

@export var zones: Array[WorldZone] = []

var current_zone: WorldZone

var _camera: Camera2D
var _player: Node2D


func setup(camera: Camera2D, player: Node2D) -> void:
	_camera = camera
	_player = player
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 5.0


func _process(_delta: float) -> void:
	if _camera == null or not is_instance_valid(_player):
		return
	var zone := _find_zone_at(_player.global_position)
	if zone == current_zone:
		return
	current_zone = zone
	if zone != null:
		_camera.limit_left = int(zone.bounds.position.x)
		_camera.limit_top = int(zone.bounds.position.y)
		_camera.limit_right = int(zone.bounds.end.x)
		_camera.limit_bottom = int(zone.bounds.end.y)
	zone_changed.emit(zone)


func _find_zone_at(pos: Vector2) -> WorldZone:
	for zone in zones:
		if zone.bounds.has_point(pos):
			return zone
	return null
