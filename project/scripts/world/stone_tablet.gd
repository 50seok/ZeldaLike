class_name StoneTablet
extends NPC

## §3.5 2막 "석판 3~4개로 유적의 내력을 조각조각 전달". 기존 NPC/대화 시스템을
## 그대로 재사용한다 - 대사만 다른 NPC일 뿐(sets_flag/requires_flag 없이 순수
## 읽기 전용). 시각적 구분을 위해 색만 돌 느낌으로 바꾼다.

func _draw() -> void:
	draw_rect(Rect2(-box_size / 2, box_size), Color(0.45, 0.45, 0.48))
	draw_rect(Rect2(-box_size / 2, box_size), Color.BLACK, false, 2.0)
