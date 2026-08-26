class_name ItemIds

## PRD §3.3 MVP 아이템 목록의 소모/진행/수집 아이템 ID. 장비(칼/방패/활)는 별도
## 필드(Player.sword_material 등)로 관리하므로 여기 없다 — 인벤토리는 "개수"가
## 의미 있는 아이템만 다룬다.

const HEART := "heart"
const ARROW := "arrow"
const SMALL_KEY := "small_key"
const BOSS_KEY := "boss_key"
const HEART_PIECE := "heart_piece"

const _DISPLAY_NAMES := {
	HEART: "하트",
	ARROW: "화살",
	SMALL_KEY: "작은 열쇠",
	BOSS_KEY: "보스 열쇠",
	HEART_PIECE: "하트조각",
}

## §3.2 "획득 연출·징글"은 흔한 소모품(하트/화살)까지 매번 띄우면 성가시다 -
## 진행에 의미 있는 아이템(열쇠류·하트조각)만 특별 취급한다.
const _NOTABLE := [SMALL_KEY, BOSS_KEY, HEART_PIECE]


static func display_name(item_id: String) -> String:
	return _DISPLAY_NAMES.get(item_id, item_id)


static func is_notable(item_id: String) -> bool:
	return item_id in _NOTABLE
