extends StoryScreen

## §3.5 1막 오프닝(원소 폭주 배경 설명). "새 게임" 시작 직후에만 재생 -
## "이어하기"는 이미 봤을 테니 건너뛴다(title.gd 참고).

func _ready() -> void:
	slides = [
		{"bg": Color(0.2, 0.15, 0.3), "text": "불·물·전기·얼음, 네 원소의 조화로 유지되던 마을 \"옹달마을\"."},
		{"bg": Color(0.35, 0.12, 0.1), "text": "어느 날, 마을 지하 유적의 봉인이 풀리며 원소가 폭주하기 시작했다."},
		{"bg": Color(0.12, 0.2, 0.35), "text": "우물은 얼어붙고, 밭은 불타고, 대장간엔 쉴 새 없이 번개가 친다."},
		{"bg": Color(0.15, 0.15, 0.2), "text": "견습 연금술사인 당신은, 원소를 진정시키기 위해 유적으로 향한다."},
	]
	next_scene_path = "res://scenes/world_test/world_test.tscn"
	super._ready()
