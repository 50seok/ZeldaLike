extends Node

## §3.4 세이브/로드 — JSON 1슬롯(user://). 타이틀 화면이 아직 없어서(M4 스코프)
## "이어하기"는 씬 시작 시 저장이 있으면 자동으로 적용하는 것으로 대신한다.
## "방 클리어 시 자동저장"은 현재 스코프엔 던전 방이 없어 구역(WorldZone) 진입을
## 체크포인트로 대신 쓴다 - 던전이 생기면(우선순위6) 방 클리어 시점 호출만 추가하면 됨.
##
## save_path를 const가 아니라 var로 둔 이유: 자동테스트가 실제 유저 세이브 파일을
## 덮어쓰지 않도록 테스트 중에만 다른 경로로 바꿔치기할 수 있게 하기 위함.

var save_path: String = "user://savegame.json"


func save_game(player: Player) -> void:
	var data := {
		"player": player.get_save_data(),
		"story_flags": StoryFlags.to_dict(),
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
