// 탑뷰(위에서 본) 소품 그림: top_<id>.png, 크기 = [정면 그림 너비, 앞뒤 깊이(items.json depth)].
// 위쪽이 벽(뒤), 아래쪽이 앞. 빛은 왼쪽 위. 정면 그림과 같은 도트 처리(1/2로 줄였다 nearest로 키움).
// 실행: node tools/top_sprites.js
const sharp = require('sharp'), path = require('path');
const OUT = path.join(__dirname, '..', 'resource');
const INK = '#120a26', CYAN = '#2ee6d6', PINK = '#ff4d8d';
const shadow = (x, y, w, h, r = 6) => `<rect x="${x + 3}" y="${y + 4}" width="${w}" height="${h}" rx="${r}" fill="#000" opacity=".35"/>`;
const rgb = id => `<linearGradient id="${id}" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="${PINK}"/><stop offset=".5" stop-color="#7b5cff"/><stop offset="1" stop-color="${CYAN}"/></linearGradient>`;
const S = {};

// 모니터: 뒤판(얇은 막대) + 목 + 받침, 앞쪽 책상에 화면 빛
S.top_monitor = [208, 70, `<defs><linearGradient id="spill" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${CYAN}" stop-opacity=".35"/><stop offset="1" stop-color="${CYAN}" stop-opacity="0"/></linearGradient></defs>
  <path d="M8 20 L200 20 L184 70 L24 70 Z" fill="url(#spill)"/>
  ${shadow(4, 6, 200, 14, 3)}<rect x="4" y="6" width="200" height="14" rx="3" fill="#2a2440"/><rect x="4" y="6" width="200" height="4" rx="2" fill="#3e3760"/>
  <rect x="4" y="18" width="200" height="3" fill="${CYAN}"/>
  <rect x="96" y="20" width="16" height="16" fill="#3e3760"/>
  ${shadow(62, 34, 84, 28, 8)}<rect x="62" y="34" width="84" height="28" rx="8" fill="#2a2440"/><rect x="62" y="34" width="84" height="8" rx="6" fill="#4a4370"/><rect x="66" y="56" width="76" height="3" fill="#1a1530"/>`];

// 키보드 + 마우스
const keys = (x0, y0, cols, rows, w, h, gap, c) => [...Array(rows)].map((_, r) => [...Array(cols)].map((_, k) => `<rect x="${x0 + k * (w + gap)}" y="${y0 + r * (h + gap)}" width="${w}" height="${h}" fill="${c}"/>`).join('')).join('');
S.top_keyboard = [98, 44, `${shadow(2, 6, 76, 32, 3)}<rect x="2" y="6" width="76" height="32" rx="3" fill="#c9ccd6"/>
  ${keys(5, 9, 10, 4, 5, 5, 2, '#f4f4fa')}<rect x="17" y="33" width="38" height="3" fill="#f4f4fa"/>
  ${shadow(82, 12, 14, 22, 7)}<rect x="82" y="12" width="14" height="22" rx="7" fill="#e6e8f0"/><rect x="88" y="14" width="2" height="7" fill="#9aa0b4"/>`];

// 게이밍 마우스 + RGB 패드
S.top_mouse_gaming = [98, 70, `<defs>${rgb('pad')}</defs>${shadow(4, 4, 90, 62, 5)}<rect x="4" y="4" width="90" height="62" rx="5" fill="url(#pad)"/><rect x="7" y="7" width="84" height="56" rx="4" fill="#14102a"/>
  ${shadow(50, 18, 22, 36, 11)}<rect x="50" y="18" width="22" height="36" rx="11" fill="#2a2440"/><rect x="50" y="18" width="22" height="14" rx="9" fill="#3e3760"/>
  <rect x="60" y="20" width="2" height="9" fill="${CYAN}"/><rect x="53" y="40" width="16" height="3" fill="${PINK}"/>`];

// 스탠드: 둥근 받침 → 팔 → 갓(따뜻한 빛이 책상에 번짐)
S.top_lamp_warm = [98, 70, `<defs><radialGradient id="warm"><stop offset="0" stop-color="#ffd27a" stop-opacity=".55"/><stop offset="1" stop-color="#ffd27a" stop-opacity="0"/></radialGradient></defs>
  <circle cx="62" cy="34" r="34" fill="url(#warm)"/>
  <circle cx="27" cy="51" r="15" fill="#000" opacity=".35"/><circle cx="24" cy="48" r="15" fill="#3a3354"/><circle cx="21" cy="45" r="6" fill="#4e4670"/>
  <path d="M26 46 L58 28" stroke="#5a5280" stroke-width="5"/>
  <circle cx="65" cy="28" r="19" fill="#000" opacity=".35"/><circle cx="62" cy="25" r="19" fill="#f2a541"/><circle cx="56" cy="19" r="7" fill="#ffd27a"/><circle cx="62" cy="25" r="19" fill="none" stroke="#b8741f" stroke-width="3"/>`];

// 하트 머그: 위에서 보면 커피 위 하트 라테아트
S.top_mug = [98, 60, `<rect x="16" y="6" width="56" height="50" rx="8" fill="#5a4a7a" opacity=".6"/>
  <circle cx="47" cy="34" r="22" fill="#000" opacity=".35"/><rect x="62" y="24" width="18" height="10" rx="4" fill="#e85d8a"/>
  <circle cx="44" cy="30" r="22" fill="#ff7aa8"/><circle cx="44" cy="30" r="17" fill="#ffd0e0"/><circle cx="44" cy="30" r="14" fill="#5a2e1e"/>
  <path d="M44 37 L36 29 A4 4 0 0 1 44 24 A4 4 0 0 1 52 29 Z" fill="#f2e2cc"/>`];

const TINT = ['top_mug', 'top_mouse_gaming'];
(async () => {
  for (const [name, [w, h, body]] of Object.entries(S)) {
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">${body}</svg>`;
    const small = await sharp(Buffer.from(svg)).resize(Math.ceil(w / 2), Math.ceil(h / 2), { kernel: 'nearest' }).png().toBuffer();
    await sharp(small).resize(w, h, { kernel: 'nearest' }).png().toFile(path.join(OUT, name + '.png'));
    if (TINT.includes(name))
      for (let k = 1; k <= 3; k++) await sharp(small).modulate({ hue: 90 * k }).resize(w, h, { kernel: 'nearest' }).png().toFile(path.join(OUT, `${name}__c${k}.png`));
  }
  console.log(Object.keys(S).length, 'top sprites');
})();
