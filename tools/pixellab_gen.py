# PixelLab으로 게임 그림 뽑기. 키는 파일에 안 적고 환경 변수로만 받음.
#   Windows:  set PIXELLAB_API_KEY=내키
#             python tools\pixellab_gen.py            (목록 전부, 이미 있는 건 건너뜀)
#             python tools\pixellab_gen.py gpu_mid    (하나만)
# 목록: tools/pixellab_list.json  →  결과: resource/pixellab/<id>.png
# ponytail: 표준 라이브러리만 (pip 설치 없이 바로 실행)
import base64, json, os, sys, time, urllib.request, urllib.error

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIST = os.path.join(ROOT, "tools", "pixellab_list.json")
OUT = os.path.join(ROOT, "resource", "pixellab")
URL = "https://api.pixellab.ai/v1/generate-image-pixflux"
STYLE = "pixel art, game item icon, clean dark outline, soft shading, centered, single object"   # 모든 그림 공통 화풍


def gen(item, key):
    body = {"description": f"{item['prompt']}, {STYLE}",
            "image_size": {"width": item.get("w", 128), "height": item.get("h", 128)},
            "no_background": True}   # 200x200 이하면 배경 투명
    if "seed" in item:
        body["seed"] = item["seed"]
    req = urllib.request.Request(URL, json.dumps(body).encode(), {"Authorization": "Bearer " + key, "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=120) as r:
        res = json.load(r)
    data = res["image"]["base64"].split(",", 1)[-1]   # "data:image/png;base64," 앞부분 제거
    with open(os.path.join(OUT, item["id"] + ".png"), "wb") as f:
        f.write(base64.b64decode(data))
    return res.get("usage", {})


def main():
    key = os.environ.get("PIXELLAB_API_KEY", "").strip()
    if not key:
        sys.exit("PIXELLAB_API_KEY가 없어요. 먼저:  set PIXELLAB_API_KEY=내키")
    os.makedirs(OUT, exist_ok=True)
    items = json.load(open(LIST, encoding="utf-8"))
    only = sys.argv[1:]
    for it in items:
        path = os.path.join(OUT, it["id"] + ".png")
        if only and it["id"] not in only:
            continue
        if os.path.exists(path) and not only:   # 이미 뽑은 건 건너뜀 (다시 뽑으려면 id를 직접 지정)
            continue
        try:
            usage = gen(it, key)
            print("완료", it["id"], usage)
        except urllib.error.HTTPError as e:
            msg = {401: "키가 틀렸어요", 402: "크레딧이 모자라요", 422: "요청 형식 오류", 429: "너무 빨라요(잠시 후 다시)"}.get(e.code, "")
            print("실패", it["id"], e.code, msg, e.read()[:200])
            if e.code in (401, 402):
                break
        time.sleep(1)   # 속도 제한 피하기


if __name__ == "__main__":
    main()
