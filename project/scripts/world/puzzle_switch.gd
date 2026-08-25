class_name PuzzleSwitch
extends ChemActor

## §4 화학 퍼즐 예시 ②("물 뿌려 전기 회로 연결") - 새 반응 규칙 없이 화학엔진의
## 기존 CHARGED 상태 변화를 그대로 재사용한다(전기+금속=전도, 이미 반응표에 있음).
## 한 번 활성화되면 계속 activated 상태 유지(재잠금 없음 - 퍼즐 게이트는 한 번 풀면
## 끝이라는 젤다 관례).

signal activated

var _activated := false


func _ready() -> void:
	super._ready()
	chem_material = ChemTypes.MaterialTag.METAL
	display_name = "스위치"
	chem_state_changed.connect(_on_state_changed)


func _on_state_changed(new_state: int) -> void:
	if _activated or new_state != ChemTypes.State.CHARGED:
		return
	_activated = true
	activated.emit()
