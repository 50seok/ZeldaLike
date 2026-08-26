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

## 방 배경(§5 "게임 배경화면") - 낱장으로 잘라둔 16x16 바닥 타일 하나를 반복
## 샘플링해서 채운다. 시트 그대로 AtlasTexture+region으로 하면 GPU가 시트
## 전체 기준으로 반복(wrap)해서 옆 타일이 새어 들어올 위험이 있어(실측 없이도
## 알려진 함정), 미리 낱장 PNG로 잘라둔 파일을 쓴다.
const FLOOR_STONE: Texture2D = preload("res://assets/sprites/tiny_dungeon/floor_stone.png")
const FLOOR_SAND: Texture2D = preload("res://assets/sprites/tiny_dungeon/floor_sand.png")

## "Tiny Town"(Kenney, CC0) - Tiny Dungeon과 짝을 이루는 마을/야외 팩. 실측
## 지적("배경이 조잡함, 마을답게/던전답게/초원답게 보여야 함")으로 도입 -
## 이제부터 방 배경은 반복 단일타일이 아니라 이 시트로 실제 레벨(잔디+길+
## 나무+건물)을 그린다.
const TINY_TOWN: Texture2D = preload("res://assets/sprites/tiny_town/tilemap_packed.png")
const TINY_TOWN_COLS := 12


## 시트 하나를 통째로 TileMap용 TileSet으로 등록한다(칸 전체를 다 등록해두면
## 나중에 다른 타일이 더 필요해져도 새 TileSet을 안 만들어도 됨).
static func build_tileset(sheet: Texture2D, cols: int, rows: int) -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	var source := TileSetAtlasSource.new()
	source.texture = sheet
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for row in range(rows):
		for col in range(cols):
			source.create_tile(Vector2i(col, row))
	ts.add_source(source)
	return ts


static func tile(sheet: Texture2D, index: int, cols: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	var col := index % cols
	var row := index / cols
	atlas.region = Rect2(col * TILE_SIZE, row * TILE_SIZE, TILE_SIZE, TILE_SIZE)
	return atlas


static func make_tiled_floor(floor_texture: Texture2D, area: Rect2, tint: Color = Color.WHITE) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = floor_texture
	sprite.centered = false
	sprite.position = area.position
	sprite.region_enabled = true
	sprite.region_rect = Rect2(Vector2.ZERO, area.size)
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sprite.modulate = tint
	sprite.z_index = -10  # 캐릭터·몬스터·문 등 다른 모든 것보다 뒤에 그려지게
	return sprite
