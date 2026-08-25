class_name FieldSpawnManager
extends Node

## §4.2 리젠(혼합형 중 "필드=시간 기반"). 몬스터 전용이 아니라 "소모되면 시간
## 지나 다시 채워지는 것"의 범용 시스템 — 물항아리 같은 소모성 아이템도 같은
## 매니저로 리젠한다(실측 지적: "몬스터만 리젠되고 항아리는 안 됨").
## 스폰포인트마다 죽거나(몬스터) 소모되면(아이템) respawn_sec 카운트다운을 시작,
## 만료됐을 때 ① 화면 밖 ② 필드 전체 개수 상한 이내 둘 다 만족해야 다시 채운다
## (눈앞 팝인 금지, PRD §4.2). 몬스터/아이템을 같은 상한으로 묶고 싶지 않으면
## world_test.gd처럼 매니저를 용도별로 따로 두면 된다.
##
## 엔티티 팩토리(_create_entity)는 새 종류 추가 시 여기에 match 분기만 늘리면
## 된다 — 데이터(SpawnPoint.entity_type)는 이미 문자열이라 이 파일 수정 1곳이면 충분.

signal entity_spawned(entity: Node)

@export var spawn_points: Array[SpawnPoint] = []
@export var field_cap: int = 5

var _camera: Camera2D
var _alive: Dictionary = {}    # SpawnPoint -> Array[Node]
var _cooldown: Dictionary = {} # SpawnPoint -> float(남은 초)


func setup(camera: Camera2D) -> void:
	_camera = camera


func _ready() -> void:
	for sp in spawn_points:
		_alive[sp] = []
	# 초기 배치도 field_cap을 지킨다 — 스폰포인트 총합이 상한보다 많으면
	# 나머지는 못 채운 채로 시작해서(size<max_alive) 곧바로 리젠 대기열에 들어간다.
	for sp in spawn_points:
		for i in range(sp.max_alive):
			if _count_alive() >= field_cap:
				break
			_do_spawn(sp)


func _process(delta: float) -> void:
	for sp in spawn_points:
		if not sp.active:
			continue
		_alive[sp] = _alive[sp].filter(func(n): return is_instance_valid(n))

		if _alive[sp].size() >= sp.max_alive:
			continue

		if not _cooldown.has(sp):
			_cooldown[sp] = sp.respawn_sec
			continue

		_cooldown[sp] -= delta
		if _cooldown[sp] > 0.0:
			continue
		if _count_alive() >= field_cap:
			continue
		if not _is_offscreen(sp.global_position):
			continue

		_do_spawn(sp)
		_cooldown.erase(sp)


func _count_alive() -> int:
	var n := 0
	for sp in _alive:
		for node in _alive[sp]:
			if is_instance_valid(node):
				n += 1
	return n


func _do_spawn(sp: SpawnPoint) -> void:
	var entity := _create_entity(sp.entity_type)
	if entity == null:
		return
	entity.global_position = sp.global_position
	get_parent().add_child(entity)
	_alive[sp].append(entity)
	entity_spawned.emit(entity)


func _create_entity(entity_type: String) -> ChemActor:
	match entity_type:
		"vine":
			return VineEnemy.new()
		"wood_guard":
			return WoodGuard.new()
		"ember":
			return Ember.new()
		"iron_shell":
			return IronShell.new()
		"water_jar":
			var jar := Throwable.new()
			jar.chem_material = ChemTypes.MaterialTag.WATER
			jar.display_name = "물항아리"
			return jar
		_:
			push_warning("FieldSpawnManager: 알 수 없는 엔티티 타입 '%s'" % entity_type)
			return null


func _is_offscreen(pos: Vector2) -> bool:
	if _camera == null:
		return true
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var half_extents: Vector2 = (viewport_size / _camera.zoom) / 2.0
	var center: Vector2 = _camera.get_screen_center_position()
	var rect := Rect2(center - half_extents, half_extents * 2.0)
	return not rect.has_point(pos)
