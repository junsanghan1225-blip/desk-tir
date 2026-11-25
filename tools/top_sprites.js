// 탑뷰(위에서 본) 소품 그림: top_<id>.png. 크기 = items.json foot [가로 cm, 앞뒤 cm] x 5.5 (게임 책상 좌표와 같음).
// 위쪽이 벽(뒤), 아래쪽이 앞. 빛은 왼쪽 위. 정면 그림과 같은 도트 처리(1/2로 줄였다 nearest로 키움).
// 실행: node tools/top_sprites.js
const sharp = require('sharp'), path = require('path');
const ITEMS = require('../data/items.json');
const OUT = path.join(__dirname, '..', 'resource');
const UNIT = 5.5;
const CYAN = '#2ee6d6', PINK = '#ff4d8d';
const shadow = (x, y, w, h, r = 6) => `<rect x="${x + 3}" y="${y + 4}" width="${w}" height="${h}" rx="${r}" fill="#000" opacity=".35"/>`;
const rgb = id => `<linearGradient id="${id}" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="${PINK}"/><stop offset=".5" stop-color="#7b5cff"/><stop offset="1" stop-color="${CYAN}"/></linearGradient>`;
const cshadow = (cx, cy, r) => `<circle cx="${cx + 3}" cy="${cy + 4}" r="${r}" fill="#000" opacity=".35"/>`;
const dots = (cx, cy, r, c) => [...Array(25)].map((_, i) => [i % 5 - 2, Math.floor(i / 5) - 2]).filter(([a, b]) => a * a + b * b <= 5).map(([a, b]) => `<rect x="${cx + a * r / 2.4 - 1}" y="${cy + b * r / 2.4 - 1}" width="2" height="2" fill="${c}"/>`).join('');
// 잎: 가운데에서 n장이 퍼짐. split이면 몬스테라처럼 잎에 칼집
const leaves = (cx, cy, n, len, wid, c1, c2, split = false) => [...Array(n)].map((_, i) => {
  const a = i * 360 / n + 20, c = i % 2 ? c1 : c2;
  return `<g transform="rotate(${a} ${cx} ${cy})"><ellipse cx="${cx + len / 2}" cy="${cy}" rx="${len / 2}" ry="${wid}" fill="${c}"/><path d="M${cx} ${cy} L${cx + len} ${cy}" stroke="#2e6a48" stroke-width="1.5"/>${split ? [.45, .65, .82].map(k => `<path d="M${cx + len * k} ${cy - wid} L${cx + len * k - 4} ${cy - wid * .3}" stroke="#14102a" stroke-width="2.5"/>`).join('') : ''}</g>`;
}).join('');
const keys = (x0, y0, cols, rows, w, h, gap, c) => [...Array(rows)].map((_, r) => [...Array(cols)].map((_, k) => `<rect x="${x0 + k * (w + gap)}" y="${y0 + r * (h + gap)}" width="${w}" height="${h}" fill="${c}"/>`).join('')).join('');

// 모니터: 뒤판(얇은 막대) + 목 + 받침, 앞쪽 책상에 화면 빛
const monitor = (body, top, glow, baseW = 0.4) => (W, H) => {
  const bw = W * baseW, bx = (W - bw) / 2;
  return `<defs><linearGradient id="spill" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${glow}" stop-opacity=".35"/><stop offset="1" stop-color="${glow}" stop-opacity="0"/></linearGradient></defs>
  <path d="M6 ${H * .3} L${W - 6} ${H * .3} L${W - 30} ${H} L30 ${H} Z" fill="url(#spill)"/>
  ${shadow(2, 4, W - 4, H * .22, 3)}<rect x="2" y="4" width="${W - 4}" height="${H * .22}" rx="3" fill="${body}"/><rect x="2" y="4" width="${W - 4}" height="5" rx="2" fill="${top}"/>
  <rect x="2" y="${4 + H * .22 - 3}" width="${W - 4}" height="3" fill="${glow}"/>
  <rect x="${W / 2 - 8}" y="${H * .26}" width="16" height="${H * .2}" fill="${top}"/>
  ${shadow(bx, H * .44, bw, H * .48, 8)}<rect x="${bx}" y="${H * .44}" width="${bw}" height="${H * .48}" rx="8" fill="${body}"/><rect x="${bx}" y="${H * .44}" width="${bw}" height="8" rx="6" fill="${top}"/>`;
};

// 키보드(+ 마우스) 공통: key가 배열이면 줄마다 색이 바뀜(RGB). pad가 있으면 마우스 밑에 패드.
const kbTop = ({ body, top, key, cols = 15, kbW = 0.97, mouse, pad }) => (W, H) => {
  const kw = W * kbW, kc = Array.isArray(key) ? key : [key];
  const kx = (kw - 12) / cols - 3, ky = (H - 30) / 5;
  const rows = [0, 1, 2, 3].map(r => keys(8, 12 + r * (ky + 3), cols, 1, kx, ky, 3, kc[r % kc.length])).join('');
  const mx = kw + (W - kw) * .3, mw = (W - kw) * .5;
  return `${shadow(2, 4, kw, H - 10, 4)}<rect x="2" y="4" width="${kw}" height="${H - 10}" rx="4" fill="${body}"/><rect x="2" y="4" width="${kw}" height="5" rx="3" fill="${top}"/>
    ${rows}<rect x="${kw * .25}" y="${H - 18}" width="${kw * .45}" height="${ky}" fill="${kc[0]}"/>
    ${!mouse ? '' : pad ? `<rect x="${kw + 6}" y="${H * .08}" width="${W - kw - 8}" height="${H * .84}" rx="3" fill="#14102a" stroke="${pad}" stroke-width="2"/>` : ''}
    ${!mouse ? '' : `${shadow(mx, H * .2, mw, H * .62, 12)}`}${!mouse ? '' : `<rect x="${mx}" y="${H * .2}" width="${mw}" height="${H * .62}" rx="12" fill="${mouse}"/><rect x="${mx + mw / 2 - 1}" y="${H * .24}" width="3" height="${H * .16}" fill="${pad || '#9aa0b4'}"/>`}`;
};

const DRAW = {
  monitor: monitor('#2a2440', '#4a4370', CYAN),
  monitor_27: monitor('#1c1830', '#3e3760', PINK, 0.36),
  monitor_white: monitor('#e6e8f0', '#ffffff', CYAN, 0.3),

  // 커브드: 양 끝이 앞으로 휘어 있음
  monitor_curve: (W, H) => `<defs><linearGradient id="cs" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#7b5cff" stop-opacity=".4"/><stop offset="1" stop-color="#7b5cff" stop-opacity="0"/></linearGradient></defs>
    <path d="M10 ${H * .45} Q${W / 2} ${H * .05} ${W - 10} ${H * .45} L${W - 40} ${H} L40 ${H} Z" fill="url(#cs)"/>
    <path d="M8 ${H * .42} Q${W / 2} ${-H * .02} ${W - 8} ${H * .42}" stroke="#000" stroke-opacity=".35" stroke-width="16" fill="none" transform="translate(3 4)"/>
    <path d="M8 ${H * .42} Q${W / 2} ${-H * .02} ${W - 8} ${H * .42}" stroke="#2a2440" stroke-width="16" fill="none"/>
    <path d="M10 ${H * .46} Q${W / 2} ${H * .03} ${W - 10} ${H * .46}" stroke="#7b5cff" stroke-width="3" fill="none"/>
    <rect x="${W / 2 - 9}" y="${H * .24}" width="18" height="${H * .2}" fill="#4a4370"/>
    ${shadow(W * .3, H * .44, W * .4, H * .44, 10)}<path d="M${W * .3} ${H * .88} L${W / 2} ${H * .44} L${W * .7} ${H * .88} Z" fill="#2a2440"/><rect x="${W * .46}" y="${H * .44}" width="${W * .08}" height="8" fill="#4a4370"/>`,

  // 노트북: 뒤쪽에 화면(뚜껑 옆면), 앞쪽에 키보드 · 터치패드
  laptop: (W, H) => `${shadow(2, 2, W - 4, H - 4, 5)}<rect x="2" y="2" width="${W - 4}" height="${H * .14}" rx="3" fill="#c9ccd6"/><rect x="2" y="${2 + H * .14 - 3}" width="${W - 4}" height="3" fill="${CYAN}"/>
    <rect x="2" y="${H * .16}" width="${W - 4}" height="${H * .82}" rx="5" fill="#d8dbe4"/><rect x="2" y="${H * .16}" width="${W - 4}" height="5" rx="3" fill="#f4f4fa"/>
    ${keys(12, H * .24, 12, 4, (W - 24) / 12 - 3, 7, 3, '#3a3a50')}
    <rect x="${W * .34}" y="${H * .64}" width="${W * .32}" height="${H * .26}" rx="3" fill="#c3c6d2"/>`,

  // 드로잉 태블릿 + 펜
  tablet: (W, H) => `${shadow(2, 2, W - 4, H - 4, 6)}<rect x="2" y="2" width="${W - 4}" height="${H - 4}" rx="6" fill="#1c1830"/>
    <rect x="${W * .2}" y="12" width="${W * .74}" height="${H - 24}" fill="#2a2440"/><rect x="${W * .2}" y="12" width="${W * .74}" height="${H - 24}" fill="none" stroke="${CYAN}" stroke-width="2" opacity=".6"/>
    ${[0, 1, 2, 3].map(i => `<rect x="8" y="${14 + i * (H - 28) / 4}" width="${W * .1}" height="${(H - 28) / 4 - 5}" rx="2" fill="#3e3760"/>`).join('')}
    <path d="M${W * .45} ${H * .75} L${W * .85} ${H * .3}" stroke="#000" stroke-opacity=".35" stroke-width="7" transform="translate(3 4)"/><path d="M${W * .45} ${H * .75} L${W * .85} ${H * .3}" stroke="#e6e8f0" stroke-width="7"/><path d="M${W * .45} ${H * .75} L${W * .5} ${H * .69}" stroke="${PINK}" stroke-width="7"/>`,

  // 웹캠: 모니터 윗면에 끼운 작은 카메라 (렌즈가 앞을 봄)
  webcam: (W, H) => `<rect x="${W * .4}" y="2" width="${W * .2}" height="${H * .3}" fill="#2a2440"/>
    ${shadow(W * .12, H * .28, W * .76, H * .5, 6)}<rect x="${W * .12}" y="${H * .28}" width="${W * .76}" height="${H * .5}" rx="6" fill="#1c1830"/><rect x="${W * .12}" y="${H * .28}" width="${W * .76}" height="4" rx="3" fill="#3e3760"/>
    <rect x="${W * .38}" y="${H * .7}" width="${W * .24}" height="${H * .12}" fill="#3a7ac8"/><rect x="${W * .76}" y="${H * .36}" width="4" height="4" fill="${PINK}"/>`,

  // 키보드 + 마우스
  keyboard: kbTop({ body: '#c9ccd6', top: '#e6e8f0', key: '#f4f4fa' }),   // 마우스는 따로 파는 소품
  gaming_kb: kbTop({ body: '#14102a', top: '#2a2440', key: [PINK, '#7b5cff', CYAN] }),
  kb_white: kbTop({ body: '#f4f4fa', top: '#ffffff', key: '#e6e8f0' }),
  kb_mini: kbTop({ body: '#8a7cc8', top: '#a99be0', key: ['#e6e0ff', '#e6e0ff', '#e6e0ff', PINK], cols: 11 }),

  // 버티컬 마우스: 옆으로 세운 손잡이
  mouse_vertical: (W, H) => `<ellipse cx="${W / 2 + 2}" cy="${H / 2 + 3}" rx="${W * .42}" ry="${H * .46}" fill="#000" opacity=".35"/>
    <ellipse cx="${W / 2}" cy="${H / 2}" rx="${W * .42}" ry="${H * .46}" fill="#4a4566"/><path d="M${W * .5} ${H * .06} Q${W * .95} ${H * .5} ${W * .5} ${H * .94}" fill="#2e2a44"/>
    <rect x="${W * .3}" y="${H * .3}" width="4" height="6" fill="${CYAN}"/>`,

  // 차가운 스탠드: 네모 받침 · 꺾인 팔 · 하늘색 갓, 차가운 빛
  lamp_cool: (W, H) => `<defs><radialGradient id="cool"><stop offset="0" stop-color="#cfefff" stop-opacity=".5"/><stop offset="1" stop-color="#cfefff" stop-opacity="0"/></radialGradient></defs>
    <circle cx="${W * .64}" cy="${H * .5}" r="${H * .52}" fill="url(#cool)"/>
    ${shadow(W * .06, H * .58, W * .3, H * .32, 3)}<rect x="${W * .06}" y="${H * .58}" width="${W * .3}" height="${H * .32}" rx="3" fill="#2a2440"/><rect x="${W * .06}" y="${H * .58}" width="${W * .3}" height="4" fill="#4a4370"/>
    <path d="M${W * .2} ${H * .72} L${W * .38} ${H * .3} L${W * .55} ${H * .36}" stroke="#5a4fa0" stroke-width="5" fill="none"/><rect x="${W * .36}" y="${H * .27}" width="6" height="6" fill="${CYAN}"/>
    ${shadow(W * .52, H * .2, W * .36, H * .34, 4)}<rect x="${W * .52}" y="${H * .2}" width="${W * .36}" height="${H * .34}" rx="4" fill="#8fd8ff"/><rect x="${W * .52}" y="${H * .2}" width="${W * .36}" height="5" fill="#c8eeff"/><circle cx="${W * .7}" cy="${H * .4}" r="${H * .08}" fill="#ffffff"/>`,

  // 모니터 라이트바: 얇은 막대 + 앞쪽 책상에 떨어지는 빛
  monitor_bar: (W, H) => `<defs><linearGradient id="bar" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#e8f6ff" stop-opacity=".55"/><stop offset="1" stop-color="#e8f6ff" stop-opacity="0"/></linearGradient></defs>
    <path d="M4 ${H * .4} L${W - 4} ${H * .4} L${W - 16} ${H} L16 ${H} Z" fill="url(#bar)"/>
    ${shadow(2, 2, W - 4, H * .36, 3)}<rect x="2" y="2" width="${W - 4}" height="${H * .36}" rx="3" fill="#2a2440"/><rect x="6" y="${H * .3}" width="${W - 12}" height="3" fill="#ffffff"/>
    <rect x="${W / 2 - 10}" y="0" width="20" height="${H * .24}" fill="#4a4370"/>`,

  // 네온 무드등: 위에서 보면 빛나는 원기둥 윗면 (색 바꾸기 가능)
  mood_lamp: (W, H) => `<defs><radialGradient id="mood"><stop offset="0" stop-color="${PINK}" stop-opacity=".6"/><stop offset="1" stop-color="#7b5cff" stop-opacity="0"/></radialGradient>
    <radialGradient id="tube" cx=".4" cy=".35"><stop offset="0" stop-color="#ffd0e4"/><stop offset=".5" stop-color="${PINK}"/><stop offset="1" stop-color="#7b5cff"/></radialGradient></defs>
    <circle cx="${W / 2}" cy="${H / 2}" r="${W / 2}" fill="url(#mood)"/>
    <circle cx="${W / 2 + 2}" cy="${H / 2 + 3}" r="${W * .34}" fill="#000" opacity=".35"/><circle cx="${W / 2}" cy="${H / 2}" r="${W * .34}" fill="#2a2440"/><circle cx="${W / 2}" cy="${H / 2}" r="${W * .24}" fill="url(#tube)"/>`,

  // 달 무드등: 나무 받침 위 달
  moon_lamp: (W, H) => `<defs><radialGradient id="mglow"><stop offset="0" stop-color="#fff2c0" stop-opacity=".5"/><stop offset="1" stop-color="#fff2c0" stop-opacity="0"/></radialGradient></defs>
    <circle cx="${W / 2}" cy="${H / 2}" r="${W / 2}" fill="url(#mglow)"/>
    <rect x="${W * .2}" y="${H * .2}" width="${W * .6}" height="${H * .6}" rx="4" fill="#8a5a34"/>
    <circle cx="${W / 2 + 2}" cy="${H / 2 + 3}" r="${W * .32}" fill="#000" opacity=".3"/><circle cx="${W / 2}" cy="${H / 2}" r="${W * .32}" fill="#f4e8b8"/>
    <circle cx="${W * .4}" cy="${H * .42}" r="${W * .07}" fill="#d8c890"/><circle cx="${W * .6}" cy="${H * .6}" r="${W * .09}" fill="#d8c890"/><circle cx="${W * .42}" cy="${H * .36}" r="${W * .1}" fill="#fffbe8" opacity=".6"/>`,

  // 게이밍 마우스 + RGB 패드
  mouse_gaming: (W, H) => `<defs>${rgb('pad')}</defs>${shadow(3, 3, W - 6, H - 6, 6)}<rect x="3" y="3" width="${W - 6}" height="${H - 6}" rx="6" fill="url(#pad)"/><rect x="7" y="7" width="${W - 14}" height="${H - 14}" rx="5" fill="#14102a"/>
    ${shadow(W * .5, H * .25, W * .22, H * .48, 18)}<rect x="${W * .5}" y="${H * .25}" width="${W * .22}" height="${H * .48}" rx="18" fill="#2a2440"/><rect x="${W * .5}" y="${H * .25}" width="${W * .22}" height="${H * .18}" rx="14" fill="#3e3760"/>
    <rect x="${W * .605}" y="${H * .28}" width="3" height="${H * .12}" fill="${CYAN}"/><rect x="${W * .53}" y="${H * .55}" width="${W * .16}" height="4" fill="${PINK}"/>`,

  // 스탠드: 둥근 받침 → 팔 → 갓(따뜻한 빛이 책상에 번짐)
  lamp_warm: (W, H) => `<defs><radialGradient id="warm"><stop offset="0" stop-color="#ffd27a" stop-opacity=".55"/><stop offset="1" stop-color="#ffd27a" stop-opacity="0"/></radialGradient></defs>
    <circle cx="${W * .63}" cy="${H * .45}" r="${H * .5}" fill="url(#warm)"/>
    <circle cx="${W * .26}" cy="${H * .74}" r="${H * .22}" fill="#000" opacity=".35"/><circle cx="${W * .24}" cy="${H * .7}" r="${H * .22}" fill="#3a3354"/><circle cx="${W * .21}" cy="${H * .65}" r="${H * .08}" fill="#4e4670"/>
    <path d="M${W * .26} ${H * .66} L${W * .58} ${H * .4}" stroke="#5a5280" stroke-width="7"/>
    <circle cx="${W * .65}" cy="${H * .38}" r="${H * .28}" fill="#000" opacity=".35"/><circle cx="${W * .63}" cy="${H * .35}" r="${H * .28}" fill="#f2a541"/><circle cx="${W * .58}" cy="${H * .27}" r="${H * .1}" fill="#ffd27a"/><circle cx="${W * .63}" cy="${H * .35}" r="${H * .28}" fill="none" stroke="#b8741f" stroke-width="4"/>`,

  // 하트 머그: 위에서 보면 커피 위 하트 라테아트
  mug: (W, H) => {
    const r = H * .46, cx = W * .4, cy = H / 2;
    return `<circle cx="${cx + 3}" cy="${cy + 3}" r="${r}" fill="#000" opacity=".35"/><rect x="${cx + r - 4}" y="${cy - 5}" width="${W - cx - r + 2}" height="10" rx="4" fill="#e85d8a"/>
    <circle cx="${cx}" cy="${cy}" r="${r}" fill="#ff7aa8"/><circle cx="${cx}" cy="${cy}" r="${r * .78}" fill="#5a2e1e"/>
    <path d="M${cx} ${cy + r * .4} L${cx - r * .38} ${cy} A${r * .19} ${r * .19} 0 0 1 ${cx} ${cy - r * .22} A${r * .19} ${r * .19} 0 0 1 ${cx + r * .38} ${cy} Z" fill="#f2e2cc"/>`;
  },
  // ---------- 오디오 ----------
  speaker: (W, H) => `${shadow(2, 2, W - 4, H - 4, 3)}<rect x="2" y="2" width="${W - 4}" height="${H - 4}" rx="3" fill="#1c1830"/><rect x="2" y="2" width="${W - 4}" height="4" fill="#3e3760"/>
    <rect x="2" y="${H - 9}" width="${W - 4}" height="7" fill="#2a2440"/><rect x="${W * .2}" y="${H - 6}" width="${W * .6}" height="3" fill="#ffd65c"/><rect x="${W / 2 - 3}" y="${H - 14}" width="6" height="3" fill="${CYAN}"/>`,
  speaker_bt: (W, H) => `${cshadow(W / 2, H / 2, W * .44)}<circle cx="${W / 2}" cy="${H / 2}" r="${W * .44}" fill="#2a2440"/><circle cx="${W / 2}" cy="${H / 2}" r="${W * .44}" fill="none" stroke="${CYAN}" stroke-width="3"/>
    ${dots(W / 2, H / 2, W * .3, '#4a4370')}`,
  soundbar: (W, H) => `<defs>${rgb('sb')}</defs>${shadow(2, 2, W - 4, H - 6, 4)}<rect x="2" y="2" width="${W - 4}" height="${H - 6}" rx="4" fill="#1c1830"/>
    ${[...Array(Math.floor((W - 20) / 8))].map((_, i) => `<rect x="${10 + i * 8}" y="${H * .3}" width="3" height="3" fill="#3e3760"/>`).join('')}<rect x="4" y="${H - 8}" width="${W - 8}" height="4" fill="url(#sb)"/>`,
  mic: (W, H) => `${shadow(4, 4, W * .2, H * .2, 2)}<rect x="4" y="4" width="${W * .2}" height="${H * .2}" rx="2" fill="#2a2440"/>
    <path d="M${W * .14} ${H * .14} L${W * .5} ${H * .4} L${W * .62} ${H * .62}" stroke="#5a4fa0" stroke-width="5" fill="none"/><rect x="${W * .48}" y="${H * .38}" width="6" height="6" fill="${CYAN}"/>
    ${cshadow(W * .66, H * .68, W * .2)}<circle cx="${W * .66}" cy="${H * .68}" r="${W * .2}" fill="#2a2440"/><circle cx="${W * .66}" cy="${H * .68}" r="${W * .2}" fill="none" stroke="${PINK}" stroke-width="3"/>${dots(W * .66, H * .68, W * .12, '#8a84a8')}`,
  mic_desk: (W, H) => `${cshadow(W / 2, H / 2, W * .46)}<circle cx="${W / 2}" cy="${H / 2}" r="${W * .46}" fill="#2a2440"/>
    <circle cx="${W / 2}" cy="${H / 2}" r="${W * .3}" fill="#c9ccd6"/><circle cx="${W / 2}" cy="${H / 2}" r="${W * .3}" fill="none" stroke="${PINK}" stroke-width="3"/>${dots(W / 2, H / 2, W * .2, '#9aa0b4')}`,
  // 헤드셋 걸이: 책상 앞 모서리 집게(위) → 모서리 밖으로 매달린 헤드셋(아래)
  headset: (W, H) => `<rect x="${W * .36}" y="0" width="${W * .28}" height="${H * .4}" fill="#4a4370"/><rect x="${W * .36}" y="0" width="${W * .28}" height="4" fill="#5a5280"/>
    <path d="M${W * .14} ${H * .62} Q${W / 2} ${H * .2} ${W * .86} ${H * .62}" stroke="#000" stroke-opacity=".35" stroke-width="7" fill="none" transform="translate(3 4)"/>
    <path d="M${W * .14} ${H * .62} Q${W / 2} ${H * .2} ${W * .86} ${H * .62}" stroke="#1c1830" stroke-width="7" fill="none"/>
    <rect x="2" y="${H * .5}" width="${W * .24}" height="${H * .44}" rx="6" fill="#1c1830"/><rect x="${W * .08}" y="${H * .56}" width="4" height="${H * .3}" fill="${PINK}"/>
    <rect x="${W * .74}" y="${H * .5}" width="${W * .24}" height="${H * .44}" rx="6" fill="#1c1830"/><rect x="${W * .86}" y="${H * .56}" width="4" height="${H * .3}" fill="${CYAN}"/>`,
  headphones: (W, H) => `<path d="M${W * .2} ${H * .7} Q${W / 2} ${-H * .1} ${W * .8} ${H * .7}" stroke="#000" stroke-opacity=".35" stroke-width="8" fill="none" transform="translate(3 4)"/>
    <path d="M${W * .2} ${H * .7} Q${W / 2} ${-H * .1} ${W * .8} ${H * .7}" stroke="#e6e8f0" stroke-width="8" fill="none"/>
    ${[.2, .8].map(k => `${cshadow(W * k, H * .72, W * .17)}<circle cx="${W * k}" cy="${H * .72}" r="${W * .17}" fill="#c8bcf4"/><circle cx="${W * k}" cy="${H * .72}" r="${W * .1}" fill="#a99be0"/>`).join('')}`,
  turntable: (W, H) => `${shadow(2, 2, W - 4, H - 4, 4)}<rect x="2" y="2" width="${W - 4}" height="${H - 4}" rx="4" fill="#8a5a34"/><rect x="2" y="2" width="${W - 4}" height="5" fill="#a87448"/>
    <circle cx="${W * .42}" cy="${H / 2}" r="${H * .42}" fill="#14102a"/>${[.36, .3, .24].map(k => `<circle cx="${W * .42}" cy="${H / 2}" r="${H * k}" fill="none" stroke="#2a2440" stroke-width="1.5"/>`).join('')}
    <circle cx="${W * .42}" cy="${H / 2}" r="${H * .12}" fill="${PINK}"/><circle cx="${W * .42}" cy="${H / 2}" r="3" fill="#14102a"/>
    <circle cx="${W * .86}" cy="${H * .18}" r="7" fill="#c9ccd6"/><path d="M${W * .86} ${H * .18} L${W * .84} ${H * .66} L${W * .74} ${H * .76}" stroke="#c9ccd6" stroke-width="4" fill="none"/><circle cx="${W * .9}" cy="${H * .86}" r="4" fill="${CYAN}"/>`,

  // ---------- 식물 ----------
  mini_plant: (W, H) => `${cshadow(W / 2, H / 2, W * .36)}<circle cx="${W / 2}" cy="${H / 2}" r="${W * .36}" fill="#2a2440"/><circle cx="${W / 2}" cy="${H / 2}" r="${W * .28}" fill="#4a3424"/>
    ${leaves(W / 2, H / 2, 6, W * .42, W * .12, '#5fb889', '#3e8a64')}`,
  cactus: (W, H) => `${cshadow(W / 2, H / 2, W * .42)}<circle cx="${W / 2}" cy="${H / 2}" r="${W * .42}" fill="#e2704a"/><circle cx="${W / 2}" cy="${H / 2}" r="${W * .34}" fill="#4a3424"/>
    <circle cx="${W / 2}" cy="${H / 2}" r="${W * .24}" fill="#4caf7a"/><circle cx="${W * .44}" cy="${H * .44}" r="${W * .1}" fill="#6fcf98"/>
    ${[0, 1, 2, 3, 4, 5].map(i => `<rect x="${W / 2 + Math.cos(i) * W * .18 - 1}" y="${H / 2 + Math.sin(i) * W * .18 - 1}" width="2" height="2" fill="#e6f5d8"/>`).join('')}<circle cx="${W * .58}" cy="${H * .4}" r="3" fill="${PINK}"/>`,
  monstera: (W, H) => `${cshadow(W / 2, H / 2, W * .18)}<circle cx="${W / 2}" cy="${H / 2}" r="${W * .16}" fill="#2a2440"/>
    ${leaves(W / 2, H / 2, 7, W * .46, W * .14, '#4ea67a', '#2e7a54', true)}`,
  terrarium: (W, H) => `${cshadow(W / 2, H / 2, W * .44)}<circle cx="${W / 2}" cy="${H / 2}" r="${W * .44}" fill="#2a2440"/><circle cx="${W / 2}" cy="${H / 2}" r="${W * .38}" fill="#5a4030"/>
    <circle cx="${W * .4}" cy="${H * .44}" r="${W * .12}" fill="#4caf7a"/><circle cx="${W * .6}" cy="${H * .58}" r="${W * .1}" fill="#6fcf98"/><circle cx="${W * .62}" cy="${H * .36}" r="${W * .06}" fill="#c9ccd6"/>
    <circle cx="${W / 2}" cy="${H / 2}" r="${W * .4}" fill="${CYAN}" opacity=".18"/><circle cx="${W / 2}" cy="${H / 2}" r="${W * .4}" fill="none" stroke="#cfefff" stroke-width="2" opacity=".7"/><path d="M${W * .28} ${H * .34} Q${W * .34} ${H * .22} ${W * .46} ${H * .18}" stroke="#fff" stroke-width="3" fill="none" opacity=".6"/>`,

  // ---------- 소품 ----------
  book: (W, H) => {
    const C = [PINK, CYAN, '#ffd65c', '#7b5cff', '#e2704a', '#5fb889'];
    let x = 6;
    return `${shadow(2, 2, W - 4, H - 4, 3)}<rect x="2" y="2" width="${W - 4}" height="${H - 4}" rx="3" fill="#7b6cd0"/>` +
      C.map((c, i) => { const w = [16, 12, 18, 10, 14, 12][i] * W / 140; const r = `<rect x="${x}" y="${H * .14 + (i % 2) * 3}" width="${w}" height="${H * .66}" fill="${c}"/><rect x="${x}" y="${H * .14 + (i % 2) * 3}" width="${w}" height="3" fill="#fff" opacity=".35"/>`; x += w + 2; return r; }).join('');
  },
  figure: (W, H) => `<rect x="${W * .1}" y="${H * .2}" width="${W * .8}" height="${H * .6}" rx="4" fill="#9aa0b4"/>${shadow(W * .25, H * .1, W * .5, H * .7, 5)}<rect x="${W * .25}" y="${H * .1}" width="${W * .5}" height="${H * .7}" rx="5" fill="#e6e8f0"/>
    <rect x="${W * .3}" y="${H * .55}" width="${W * .4}" height="${H * .18}" fill="#2a2440"/><rect x="${W * .36}" y="${H * .6}" width="4" height="4" fill="${CYAN}"/><rect x="${W * .58}" y="${H * .6}" width="4" height="4" fill="${CYAN}"/><circle cx="${W / 2}" cy="${H * .3}" r="4" fill="${PINK}"/>`,
  block_ship: (W, H) => `<rect x="${W * .3}" y="${H * .3}" width="${W * .4}" height="${H * .4}" fill="#2a2440"/>
    <path d="M${W * .12} ${H * .5} L${W * .3} ${H * .1} L${W * .9} ${H * .38} L${W * .96} ${H * .5} L${W * .9} ${H * .62} L${W * .3} ${H * .9} Z" fill="#000" opacity=".35" transform="translate(3 4)"/>
    <path d="M${W * .12} ${H * .5} L${W * .3} ${H * .1} L${W * .9} ${H * .38} L${W * .96} ${H * .5} L${W * .9} ${H * .62} L${W * .3} ${H * .9} Z" fill="#e6e8f0"/><path d="M${W * .3} ${H * .1} L${W * .9} ${H * .38} L${W * .3} ${H * .38} Z" fill="#c9ccd6"/>
    <rect x="${W * .6}" y="${H * .42}" width="${W * .16}" height="${H * .16}" fill="${CYAN}"/><rect x="${W * .04}" y="${H * .38}" width="${W * .1}" height="${H * .24}" fill="${PINK}"/>`,
  candle: (W, H) => `<defs><radialGradient id="flame"><stop offset="0" stop-color="#ffd27a" stop-opacity=".7"/><stop offset="1" stop-color="#ffd27a" stop-opacity="0"/></radialGradient></defs>
    ${cshadow(W / 2, H / 2, W * .4)}<circle cx="${W / 2}" cy="${H / 2}" r="${W * .4}" fill="#a99be0"/><circle cx="${W / 2}" cy="${H / 2}" r="${W * .32}" fill="#f4f0ff"/>
    <circle cx="${W / 2}" cy="${H / 2}" r="${W * .3}" fill="url(#flame)"/><circle cx="${W / 2}" cy="${H / 2}" r="3" fill="#ffb84a"/>`,
  diffuser: (W, H) => `${cshadow(W / 2, H / 2, W * .3)}<circle cx="${W / 2}" cy="${H / 2}" r="${W * .3}" fill="#7a6cb0"/><circle cx="${W / 2}" cy="${H / 2}" r="${W * .14}" fill="#4a3c80"/>
    ${[0, 1, 2, 3, 4, 5, 6].map(i => { const a = i * 0.9 - 2.4; return `<path d="M${W / 2} ${H / 2} L${W / 2 + Math.cos(a) * W * .48} ${H / 2 + Math.sin(a) * H * .48}" stroke="#8a5a34" stroke-width="2"/>`; }).join('')}`,
  desk_clock: (W, H) => `${shadow(2, 2, W - 4, H - 4, 4)}<rect x="2" y="2" width="${W - 4}" height="${H - 4}" rx="4" fill="#2a2440"/><rect x="2" y="2" width="${W - 4}" height="4" fill="#4a4370"/>
    <rect x="${W / 2 - 1}" y="4" width="2" height="${H - 8}" fill="#14102a"/><rect x="6" y="${H - 9}" width="${W - 12}" height="4" fill="#ffd65c" opacity=".8"/>`,
  calendar: (W, H) => `<path d="M2 ${H - 3} L${W / 2} 3 L${W - 2} ${H - 3} Z" fill="#000" opacity=".3" transform="translate(3 3)"/>
    <rect x="2" y="2" width="${W - 4}" height="${H - 4}" rx="2" fill="#f4f4fa"/><rect x="2" y="2" width="${W - 4}" height="${H * .4}" fill="#e6e8f0"/><rect x="2" y="${H * .4}" width="${W - 4}" height="3" fill="${PINK}"/>
    ${[...Array(6)].map((_, i) => `<rect x="${8 + i * (W - 16) / 6}" y="${H * .4 - 2}" width="3" height="7" fill="#9aa0b4"/>`).join('')}`,
  pen_holder: (W, H) => `${cshadow(W / 2, H / 2, W * .42)}<circle cx="${W / 2}" cy="${H / 2}" r="${W * .42}" fill="#2a2440"/><circle cx="${W / 2}" cy="${H / 2}" r="${W * .34}" fill="#14102a"/>
    ${[[PINK, -.12, -.1], [CYAN, .1, -.12], ['#ffd65c', .14, .1], ['#7b5cff', -.1, .12], ['#fff', 0, 0]].map(([c, dx, dy]) => `<circle cx="${W / 2 + dx * W}" cy="${H / 2 + dy * H}" r="3.5" fill="${c}"/>`).join('')}`,
  photo: (W, H) => `<path d="M${W / 2} ${H * .4} L${W / 2} ${H - 2}" stroke="#5a3a20" stroke-width="4"/>${shadow(2, 2, W - 4, H * .4, 2)}<rect x="2" y="2" width="${W - 4}" height="${H * .4}" rx="2" fill="#8a5a34"/><rect x="2" y="2" width="${W - 4}" height="3" fill="#b07a4a"/>`,
  globe: (W, H) => `${cshadow(W / 2, H / 2, W * .3)}<circle cx="${W / 2}" cy="${H / 2}" r="${W * .3}" fill="#2a2440"/>
    <circle cx="${W / 2}" cy="${H / 2}" r="${W * .4}" fill="#3a7ac8"/><path d="M${W * .3} ${H * .35} q8 -6 16 0 q4 8 -6 12 q-10 2 -10 -12 Z M${W * .55} ${H * .55} q10 -4 14 4 q-2 10 -12 8 Z" fill="#5fb889"/>
    <circle cx="${W * .4}" cy="${H * .36}" r="${W * .1}" fill="#fff" opacity=".25"/><path d="M${W * .12} ${H * .6} A${W * .4} ${W * .4} 0 0 0 ${W * .6} ${H * .9}" stroke="#c9ccd6" stroke-width="3" fill="none"/>`,
  gamepad: (W, H) => `<defs>${rgb('gp')}</defs><rect x="${W * .2}" y="${H * .6}" width="${W * .6}" height="${H * .35}" fill="url(#gp)"/>
    <path d="M${W * .12} ${H * .2} Q${W / 2} ${H * .1} ${W * .88} ${H * .2} Q${W * 1.02} ${H * .8} ${W * .8} ${H * .82} Q${W * .66} ${H * .82} ${W * .6} ${H * .64} L${W * .4} ${H * .64} Q${W * .34} ${H * .82} ${W * .2} ${H * .82} Q${-W * .02} ${H * .8} ${W * .12} ${H * .2} Z" fill="#000" opacity=".3" transform="translate(3 3)"/>
    <path d="M${W * .12} ${H * .2} Q${W / 2} ${H * .1} ${W * .88} ${H * .2} Q${W * 1.02} ${H * .8} ${W * .8} ${H * .82} Q${W * .66} ${H * .82} ${W * .6} ${H * .64} L${W * .4} ${H * .64} Q${W * .34} ${H * .82} ${W * .2} ${H * .82} Q${-W * .02} ${H * .8} ${W * .12} ${H * .2} Z" fill="#f4f4fa"/>
    <rect x="${W * .2}" y="${H * .38}" width="${W * .14}" height="4" fill="#2a2440"/><rect x="${W * .25}" y="${H * .3}" width="4" height="${H * .22}" fill="#2a2440"/>
    <circle cx="${W * .72}" cy="${H * .32}" r="3" fill="${PINK}"/><circle cx="${W * .8}" cy="${H * .42}" r="3" fill="${CYAN}"/><circle cx="${W * .64}" cy="${H * .42}" r="3" fill="#ffd65c"/><circle cx="${W * .72}" cy="${H * .52}" r="3" fill="#7b5cff"/>`,
};
Object.assign(DRAW, require('./props_sprites').top);   // 소품 확장
const TINT = ['mug', 'mouse_gaming', 'kb_mini', 'mood_lamp', 'speaker_bt', 'headphones', 'desk_clock', 'gamepad', 'tumbler', 'rgb_cube'];

(async () => {
  for (const [id, draw] of Object.entries(DRAW)) {
    const it = ITEMS.find(i => i.id === id);
    if (!it || !it.foot) throw new Error(`${id}: items.json에 foot이 없어요`);
    const [W, H] = it.foot.map(v => Math.round(v * UNIT));
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${draw(W, H)}</svg>`;
    const small = await sharp(Buffer.from(svg)).resize(Math.ceil(W / 2), Math.ceil(H / 2), { kernel: 'nearest' }).png().toBuffer();
    await sharp(small).resize(W, H, { kernel: 'nearest' }).png().toFile(path.join(OUT, `top_${id}.png`));
    if (TINT.includes(id))
      for (let k = 1; k <= 3; k++) await sharp(small).modulate({ hue: 90 * k }).resize(W, H, { kernel: 'nearest' }).png().toFile(path.join(OUT, `top_${id}__c${k}.png`));
  }
  console.log(Object.keys(DRAW).length, 'top sprites');
})();
