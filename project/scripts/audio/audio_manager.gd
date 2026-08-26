extends Node

## 오토로드. PRD §5 "BGM 마을/던전/보스 3트랙" + 기본 효과음(공격/피격/획득/문).
## BGM은 finished 신호로 수동 루프(mp3는 Godot에서 임포트 루프 메타데이터를
## 못 써서, 대신 재생이 끝나면 다시 재생).

const BGM := {
	"village": preload("res://assets/audio/bgm/village.mp3"),
	"dungeon": preload("res://assets/audio/bgm/dungeon.ogg"),
	"boss": preload("res://assets/audio/bgm/boss.mp3"),
}

const SFX := {
	"attack": preload("res://assets/audio/sfx/knifeSlice.ogg"),
	"hit": preload("res://assets/audio/sfx/impactGeneric_light_000.ogg"),
	"pickup": preload("res://assets/audio/sfx/handleCoins.ogg"),
	"door": preload("res://assets/audio/sfx/doorOpen_1.ogg"),
	"jingle": preload("res://assets/audio/sfx/item_get_jingle.ogg"),
}

## 실측 지적("BGM 소리를 줄이거나 끌 수 있는 UI가 필요할듯") - 정밀한 dB
## 슬라이더 대신 이 프로젝트 전체가 키보드 전용 UX라(마우스 조작 없음) 단계
## 순환으로 충분하다. BGM만 별도 버스로 둬서 SFX는 안 건드리고 배경음악만
## 낮춘다.
const BGM_VOLUME_LEVELS := [
	{"db": 0.0, "label": "100%"},
	{"db": -6.0, "label": "50%"},
	{"db": -14.0, "label": "20%"},
	{"db": -80.0, "label": "음소거"},
]

var _bgm_player: AudioStreamPlayer
var _current_bgm: String = ""
var _bgm_volume_index := 0


func _ready() -> void:
	if AudioServer.get_bus_index("BGM") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "BGM")

	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "BGM"
	add_child(_bgm_player)
	_bgm_player.finished.connect(func(): _bgm_player.play())


func cycle_bgm_volume() -> void:
	_bgm_volume_index = (_bgm_volume_index + 1) % BGM_VOLUME_LEVELS.size()
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("BGM"), BGM_VOLUME_LEVELS[_bgm_volume_index]["db"])


func bgm_volume_label() -> String:
	return BGM_VOLUME_LEVELS[_bgm_volume_index]["label"]


func play_bgm(track: String) -> void:
	if track == _current_bgm:
		return
	if not BGM.has(track):
		push_warning("AudioManager: 알 수 없는 BGM '%s'" % track)
		return
	_current_bgm = track
	_bgm_player.stream = BGM[track]
	_bgm_player.play()


## SFX는 겹쳐 재생될 수 있어(연타 공격 등) 재생마다 임시 플레이어를 만들고
## 끝나면 스스로 정리한다 - ponytail: 풀링 없이 매번 생성/해제, SFX 빈도가
## 낮은 토이 게임이라 충분함. 나중에 초당 수십 회씩 쏟아지면 풀로 바꿀 것.
func play_sfx(name: String) -> void:
	if not SFX.has(name):
		push_warning("AudioManager: 알 수 없는 SFX '%s'" % name)
		return
	var p := AudioStreamPlayer.new()
	p.stream = SFX[name]
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	# 웹(HTML5) 빌드는 AudioStreamPlayer.finished가 압축 포맷에서 안 터지는 경우가
	# 알려져 있다 - 그러면 정리가 영영 안 돼 노드가 계속 쌓이고, 전투가 길어질수록
	# (히트가 잦을수록) 프레임이 서서히 죽어 "멈춘 것처럼" 보일 수 있다. finished만
	# 믿지 않고 재생 길이+여유로 강제 정리하는 보험을 하나 더 둔다. p를 캡처하는
	# 람다로 감싸면 이미 해제된 뒤 호출될 때 "Lambda capture was freed" 에러가
	# 나서(실측 확인) - p.queue_free를 직접 연결(다른 Callable 바인딩과 동일하게
	# 이미 해제된 대상이면 조용히 무시됨).
	get_tree().create_timer(p.stream.get_length() + 0.5).timeout.connect(p.queue_free)
