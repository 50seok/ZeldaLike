extends Node

## §3.4 세이브/로드 — JSON 1슬롯(user://). 구역(WorldZone) 진입을 체크포인트로
## 쓴다(던전 방도 §4.2 WorldZone 재사용이라 동일하게 적용됨).
##
## save_path를 const가 아니라 var로 둔 이유: 자동테스트가 실제 유저 세이브 파일을
## 덮어쓰지 않도록 테스트 중에만 다른 경로로 바꿔치기할 수 있게 하기 위함.

var save_path: String = "user://savegame.json"


## 어느 씬(마을/던전 등)에서 저장했는지도 같이 남긴다 - 안 남기면 "이어하기"가
## 항상 마을부터 시작해버려서, 던전 깊이 들어간 상태로 저장해도 거기서부터
## 이어지지 않는다(우선순위5 "전체 연결"에서 발견).
func save_game(player: Player) -> void:
	var data := {
		"player": player.get_save_data(),
		"story_flags": StoryFlags.to_dict(),
		"scene_path": get_tree().current_scene.scene_file_path,
	}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: 저장 실패 - %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(data))


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


## §4 타이틀 "새 게임" - 이어하기가 아니라 진짜 처음부터 시작하려면 기존 저장을
## 무시해야 한다(안 지우면 다음 구역 진입 자동저장 전까지는 옛 세이브가 남아있어,
## 도중에 죽어 씬이 리로드되면 그 옛 데이터로 이어하기가 돼버림).
func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


func load_game(player: Player) -> bool:
	if not has_save():
		return false
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	player.apply_save_data(parsed.get("player", {}))
	StoryFlags.from_dict(parsed.get("story_flags", {}))
	return true


## 타이틀 "이어하기"가 저장된 씬으로 정확히 돌아가기 위한 조회 전용 헬퍼.
func get_saved_scene_path() -> String:
	if not has_save():
		return ""
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return ""
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return ""
	return parsed.get("scene_path", "")
