class_name SpawnPoint
extends Node2D

## §4.2 "스폰포인트 = 데이터" — 필드 씬에 노드로 배치. 몬스터 종류/최대 마릿수/
## 리젠 주기/활성 조건을 전부 인스펙터에서 조정 가능한 데이터로 뺀다(반응표·드랍표와
## 같은 원칙) — 밸런싱은 M5에서 이 값들만 고치면 된다.

@export var monster_type: String = "vine"
@export var respawn_sec: float = 45.0
@export var max_alive: int = 1
@export var active: bool = true
