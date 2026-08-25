extends Node

## §3.4 스토리 플래그. bool만 다루는 단순 저장소 - "촌장과 대화함" 같은 진행
## 게이트/주민 대사 교체를 구동한다. 세이브 연동(우선순위5)은 이 Dictionary를
## 그대로 직렬화하면 되므로 지금은 순수 런타임 상태로만 둔다.

signal flag_changed(flag_name: String)

var _flags: Dictionary = {}


func set_flag(flag_name: String) -> void:
	if _flags.get(flag_name, false):
		return
	_flags[flag_name] = true
	flag_changed.emit(flag_name)


func has_flag(flag_name: String) -> bool:
	return _flags.get(flag_name, false)
