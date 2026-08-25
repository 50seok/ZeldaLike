class_name Throwable
extends ChemActor

## 집기/던지기 대상(§3.1). 물 항아리 등 — 들고 있는 동안은 반응 없음(monitoring off),
## 던지면 날아가다 뭔가에 닿는 순간 화학 반응이 성립하고(예: 불에 던지면 소화) 깨진다.

@export var throw_speed: float = 300.0

var _is_thrown := false
var _direction := Vector2.ZERO
var _held_by: Node2D = null
var _thrower: Node = null


func pick_up(holder: Node2D) -> void:
	_held_by = holder
	_thrower = holder
	monitoring = false
	visible = false


func throw(dir: Vector2) -> void:
	_held_by = null
	_direction = dir.normalized() if dir != Vector2.ZERO else Vector2.RIGHT
	_is_thrown = true
	monitoring = true
	visible = true


func _physics_process(_delta: float) -> void:
	if _held_by:
		global_position = _held_by.global_position
		return
	if _is_thrown:
		position += _direction * throw_speed * _delta


func _on_area_entered(other: Area2D) -> void:
	if other == _thrower or other.get_parent() == _thrower:
		return
	super._on_area_entered(other)
	if _is_thrown:
		_is_thrown = false
		queue_free()
