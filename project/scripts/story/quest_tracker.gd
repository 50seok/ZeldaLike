class_name QuestTracker
extends Label

## §3.4 스토리 플래그를 그대로 재사용해 "현재 목표" 한 줄만 보여준다 - 퀘스트
## 로그나 대화 분기가 아니라 목표 표시 UI만(PRD §4 비스코프 "대화 분기·퀘스트
## 시스템" 유지, 진행은 여전히 선형 bool 플래그 하나로 결정).
##
## steps는 순서대로 훑어 첫 번째 "아직 안 세워진 플래그"의 텍스트를 보여준다.
## flag가 빈 문자열이면 완료 조건이 없는 마지막 단계로 취급해 항상 표시한다.

@export var steps: Array[Dictionary] = []  # [{flag: String, text: String}, ...]


func _ready() -> void:
	add_theme_font_size_override("font_size", 16)
	add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	StoryFlags.flag_changed.connect(func(_flag_name): _refresh())
	_refresh()


func _refresh() -> void:
	for step in steps:
		var flag: String = step.get("flag", "")
		if flag == "" or not StoryFlags.has_flag(flag):
			text = "목표: %s" % step.get("text", "")
			return
	text = "목표: 완료"
