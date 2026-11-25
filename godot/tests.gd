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
	ok(b.post()[0] == 3 and "나사" in b.post()[1], "SSD 나사 안 조임")
	for t in b.screws:
		b.screws[t].fill(true)
	ok(b.boots() and b.throttled() and b.perf() == 4 + 1 + 3 - 3, "부팅 · 쓰로틀링 · 성능 %d" % b.perf())
	var out := b.remove("MB")
	out.sort()   # 새 부품은 id 문자열로 돌아옴
	ok(out == ["cool1", "cpu2", "gpu1", "mb2", "ram1", "ssd1"] and b.cables.is_empty() and not b.paste, "보드를 빼면 위의 것도 다 빠짐")
	var good := PCBuild.full()
	ok(good.boots() and good.dual_channel() and good.perf() == 13, "기본 완성 PC 성능 13: %d" % good.perf())
	ok(PCBuild.full({"psu": "psu1"}).post()[0] == 2, "400W 파워엔 GPU 전원선 없음")
	var top := PCBuild.full({"case": "case3", "cpu": "cpu3", "mb": "mb3", "cooler": "cool2", "gpu": "gpu3", "psu": "psu3", "ram": ["ram3", "ram3"]})
	ok(top.boots() and top.stars() == 3 and top.watt() == 520 and top.perf() == 26, "최고 사양")

	# --- 배치 (room.py) ---
	var placed := []
	ok(Rules.fits_at(placed, "monitor", "desk", 360, Rules.DESK_Y) and not Rules.fits_at(placed, "monitor", "wall", 306, 450), "레이어")
	var lamp := Rules.place_slot(placed, "lamp_warm", "desk", 0)
	ok(not Rules.fits_at(placed, "book", "desk", lamp["x"] + 10, Rules.DESK_Y), "겹침 금지")
	var book := {"id": "book", "layer": "desk", "x": lamp["x"] + DB.size_of("lamp_warm").x + 10, "y": Rules.DESK_Y}
	placed.append(book)
	var mz := {"id": "monitor", "layer": "desk", "x": 400, "y": Rules.DESK_Y, "z": 0}
	ok(not Rules.fits_at([mz], "monitor", "desk", 400, Rules.DESK_Y, null, 30) and Rules.fits_at([mz], "monitor", "desk", 400, Rules.DESK_Y, null, Rules.depth_of("monitor")), "탑뷰: 앞뒤로 비키면 같은 x에 놓임")
	ok(Rules.free_z([mz], "monitor", 400) == Rules.depth_of("monitor") and not Rules.fits_at([], "monitor", "desk", 400, Rules.DESK_Y, null, 350), "빈 앞뒤 자리 · 책상 밖")
	ok(not Rules.fits_at([], "monitor_curve", "desk", Rules.AREA_X2 - 100, Rules.DESK_Y) and Rules.drop_target("keyboard", 0, Rules.DESK_Y) != null and Rules.fits_at([], "keyboard", "desk", Rules.drop_target("keyboard", 0, Rules.DESK_Y)[1], Rules.DESK_Y), "실제 크기도 책상 안에")
	# 현실적인 배치: 키보드는 모니터 앞, 마우스는 키보드 오른쪽, 라이트바는 모니터 위 (모니터 따라 이동)
	var mn := {"id": "monitor", "layer": "desk", "x": 500, "y": Rules.DESK_Y, "z": 0}
	var kc: Array = Rules.magnet([mn], "keyboard", 470, -1)[0]
	ok(absf(kc[0] + DB.size_of("keyboard").x / 2.0 - Rules.center_x(mn)) < 1 and kc[1] == Rules.depth_of("monitor") + 10, "키보드 → 모니터 앞 가운데")
	var kbd := {"id": "keyboard", "layer": "desk", "x": kc[0], "y": Rules.DESK_Y, "z": kc[1]}
	var mc: Array = Rules.magnet([mn, kbd], "mouse_vertical", kc[0] + 200, -1)[0]
	ok(Rules.foot_x("mouse_vertical", mc[0]).x > Rules.foot_x("keyboard", kbd["x"]).y, "마우스 → 키보드 오른쪽")
	ok(Rules.magnet([], "monitor", 600, 250)[0][1] == 0, "모니터는 벽쪽으로 끌림")
	var bar := {"id": "monitor_bar", "layer": "desk", "host": mn, "slot": 0}
	var cam := {"id": "webcam", "layer": "desk", "host": mn, "slot": 1}
	var lay := [mn, kbd, bar, cam]
	Rules.sync_mounts(lay)
	ok(absf(Rules.center_x(bar) - Rules.center_x(mn)) < 1 and Rules.rect_of(bar)[1] < Rules.rect_of(mn)[3] and Rules.rect_of(bar)[3] > Rules.rect_of(mn)[3] and Rules.free_slot(lay, mn) == -1, "라이트바 · 웹캠 → 모니터 위")
	mn["x"] = 700
	Rules.sync_mounts(lay)
	ok(absf(Rules.center_x(bar) - Rules.center_x(mn)) < 1 and Rules.mounts_on(lay, mn).size() == 2, "모니터 옮기면 따라감")
	var hs := {"id": "headset", "layer": "desk", "x": 400}
	Rules.mount_pos(hs)
	ok(Rules.rect_of(hs)[3] > Rules.DESK_Y and Rules.rect_of(hs)[3] < Rules.DESK_Y + 20 and not Rules.edge_fits([hs], "headset", 420), "헤드셋 → 책상 모서리 걸이, 겹치지 않게")
	# 성능 테스트: 병목 · 발열 · 소음 · 고치는 방법
	var all := func(_p): return true
	var fps144 := {"kind": "game", "genre": "fps", "res": "1080p", "fps": 144}
	var weak_cpu := Bench.run({"CPU": "cpu1", "GPU": "gpu3", "RAM": ["ram2", "ram2"], "COOLER": "cool2", "CASE": "case2", "MB": "mb1"}, fps144)
	ok(weak_cpu["limit"] == "CPU" and not weak_cpu["ok"] and weak_cpu["value"] < 144, "CPU 병목: 비싼 그래픽카드도 소용없음")
	var fixed := Bench.fix({"CPU": "cpu1", "GPU": "gpu3", "RAM": ["ram2", "ram2"], "COOLER": "cool2", "CASE": "case2", "MB": "mb1"}, fps144, all)
	ok(fixed.get("type") == "CPU" and fixed["value"] >= 144, "고치는 방법: CPU 바꾸기")
	var basic := func(p): return not p.has("line")   # 업그레이드 전 가게
	var stream := {"kind": "game", "genre": "fps", "res": "1080p", "fps": 170, "stream": true}   # 같은 소켓(AM) 중급으론 모자람
	var swap := Bench.fix({"CPU": "cpu1", "GPU": "gpu3", "RAM": ["ram2", "ram2"], "COOLER": "cool2", "CASE": "case3", "MB": "mb1"}, stream, basic)
	ok(swap.get("type") == "CPU" and DB.PARTS[swap["id"]]["socket"] == "LGA" and swap["mb"] != "", "소켓이 다르면 보드까지 같이 추천 %s" % [swap])
	var hot := Bench.run({"CPU": "cpu3", "GPU": "gpu2", "RAM": ["ram2", "ram2"], "COOLER": "cool1", "CASE": "case1"}, fps144)
	ok(hot.get("shutdown", false) and not hot["ok"], "쿨러가 턱없이 모자라면 과열로 꺼짐")
	var warm := Bench.run({"CPU": "cpu2", "GPU": "gpu2", "RAM": ["ram2", "ram2"], "COOLER": "cool1", "CASE": "case1"}, fps144)
	ok(warm["cpu_temp"] >= 90 and warm["cpu_temp"] < 100 and warm["notes"].any(func(n): return n.contains("뜨거워")), "쿨러 조금 부족 → 스로틀링")
	var quiet := {"kind": "office", "quiet": 30}
	ok(not Bench.run({"CPU": "cpu1", "GPU": "gpu1", "RAM": ["ram2"], "COOLER": "cool1", "CASE": "case2"}, quiet)["ok"] and Bench.run({"CPU": "cpu1", "GPU": "gpu1", "RAM": ["ram2"], "COOLER": "cool2", "CASE": "case2"}, quiet)["ok"], "기본 쿨러는 시끄러움")
	ok(Bench.run({"CPU": "cpu5", "GPU": "gpu2", "RAM": ["ram3", "ram3"], "COOLER": "cool2", "CASE": "case2"}, {"kind": "render", "min": 8})["ok"], "렌더 8분")
	for req in DB.REQUESTS:   # 모든 손님 목표는 예산 안에서 달성 가능해야 함
		var u: Dictionary = req["use"]
		ok(u["kind"] == "office" or Bench.run({"CPU": "cpu3" if u["kind"] != "game" else "cpu5", "GPU": "gpu6", "RAM": ["ram3", "ram3"], "COOLER": "cool3", "CASE": "case3"}, u)["ratio"] >= 1.0, "달성 가능: " + req["customer"])
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
	ok(Rules.crossings(tangled, placed) == 1, "꼬임 1")
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
	ok(Rules.kind_of(dev) == "full" and r["parts"]["PC 성능"] == 28.5 and r["parts"]["모니터"] == 10 and r["parts"]["배선"] == 5 and r["stars"] >= 2, "PC + 데스크 의뢰 채점 (기본 쿨러라 빌드가 목표보다 조금 느림) %s" % [r])
	ok("케이블" in Rules.score(dev, placed, good, [])["line"], "선 안 꽂음")
	Rules.place_slot(placed, "lamp_cool", "desk", 6)
	var bad := Rules.score(dev, placed, PCBuild.full({"psu": "psu1"}), wired)
	ok(bad["parts"]["PC 성능"] == 0 and bad["parts"]["필수 · 금지"] == 7.5 and "VGA" in bad["line"], "금지 소품 · 부팅 실패")

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
	var paid_now := Game.settle({"stars": 2})
	ok(paid_now == [120, 12] and Game.money == before + 132 + Game.ACHV["first"][2] and Game.ledger[-1]["cost"] == 4, "정산")
	ok(Game.settle({"stars": 0}) == [0, 0], "별 0개는 0원")
	Game.history["자취 1년차 대학생"] = 3
	var regular: Dictionary = DB.REQUESTS.filter(func(q): return q.get("returns", false) and q["customer"] == "자취 1년차 대학생")[0]
	ok("학점" in Game.lines(regular)[0], "단골 대사")

	# --- 수리 의뢰: 고장 난 채로 와서, 원인을 고치면 별 3개 ---
	var fixes := {"재택근무 회사원": func(b: PCBuild): b.faults.erase("monitor_mb"),
		"웹소설 작가": func(b: PCBuild): b.faults.erase("cpu_fan"),
		"동네 카페 사장님": func(b: PCBuild): b.faults.erase("ram_seat"),
		"손녀 바보 할머니": func(b: PCBuild): b.faults.clear(),
		"은퇴한 교수님": func(b: PCBuild): b.faults.erase("cap_bulge"),
		"프로게이머 지망생": func(b: PCBuild):   # 쿨러 떼기 → 굳은 구리스 닦기 → 새로 바르기 → 쿨러 → BIOS XMP
			b.remove("COOLER")
			b.apply_paste()
			b.place("cool2")
			b.screws["COOLER"].fill(true)
			b.faults.erase("xmp_off")}
	for i in DB.REQUESTS.size():
		var q: Dictionary = DB.REQUESTS[i]
		if not q.has("repair"):
			continue
		Game.day = q["day"]
		Game.order_index = Game.todays_requests().find(q)
		Game.reset_order()
		ok(Game.spent() == 0 and Rules.score(q, [], Game.pc, [])["stars"] == 0 and Game.difficulty(q) >= 1, "수리 전엔 증상: " + q["customer"])
		fixes[q["customer"]].call(Game.pc)
		var rs := Rules.score(q, [], Game.pc, [])
		ok(rs["stars"] == 3 and Game.spent() <= q["budget"], "수리 후 %s %s 비용 %d" % [q["customer"], rs, Game.spent()])
	var old: Dictionary = Game.pc.remove("RAM", 1)[0]   # 손님 헌 RAM은 상태째로 나옴 → 중고 창고에 남아 다음에 씀
	ok(old["id"] == "ram2" and old["paid"] == 0 and old["cond"] < 100, "손님 헌 부품 %s" % [old])

	# --- 중고 · 노후화 ---
	Game.new_game()
	Game.money = 999
	var os := Game.offers()
	ok(os.size() == 3 and Game.offers() == os, "오늘 매물 3개 (날짜로 고정)")
	ok(Game.buy_offer(os[0]) and Game.used.size() == 1 and Game.offers().size() == 2 and Game.money == 999 - os[0]["price"], "중고 구매")
	var lie_seen := false
	for dd in range(1, 40):   # 판매자 말과 실제 상태가 다른 매물이 있어야 '모르면 손해'
		Game.day = dd
		for o in Game.offers():
			lie_seen = lie_seen or (o["claim"].contains("새것") and o["cond"] < 55)
	ok(lie_seen, "상태를 부풀린 매물")
	var oldpsu := PCBuild.full({"case": "case3", "cpu": "cpu5", "mb": "mb1", "cooler": "cool2", "gpu": "gpu3", "psu": "psu3"})
	var fps_use := {"kind": "game", "genre": "fps", "res": "1080p", "fps": 144}
	ok(not Bench.run(Bench.parts_of(oldpsu), fps_use).get("shutdown", false), "새 파워는 버팀")
	oldpsu.used["PSU"] = {"id": "psu3", "cond": 25, "paid": 4, "known": false}
	ok(Bench.run(Bench.parts_of(oldpsu), fps_use).get("shutdown", false), "낡은 파워(25%)는 부하에 꺼짐")
	oldpsu.used["COOLER"] = {"id": "cool2", "cond": 40, "paid": 1, "known": false}
	oldpsu.used.erase("PSU")
	var worn := Bench.run(Bench.parts_of(oldpsu), fps_use)
	ok(worn["cpu_temp"] > Bench.run(Bench.parts_of(PCBuild.full({"case": "case3", "cpu": "cpu5", "mb": "mb1", "cooler": "cool2", "gpu": "gpu3", "psu": "psu3"})), fps_use)["cpu_temp"], "낡은 쿨러는 더 뜨거움")
	Game.pc = oldpsu
	ok(Game.spent() == 1 + DB.PARTS["case3"]["price"] + DB.PARTS["cpu5"]["price"] + 8 + DB.PARTS["gpu3"]["price"] + DB.PARTS["psu3"]["price"] + 10 + 5, "중고는 산 값으로 계산 %d" % Game.spent())
	Game.new_game()

	# --- 도감 · 업적 · 일일 목표 ---
	Game.new_game()
	for q in DB.REQUESTS:
		if q.has("repair") and q["customer"] == "동네 카페 사장님":
			Game.day = q["day"]
			Game.order_index = Game.todays_requests().find(q)
	Game.ledger = []
	Game.reset_order()
	Game.pc.faults.clear()
	var m0 := Game.money
	Game.settle(Rules.score(Game.request(), [], Game.pc, []))
	ok(Game.dex.has("f:ram_seat") and Game.dex.has("p:cpu6") and Game.achv.has("first") and "first" in Game.new_achv, "도감 · 첫 납품 업적 %s" % [Game.new_achv])
	ok("silent" in Game.new_achv and Game.money == m0 + Game.ledger[0]["pay"] + Game.ledger[0]["tip"] + Game.new_achv.reduce(func(a, k): return a + Game.ACHV[k][2], 0), "업적 보상 (조용한 사무용 PC라 숨죽인 PC도)")
	Game.day = 4   # 목표: 수리 의뢰 별 3개 (카페 수리는 5일차 장부지만 목표 판정만 봄)
	ok(Game.daily()[2] == "repair3" and Game.daily_done() and Game.claim_daily() == Game.daily()[1] and Game.claim_daily() == 0, "일일 목표 보상은 한 번만")

	# --- 큰 목표 · 손님 이야기 ---
	ok(Game.visits["동네 카페 사장님"] == [3] and Game.epilogue("동네 카페 사장님").contains("두 배"), "단골 기록 · 좋은 뒷이야기")
	Game.history["웹소설 작가"] = 0
	ok(Game.epilogue("웹소설 작가").contains("휴재"), "나쁜 뒷이야기")
	Game.money = Game.goal() - 1
	ok(not Game.goal_met(), "목표 미달")
	for nm in DB.REQUESTS.map(func(q): return q["customer"]):
		ok(DB.STORY["epilogue"].has(nm), "뒷이야기 있음: " + nm)

	# --- 내장 그래픽: 사무용은 그래픽카드 없이 ---
	var office := PCBuild.full({"cpu": "cpu6", "mb": "mb2", "cooler": "cool1", "ram": ["ram2", "ram2"]})
	office.remove("GPU")
	ok(office.boots() and Rules.port_count("DP", office) == 1 and Rules.port_count("HDMI", office) == 1, "내장 그래픽이면 그래픽카드 없이 부팅")
	ok(Bench.run(Bench.parts_of(office), {"kind": "office"})["ok"], "사무용 테스트 OK")
	ok(Bench.run(Bench.parts_of(office), {"kind": "game", "genre": "fps", "res": "1080p", "fps": 144})["value"] < 60, "내장 그래픽으로 게임은 힘듦")
	var amd := PCBuild.full({"cpu": "cpu4", "mb": "mb1"})
	amd.remove("GPU")
	ok(amd.post()[0] == 2 and "내장" in amd.post()[1] and not Bench.run(Bench.parts_of(amd), {"kind": "office"}).has("noise"), "내장 그래픽 없는 CPU는 그래픽카드 필요")

	# --- 확장 부품 수치 ---
	var fps144s := {"kind": "game", "genre": "fps", "res": "1080p", "fps": 144, "stream": true}
	var base_pc := {"CPU": "cpu2", "GPU": "gpu1", "RAM": ["ram2", "ram2"], "COOLER": "cool2", "CASE": "case2", "MB": "mb3", "PSU": "psu3"}
	var with_enc := base_pc.duplicate()
	with_enc["GPU"] = "gpu8"
	ok(Bench.run(with_enc, fps144s)["cpu_fps"] > Bench.run(base_pc, fps144s)["cpu_fps"], "인코더 있는 그래픽카드는 방송 부담이 적음")
	var weak_mb := base_pc.duplicate()
	weak_mb["MB"] = "mb6"
	ok(Bench.run(weak_mb, fps144s)["cpu_fps"] < Bench.run(base_pc, fps144s)["cpu_fps"] and "VRM" in " ".join(Bench.run(weak_mb, fps144s)["notes"]), "약한 보드 전원부")
	var fast := base_pc.duplicate()
	fast["RAM"] = ["ram6", "ram6"]
	ok(Bench.run(fast, fps144s)["cpu_fps"] > Bench.run(base_pc, fps144s)["cpu_fps"], "빠른 RAM")
	var fake := base_pc.duplicate()
	fake["GPU"] = "gpu9"
	fake["PSU"] = "psu8"
	ok(Bench.run(fake, fps144s).get("shutdown", false), "인증 없는 700W는 부하에 꺼짐")
	var silent := base_pc.duplicate()
	silent["CASE"] = "case8"
	ok(Bench.run(silent, {"kind": "office"})["noise"] <= Bench.run(base_pc, {"kind": "office"})["noise"] - 4, "방음 케이스 -4dB")
	var bl := PCBuild.full()
	ok(bl.blockers("MB").size() >= 4 and bl.blockers("CASE") == ["MB", "PSU"] and bl.blockers("GPU").is_empty(), "위에 꽂힌 것부터 빼기 %s" % [bl.blockers("CASE")])

	# --- 모니터 암: 집게는 제자리, 모니터가 팔 길이보다 멀어지면 집게가 따라감 ---
	var mp := []
	var mon_a := Rules.place_slot(mp, "monitor_144", "desk", 2)
	var arm_p := {"id": "monitor_arm", "layer": "desk", "host": mon_a}
	Rules.mount_pos(arm_p)
	mp.append(arm_p)
	var x0: int = arm_p["x"]
	mon_a["x"] += 60
	Rules.sync_mounts(mp)
	ok(arm_p["x"] == x0, "조금 옮기면 집게는 그대로")
	mon_a["x"] += 400
	Rules.sync_mounts(mp)
	ok(absf(arm_p["x"] - Rules.center_x(mon_a)) <= Rules.ARM_REACH and "모니터 암 정리" in Rules.synergies(mp, PCBuild.new()), "멀리 옮기면 집게가 미끄러져 따라옴")

	# --- 고장 난 중고 · 새 제품만 손님 ---
	var dead_seen := false
	for dd in range(1, 30):
		Game.day = dd
		dead_seen = dead_seen or Game.offers().any(func(o): return o["dead"])
	ok(dead_seen, "가끔 아예 안 되는 중고")
	Game.day = 1
	var dpc := PCBuild.full()
	dpc.used["GPU"] = {"id": "gpu2", "cond": 80, "paid": 20, "known": false, "dead": true}
	ok(dpc.post()[0] == 2 and not "고장" in dpc.post()[1], "고장 난 중고 그래픽카드: VGA 불 (원인은 안 알려 줌)")
	var newonly: Dictionary = DB.REQUESTS.filter(func(q): return q.get("used", "") == "new")[0]
	var upc := PCBuild.full()
	upc.used["RAM1"] = {"id": "ram2", "cond": 90, "paid": 3, "known": true}
	ok("새 제품만" in Rules.score(newonly, [], upc, [])["line"], "새 제품만 손님에게 중고")

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
