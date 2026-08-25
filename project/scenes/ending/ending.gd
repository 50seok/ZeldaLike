extends StoryScreen

## §3.5 3막 엔딩(원소 균형 회복). 보스 "혼돈의 코어" 격파(ChaosCore.defeated) 시
## 재생 - 끝나면 타이틀로 되돌아간다.

func _ready() -> void:
	slides = [
		{"bg": Color(0.3, 0.25, 0.1), "text": "혼돈의 코어가 무너지며, 폭주하던 원소가 천천히 잦아들었다."},
		{"bg": Color(0.15, 0.25, 0.15), "text": "얼어붙었던 우물이 녹고, 불탔던 밭엔 새싹이 돋았다. 옹달마을에 평화가 돌아왔다."},
		{"bg": Color(0.2, 0.2, 0.3), "text": "촌장은 당신에게 정식 연금술사의 증표를 건넨다."},
		{"bg": Color(0.1, 0.1, 0.15), "text": "- 끝 -"},
	]
	next_scene_path = "res://scenes/title/title.tscn"
	super._ready()
