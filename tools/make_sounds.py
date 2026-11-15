"""효과음 · 배경음(WAV) 생성: python tools/make_sounds.py → resource/sfx/*.wav
표준 라이브러리만으로 직접 합성한 소리라 저작권 문제가 없다."""
import math, os, struct, wave

RATE = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'resource', 'sfx')
os.makedirs(OUT, exist_ok=True)


def tri(p): return 2 * abs(2 * (p % 1) - 1) - 1
def sq(p): return 1.0 if p % 1 < 0.5 else -1.0
def sine(p): return math.sin(2 * math.pi * p)


def note(freq, dur, wave_fn=sine, vol=0.5, attack=0.005, decay=6.0, slide=0.0):
    """한 음: freq에서 시작해 slide(배)만큼 미끄러지고, 지수적으로 줄어든다."""
    out, phase = [], 0.0
    for i in range(int(RATE * dur)):
        t = i / RATE
        phase += freq * (1 + slide * t / dur) / RATE
        out.append(wave_fn(phase) * min(1, t / attack) * math.exp(-decay * t) * vol)
    return out


def seq(parts):
    """[(시작 시각 초, 샘플들)] → 한 줄로 섞기."""
    out = [0.0] * max(int(s * RATE) + len(p) for s, p in parts)
    for s, p in parts:
        k = int(s * RATE)
        for i, v in enumerate(p):
            out[k + i] += v
    return out


def save(name, samples):
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, v)) * 32000)) for v in samples))


N = lambda semis: 440 * 2 ** (semis / 12)   # A4 기준 반음
save('click', note(900, 0.05, sq, 0.2, decay=60))
save('pick', note(520, 0.09, tri, 0.45, decay=25, slide=0.5))
save('place', seq([(0, note(160, 0.16, sine, 0.7, decay=22)), (0, note(900, 0.03, sq, 0.12, decay=90))]))
save('error', seq([(0, note(150, 0.12, sq, 0.3, decay=10)), (0.13, note(120, 0.18, sq, 0.3, decay=8))]))
save('cart', note(N(7), 0.1, tri, 0.4, decay=20))
save('buy', seq([(0, note(N(12), 0.1, sine, 0.45, decay=14)), (0.09, note(N(19), 0.3, sine, 0.45, decay=8))]))
save('plug', seq([(0, note(1400, 0.03, sq, 0.2, decay=90)), (0, note(300, 0.1, tri, 0.4, decay=30))]))
save('lever', seq([(0, note(240, 0.06, sq, 0.25, decay=40)), (0.07, note(180, 0.08, sq, 0.25, decay=30))]))
save('paste', note(300, 0.25, sine, 0.3, decay=6, slide=-0.4))
save('boot_ok', seq([(i * 0.11, note(N(s), 0.3, tri, 0.4, decay=7)) for i, s in enumerate([0, 4, 7, 12])]))
save('boot_fail', seq([(0, note(N(-5), 0.2, sq, 0.3, decay=6)), (0.2, note(N(-9), 0.2, sq, 0.3, decay=6)), (0.4, note(N(-14), 0.45, sq, 0.3, decay=4))]))
save('star', seq([(0, note(N(19), 0.5, sine, 0.4, decay=6)), (0, note(N(24), 0.5, sine, 0.25, decay=6))]))
save('sad', seq([(0, note(N(3), 0.25, tri, 0.4, decay=5)), (0.25, note(N(-1), 0.5, tri, 0.4, decay=4))]))
save('door', seq([(0, note(N(16), 0.35, sine, 0.4, decay=5)), (0.18, note(N(12), 0.6, sine, 0.4, decay=4))]))
save('photo', seq([(0, note(2000, 0.04, sq, 0.2, decay=80)), (0.05, note(700, 0.08, sq, 0.2, decay=40))]))

# 배경음: 느린 로파이 아르페지오 (Am7 – Fmaj7 – Cmaj7 – G6), 4마디 × 2회
beat = 60 / 76
chords = [[-12, -9, -5, -2], [-16, -12, -9, -5], [-9, -5, -2, 2], [-14, -10, -7, -5]]
parts = []
for rep in range(2):
    for bar, ch in enumerate(chords):
        t0 = (rep * 4 + bar) * 4 * beat
        parts.append((t0, note(N(ch[0] - 12), 4 * beat, tri, 0.22, attack=0.02, decay=0.5)))        # 베이스
        parts += [(t0, note(N(s), 4 * beat, sine, 0.045, attack=0.4, decay=0.25)) for s in ch]       # 패드
        order = [0, 2, 1, 3, 2, 3, 1, 2] if rep == 0 else [3, 1, 2, 0, 2, 1, 3, 2]
        parts += [(t0 + k * beat / 2, note(N(ch[i] + 12), 0.5, tri, 0.11, decay=5)) for k, i in enumerate(order)]  # 아르페지오
bgm = seq(parts)
loop = int(8 * 4 * beat * RATE)
bgm, tail = bgm[:loop], bgm[loop:]
for i, v in enumerate(tail):   # 꼬리 잔향을 앞에 겹쳐 이음매 없이 반복
    bgm[i] += v
save('bgm', bgm)
print('sounds ok', len(os.listdir(OUT)))
