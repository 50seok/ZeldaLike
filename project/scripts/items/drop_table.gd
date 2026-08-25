class_name DropTable
extends Resource

## §3.3 상태 조건부 드랍 — "파괴 시점의 상태에 따라 다른 테이블 참조".
## MVP는 조건 축을 기본/BURNING 2개로 제한(폭발 방지, PRD 리스크 대응).
## 화학엔진(ReactionTable)과 같은 원칙: 반응/드랍 모두 하드코딩이 아니라
## .tres 데이터 — 확률·품목 조정에 코드 수정이 필요 없다.

@export var default_drops: Array[DropEntry] = []
@export var burning_drops: Array[DropEntry] = []


func roll(state_at_destruction: int) -> Array:
	# burning_drops를 비워두면 "태우면 드랍 없음"이 된다(§3.3 수풀 예시 그대로) —
	# 태웠을 때도 기본과 같은 드랍을 원하면 같은 항목을 burning_drops에도 채운다.
	var pool: Array[DropEntry] = default_drops
	if state_at_destruction == ChemTypes.State.BURNING:
		pool = burning_drops

	var results: Array = []
	for entry in pool:
		if randf() <= entry.chance:
			results.append({"item_id": entry.item_id, "count": entry.roll_count()})
	return results
