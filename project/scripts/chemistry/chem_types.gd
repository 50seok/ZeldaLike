class_name ChemTypes

## PRD §2.2 재질 태그. NONE = 반응 규칙표에서 "와일드카드(아무거나)"로 쓰임.
## 이름이 MaterialTag인 이유: "Material"은 Godot 내장 클래스(셰이더 머티리얼)와 충돌한다(실측 확인).
enum MaterialTag { NONE, WOOD, METAL, GRASS, CLOTH, WATER, ICE }

## PRD §2.3 상태. NONE = "상태 없음" 이자 반응 규칙표의 와일드카드.
enum State { NONE, BURNING, WET, CHARGED, FROZEN }
