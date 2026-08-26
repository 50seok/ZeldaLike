class_name SpriteUtil

## §3.2/5 "그래픽 에셋" - Kenney "Tiny" 시리즈(CC0) 2팩(Tiny Dungeon + 커뮤니티
## 확장 Tiny Creatures, 같은 16px 스타일이라 "단일 팩"에 준하는 통일감)에서
## 타일 하나를 잘라 쓰는 공용 헬퍼. 인덱스는 각 시트를 균등 격자로 잘랐을 때의
## 순번(왼쪽위 0부터 가로로 증가) - 에셋 배포 시 인덱스별 이름표가 따로 없어서
## 미리보기 이미지를 좌표 격자로 잘라 직접 확인해 골랐다.

const TILE_SIZE := 16

const TINY_DUNGEON: Texture2D = preload("res://assets/sprites/tiny_dungeon/tilemap_packed.png")
const TINY_DUNGEON_COLS := 12

const TINY_CREATURES: Texture2D = preload("res://assets/sprites/tiny_creatures/tilemap_packed.png")
const TINY_CREATURES_COLS := 10


static func tile(sheet: Texture2D, index: int, cols: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	var col := index % cols
	var row := index / cols
	atlas.region = Rect2(col * TILE_SIZE, row * TILE_SIZE, TILE_SIZE, TILE_SIZE)
	return atlas
