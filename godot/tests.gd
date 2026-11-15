extends SceneTree
## 규칙 자체 테스트 (Python 쪽 자체 테스트와 같은 경우들):  godot --headless --script godot/tests.gd

var failed := 0


func ok(cond: bool, what: String) -> void:
	if not cond:
		failed += 1
		printerr("실패: ", what)


func _initialize() -> void:
	# --- 조립 (pcbuild.py) ---
	var b := PCBuild.new()
	ok(b.check("mb2") == "케이스부터 끼워야 해요", "케이스 먼저")
	b.place("case1")
	ok("안 들어가요" in b.check("mb3"), "ATX 보드 → 미니 케이스")
	b.place("mb2")
	ok(b.check("cpu2") == "소켓 레버를 먼저 열어 주세요", "레버")
	b.toggle_lever()
	ok("소켓" in b.check("cpu1"), "AM CPU → LGA 보드")
	b.place("cpu2")
	b.toggle_lever()
	ok("옆판" in b.check("cool2") and "너무 길어요" in b.check("gpu2") and b.check("ram1", 2) != "", "쿨러 높이 · GPU 길이 · RAM 슬롯")
	b.place("cool1"); b.place("psu1"); b.plug("24pin")
	ok(b.post()[0] == -1 and "전원 버튼" in b.post()[1], "전원 버튼선")
	b.plug("front"); b.plug("cpu8")
	ok("서멀" in b.post()[1], "구리스 없이 쿨러")
	b.remove("COOLER"); b.apply_paste(); b.place("cool1")
	ok(b.post()[0] == 1, "RAM 없음")
	b.place("ram1", 0); b.place("gpu1")
	ok(b.post()[0] == 3 and "SSD" in b.post()[1], "SSD 없음")
	b.place("ssd1")
	ok(b.boots() and b.throttled() and b.perf() == 4 + 1 + 3 - 3, "부팅 · 쓰로틀링 · 성능 %d" % b.perf())
	var out := b.remove("MB")
	out.sort()
	ok(out == ["cool1", "cpu2", "gpu1", "mb2", "ram1", "ssd1"] and b.cables.is_empty() and not b.paste, "보드를 빼면 위의 것도 다 빠짐")
	var good := PCBuild.full()
	ok(good.boots() and good.dual_channel() and good.perf() == 13, "기본 완성 PC 성능 13: %d" % good.perf())
	ok(PCBuild.full({"psu": "psu1"}).post()[0] == 2, "400W 파워엔 GPU 전원선 없음")
	var top := PCBuild.full({"case": "case3", "cpu": "cpu3", "mb": "mb3", "cooler": "cool2", "gpu": "gpu3", "psu": "psu3", "ram": ["ram3", "ram3"]})
	ok(top.boots() and top.stars() == 3 and top.watt() == 520 and top.perf() == 26, "최고 사양")

	# --- 배치 (room.py) ---
	var placed := []
	ok(Rules.fits_at(placed, "monitor", "desk", 306, Rules.DESK_Y) and not Rules.fits_at(placed, "monitor", "wall", 306, 450), "레이어")
	var lamp := Rules.place_slot(placed, "lamp_warm", "desk", 0)
	ok(not Rules.fits_at(placed, "book", "desk", lamp["x"] + 10, Rules.DESK_Y), "겹침 금지")
	var book := {"id": "book", "layer": "desk", "x": lamp["x"] + DB.size_of("lamp_warm").x + 10, "y": Rules.DESK_Y}
	placed.append(book)
	var mz := {"id": "monitor", "layer": "desk", "x": 400, "y": Rules.DESK_Y, "z": 0}
	ok(not Rules.fits_at([mz], "monitor", "desk", 400, Rules.DESK_Y, null, 30) and Rules.fits_at([mz], "monitor", "desk", 400, Rules.DESK_Y, null, 100), "탑뷰: 앞뒤로 비키면 같은 x에 놓임")
	ok(Rules.free_z([mz], "monitor", 400) == Rules.depth_of("monitor") and not Rules.fits_at([], "monitor", "desk", 400, Rules.DESK_Y, null, 350), "빈 앞뒤 자리 · 책상 밖")
	ok(Rules.adjacent(lamp, book) and Rules.fits_at(placed, "mug", "desk", book["x"] + 20, Rules.DESK_Y, book), "인접 · 자기 자리 무시")
	ok(Rules.drop_target("frame", 500, 100) == null and Rules.drop_target("mug", 10, 300) == ["desk", Rules.AREA_X1, Rules.DESK_Y], "놓을 자리")

	# --- 배선 (cables.py) ---
	placed = []
	var mon := Rules.place_slot(placed, "monitor", "desk", 0)
	var kb := Rules.place_slot(placed, "keyboard", "desk", 2)
	var pc := PCBuild.full({"gpu": "gpu1", "psu": "psu1"})
	ok(Rules.port_count("DP", pc) == 1 and Rules.port_count("USB", pc) == 4 and Rules.port_count("DP", PCBuild.new()) == 0, "포트 수")
	var wired := [{"dev": mon, "type": "DP", "port": 0}, {"dev": kb, "type": "USB", "port": 0}]
	ok(Rules.wiring_score(wired, placed) == [10.0, 0, 0], "배선 만점")
	var sp := Rules.place_slot(placed, "speaker", "desk", 4)
	var tangled := [{"dev": kb, "type": "AUDIO", "port": 1}, {"dev": sp, "type": "USB", "port": 0}]
	ok(Rules.crossings(tangled) == 1, "꼬임 1")
	ok(Rules.prune(wired, placed, PCBuild.new()).is_empty(), "부품이 없으면 선이 뽑힘")

	# --- 채점 (scorer.py) ---
	var dev: Dictionary = DB.REQUESTS.filter(func(r): return r["customer"] == "밤샘 개발자")[0]
	placed = []
	for s in [["lamp_warm", "desk", 0], ["book", "desk", 1], ["monitor", "desk", 2], ["monitor", "desk", 4], ["wall_light", "wall", 0]]:
		Rules.place_slot(placed, s[0], s[1], s[2])
	wired = [{"dev": placed[2], "type": "DP", "port": 0}, {"dev": placed[3], "type": "DP", "port": 1}]
	var syn := Rules.synergies(placed, good)
	ok("독서 콤보" in syn and "균형 조명" in syn and syn.size() == 2, "시너지 %s" % [syn])
	var r := Rules.score(dev, placed, good, wired)
	ok(r["parts"]["필수 · 금지"] == 25 and r["parts"]["PC 성능"] == 20 and r["parts"]["배선"] == 15 and r["total"] == 96 and r["stars"] == 3, "채점 %s" % [r])
	ok("케이블" in Rules.score(dev, placed, good, [])["line"], "선 안 꽂음")
	Rules.place_slot(placed, "lamp_cool", "desk", 6)
	var bad := Rules.score(dev, placed, PCBuild.full({"psu": "psu1"}), wired)
	ok(bad["parts"]["PC 성능"] == 0 and bad["parts"]["필수 · 금지"] == 12.5 and "VGA" in bad["line"], "금지 소품 · 부팅 실패")

	# --- 가게 (state.py) ---
	Game.new_game()
	ok(Game.money == 200 and Game.todays_requests().size() == 3 and not Game.add_to_cart("cpu3"), "새 게임 · 잠긴 상품")
	Game.add_to_cart("monitor", 2); Game.add_to_cart("monitor", -1)
	var rc := Game.checkout()
	ok(rc["total"] == 25 and Game.money == 175 and Game.stock["monitor"] == 1 and Game.cart.is_empty(), "결제")
	Game.add_to_cart("cpu6", 100)
	ok(Game.checkout().is_empty(), "돈이 모자라면 결제 안 됨")
	Game.cart.clear()
	ok(Game.sell_back("monitor") and Game.money == 187, "반품 반값")
	ok(not Game.buy_upgrade("gamer"), "레벨 2부터")
	Game.stars_total = 3
	ok(Game.level() == 2 and Game.buy_upgrade("gamer") and Game.add_to_cart("mic"), "레벨업 → 게이밍 라인")
	Game.stars_total = 0
	Game.cart.clear()
	Game.placed = [{"id": "lamp_warm", "layer": "desk", "x": 306, "y": 210}]
	var before := Game.money
	ok(Game.settle({"stars": 2}) == [120, 12] and Game.money == before + 132 and Game.ledger[-1]["cost"] == 4, "정산")
	ok(Game.settle({"stars": 0}) == [0, 0], "별 0개는 0원")
	Game.history["자취 1년차 대학생"] = 3
	var regular: Dictionary = DB.REQUESTS.filter(func(q): return q.get("returns", false) and q["customer"] == "자취 1년차 대학생")[0]
	ok("학점" in Game.lines(regular)[0], "단골 대사")

	# --- 저장 ---
	Game.pc = PCBuild.full()
	Game.placed = []
	var m2 := Rules.place_slot(Game.placed, "monitor", "desk", 2)
	Game.cables = [{"dev": m2, "type": "DP", "port": 0}]
	Game.cart = {"book": 1}
	var money_then := Game.money
	Game.save("build")
	Game.new_game()
	ok(Game.load_save() == "build" and Game.money == money_then and Game.cart == {"book": 1} and Game.pc.boots()
		and is_same(Game.cables[0]["dev"], Game.placed[0]) and Game.placed[0]["x"] is int, "저장 · 이어하기")
	Game.delete_save()

	print("godot rules ok" if failed == 0 else "godot rules FAILED: %d" % failed)
	quit(1 if failed else 0)
