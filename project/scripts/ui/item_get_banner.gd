class_name ItemGetBanner
extends Label

## §3.2 "획득 연출" - 진행에 의미 있는 아이템(열쇠류·하트조각) 획득 시 화면
## 위쪽 중앙에 잠깐 뜨는 배너+징글(사운드는 Player.collect_item에서 재생).
## 실제 게임을 멈추는 연출(BOTW식 치켜들기)은 몬스터 AI 등 다른 시스템을
## 전부 PROCESS_MODE_ALWAYS로 예외 처리해야 해서 이 스코프엔 과함(ponytail) -
## 화면 위에 겹쳐 페이드 인/아웃하는 것만으로 충분.

var _tween: Tween


func _ready() -> void:
	# project.godot에서 뷰포트를 1152x648로 고정해뒀으니(웹 빌드 리스크 대응,
	# M5-우선순위1) 화면 중앙 좌표를 그냥 고정값으로 잡아도 안전하다.
	position = Vector2(326, 140)
	size = Vector2(500, 50)
	add_theme_font_size_override("font_size", 28)
	add_theme_color_override("font_color", Color(1.0, 0.95, 0.4))
	add_theme_color_override("font_outline_color", Color(0.2, 0.15, 0.0))
	add_theme_constant_override("outline_size", 6)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modulate.a = 0.0


func show_item(item_display_name: String) -> void:
	text = "획득! %s" % item_display_name
	if _tween and _tween.is_valid():
		_tween.kill()
	modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.15)
	_tween.tween_interval(1.0)
	_tween.tween_property(self, "modulate:a", 0.0, 0.4)
