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
}

var _bgm_player: AudioStreamPlayer
var _current_bgm: String = ""


func _ready() -> void:
	_bgm_player = AudioStreamPlayer.new()
	add_child(_bgm_player)
	_bgm_player.finished.connect(func(): _bgm_player.play())


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
