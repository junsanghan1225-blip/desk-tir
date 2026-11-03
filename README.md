# 데스크테리어 의뢰소

손님의 취향과 예산에 맞춰 **책상을 꾸미고 PC를 조립해 주는** 커스텀 의뢰 게임
2D 게임 프로그래밍 (이대현 교수) 학기 프로젝트 · Python + pico2d · 한준상

📎 **발표 자료**: [1차 발표 PPT](docs/데스크테리어의뢰소_발표.pptx) · [기획서 PPT](docs/데스크테리어의뢰소_기획서.pptx)

![꾸미기 화면](docs/screens/3_decorate.png)
![케이블 모드](docs/screens/3b_cable.png)

## 게임 루프

의뢰 받기 → 쇼핑(소품 + 부품, 한 예산) → PC 조립 → 책상 배치 → 케이블 연결 → 채점 · 해금

## 핵심 재미

- **조합 시너지**: 스탠드 옆에 책을 두면 '독서 콤보'처럼, 위치와 조합에 따라 점수가 오름
- **PC 조립 퍼즐**: 그래픽카드에 돈을 쓰면 꾸밀 돈이 모자라고, 파워 용량이 부족하면 부팅 실패
- **케이블 연결**: 모니터는 DP, 키보드 · 마이크 · 웹캠은 USB, 스피커 · 헤드셋은 오디오 포트에. GPU 등급이 DP 포트 수를 정하고(듀얼 모니터 = 중급 GPU 이상), 선이 꼬이면 감점
- **손님 리액션**: 가장 많이 깎인 항목을 손님이 말로 알려 줌

## 채점 (100점)

테마 일치 25 · 필수/금지 20 · PC 성능 20 · 조합 시너지 15 · 배선 10 · 예산 절약 10
60점 ★ / 75점 ★★ / 90점 ★★★

## 실행

```bash
pip install pico2d
python main.py
```

조작: 좌클릭 드래그(배치) · 우클릭(되돌리기) · C(배선 정리 화면: 기기를 끌어 포트에 꽂기) · Tab(책상 ↔ PC 조립) · Enter(채점) · ESC(종료)

## 구조

| 파일 | 역할 |
|---|---|
| `main.py`, `game_framework.py` | 실행, 모드 전환 |
| `title_mode.py` → `request_mode.py` → `decorate_mode.py` ⇄ `build_mode.py` · `wire_mode.py` → `result_mode.py` | 화면(모드) |
| `room.py` | 벽 · 책상 위 2레이어 슬롯 배치 |
| `cables.py` | 포트 · 케이블 연결 · 꼬임(교차) 판정 (`python cables.py`로 자체 테스트) |
| `scorer.py` | 채점 · 시너지 · 부팅 판정 (`python scorer.py`로 자체 테스트) |
| `state.py` | 의뢰 하나 동안의 배치 · PC · 예산 상태 |
| `data/*.json` | 소품 · 부품 · 의뢰 데이터 (코드 수정 없이 추가) |
| `resource/`, `tools/make_sprites.js` | 소품 · 방 · PC 스프라이트와 생성 스크립트 |
| `docs/` | 1차 발표 PPT, 기획서 PPT, 화면 캡처 |

## 진행 현황

- [x] 1차: 기획 · 핵심 루프 프로토타입 (픽셀 사이버펑크 그래픽, 의뢰 3개)
- [ ] 손님 캐릭터 그래픽 (AI 이미지 생성 툴로 직접 제작)
- [ ] 의뢰 6개 · 소품 24개 · 손님 표정 · 해금
- [ ] 자유 모드 · 저장 · 사운드

폰트: [갈무리(Galmuri)](https://github.com/quiple/galmuri), SIL OFL 1.1 (`resource/FONT_LICENSE.md`)
