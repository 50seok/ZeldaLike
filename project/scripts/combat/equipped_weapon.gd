class_name EquippedWeapon
extends ChemActor

## 장착한 무기/방패도 §2.1 원칙대로 화학 오브젝트다 — 플레이어를 따라다니며
## 늘 화학엔진에 노출된다. 나무 무기가 다 타서 없어지면(burned_out, ChemActor의
## 소멸 로직 그대로) weapon_destroyed를 쏴서 Player가 반응하게 한다.
##
## tree_exiting이 아니라 burned_out에 연결한다 — tree_exiting은 무기 교체 등
## "화재와 무관한" 제거에도 발동해서 오탐(실측 확인, M2 검증에서 6회 오발동 발견).

signal weapon_destroyed


func _ready() -> void:
	super._ready()
	burned_out.connect(func(): weapon_destroyed.emit())


## 소지자가 쏜 자기 화살에 이 무기가 맞아 불붙는 것도 자기-접촉과 같은 문제라
## 같은 패턴으로 무시한다(Player._on_area_entered 참고).
func _on_area_entered(other: Area2D) -> void:
	if other is Arrow and other.shooter == get_parent():
		return
	super._on_area_entered(other)
