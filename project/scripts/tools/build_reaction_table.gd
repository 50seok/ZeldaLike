extends SceneTree

## 일회성 빌드 도구. `godot --headless --script res://scripts/tools/build_reaction_table.gd`로 실행.
## .tres를 손으로 쓰는 대신 코드로 정확히 생성 — 중첩 리소스 배열 형식 오류를 피하기 위함.
## PRD §2.4 필수 반응 최소셋 6종을 여기서 데이터로 정의한다.

func _initialize() -> void:
	var rules: Array[ReactionRule] = []

	# 1. 불 + 나무/풀/천 -> 착화 (재질별 3줄 — 코드 분기가 아니라 데이터 행 추가일 뿐)
	var flammables: Array[int] = [ChemTypes.MaterialTag.GRASS, ChemTypes.MaterialTag.WOOD, ChemTypes.MaterialTag.CLOTH]
	for mat in flammables:
		var r := ReactionRule.new()
		r.state_a = ChemTypes.State.BURNING
		r.material_b = mat
		r.affects_b = true
		r.result_state_b = ChemTypes.State.BURNING
		r.description = "불 접촉 -> %s 착화" % ChemTypes.MaterialTag.keys()[mat]
		rules.append(r)

	# 2. 불붙은 풀 + 풀 -> 인접 전파 (배치 방향으로 "바람 방향" 연출)
	# ponytail: 전역 바람 벡터 필드는 Post-MVP. 지금은 접촉 연쇄로 방향성 배치를 시연한다.
	var r_wind := ReactionRule.new()
	r_wind.material_a = ChemTypes.MaterialTag.GRASS
	r_wind.state_a = ChemTypes.State.BURNING
	r_wind.material_b = ChemTypes.MaterialTag.GRASS
	r_wind.affects_b = true
	r_wind.result_state_b = ChemTypes.State.BURNING
	r_wind.description = "불붙은 풀 -> 인접 풀 연쇄 전파"
	rules.append(r_wind)

	# 3. 물 + 불붙음 -> 소화 + 젖음
	var r_water := ReactionRule.new()
	r_water.material_a = ChemTypes.MaterialTag.WATER
	r_water.state_b = ChemTypes.State.BURNING
	r_water.affects_b = true
	r_water.result_state_b = ChemTypes.State.WET
	r_water.description = "물 접촉 -> 불붙은 대상 소화, WET 부여"
	rules.append(r_water)

	# 5. 전기 + 젖음 -> 감전 (4번보다 먼저 검사해야 한다 — try_apply는 첫 매치에서
	# 멈추는데, "금속이면 무조건 전도"가 "젖은 금속" 케이스까지 삼켜버려서 감전이
	# 아예 발동을 못 했다(실측 확인: 아이언셸이 물에 젖어도 전기 화살에 전도만
	# 되고 감전 스턴이 안 걸림). 젖음처럼 더 구체적인 조건을 먼저 둔다.
	var r_shock := ReactionRule.new()
	r_shock.state_a = ChemTypes.State.CHARGED
	r_shock.state_b = ChemTypes.State.WET
	r_shock.affects_b = true
	r_shock.shock_b = true
	r_shock.description = "전기 접촉 -> 젖은 대상 감전 (피해는 M2 전투에서 연동)"
	rules.append(r_shock)

	# 4. 전기 + 금속(안 젖은 상태) -> 전도
	var r_conduct := ReactionRule.new()
	r_conduct.state_a = ChemTypes.State.CHARGED
	r_conduct.material_b = ChemTypes.MaterialTag.METAL
	r_conduct.affects_b = true
	r_conduct.result_state_b = ChemTypes.State.CHARGED
	r_conduct.description = "전기 접촉 -> 금속으로 전도"
	rules.append(r_conduct)

	# 6. 불 + 얼음 -> 해빙
	var r_thaw := ReactionRule.new()
	r_thaw.state_a = ChemTypes.State.BURNING
	r_thaw.material_b = ChemTypes.MaterialTag.ICE
	r_thaw.state_b = ChemTypes.State.FROZEN
	r_thaw.affects_b = true
	r_thaw.result_state_b = ChemTypes.State.NONE
	r_thaw.convert_material_b = ChemTypes.MaterialTag.WATER
	r_thaw.description = "불 접촉 -> 얼음 해빙, 물로 전환"
	rules.append(r_thaw)

	var table := ReactionTable.new()
	table.rules = rules

	var dir := DirAccess.open("res://resources/reactions")
	if dir == null:
		DirAccess.make_dir_recursive_absolute("res://resources/reactions")

	var err := ResourceSaver.save(table, "res://resources/reactions/mvp_reaction_table.tres")
	if err == OK:
		print("OK: mvp_reaction_table.tres saved with %d rules" % rules.size())
	else:
		print("FAIL: save error %d" % err)
	quit()
