// 소품 확장 스프라이트: 정면(front) + 탑뷰(top). make_sprites.js · top_sprites.js가 불러서 더한다.
// 정면: [가로, 세로, SVG] (바닥선 = 그림 아래, 1칸 = 98px · 2칸 = 208px)
// 탑뷰: (W, H) => SVG, 위쪽이 벽, 빛은 왼쪽 위
const CYAN = '#2ee6d6', PINK = '#ff4d8d', GOLD = '#ffd65c', VIO = '#7b5cff', INK = '#14102a', MID = '#2a2350';
const glow = (id, sd) => `<filter id="${id}" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="${sd}"/></filter>`;
const sh = (x, y, w, h, r = 4) => `<rect x="${x + 3}" y="${y + 4}" width="${w}" height="${h}" rx="${r}" fill="#000" opacity=".35"/>`;
const csh = (cx, cy, r) => `<circle cx="${cx + 3}" cy="${cy + 4}" r="${r}" fill="#000" opacity=".35"/>`;
const pot = (x, w, y, h, c) => `<path d="M${x} ${y} L${x + w} ${y} L${x + w - 6} ${y + h} L${x + 6} ${y + h} Z" fill="${c}"/><rect x="${x - 3}" y="${y - 6}" width="${w + 6}" height="8" fill="${c}"/>`;

const front = {
  headphone_stand: [98, 130, `<ellipse cx="49" cy="126" rx="30" ry="5" fill="${MID}"/><rect x="45" y="30" width="8" height="96" fill="#3b3170"/>
    <path d="M22 70 Q22 26 49 26 Q76 26 76 70" stroke="${INK}" stroke-width="9" fill="none"/><rect x="12" y="60" width="20" height="36" rx="8" fill="${INK}"/><rect x="66" y="60" width="20" height="36" rx="8" fill="${INK}"/>
    <rect x="16" y="66" width="12" height="24" rx="5" fill="${PINK}"/><rect x="70" y="66" width="12" height="24" rx="5" fill="${PINK}"/><rect x="38" y="20" width="22" height="8" rx="3" fill="#c9ccd6"/>`],
  tumbler: [98, 90, `<path d="M36 18 L62 18 L58 86 L40 86 Z" fill="#e8e6f2"/><rect x="34" y="10" width="30" height="10" rx="3" fill="${CYAN}"/>
    <rect x="40" y="40" width="18" height="16" fill="#c9b8ff"/><rect x="58" y="14" width="3" height="12" fill="#fff"/><ellipse cx="49" cy="88" rx="22" ry="3" fill="#8b5e3c"/>`],
  book_stack: [98, 84, `${[[10, 62, 78, '#7b5cff'], [16, 46, 66, '#ff4d8d'], [8, 30, 72, '#2ee6d6'], [20, 16, 58, '#ffd65c']].map(([x, y, w, c]) => `<rect x="${x}" y="${y}" width="${w}" height="16" rx="2" fill="${c}"/><rect x="${x + w - 8}" y="${y + 2}" width="5" height="12" fill="#f4f0ff"/><rect x="${x + 6}" y="${y + 6}" width="${w * .4}" height="3" fill="${INK}" opacity=".4"/>`).join('')}
    <rect x="4" y="78" width="90" height="6" fill="#000" opacity=".2"/>`],
  salt_lamp: [98, 110, `<defs>${glow('sl', 9)}</defs><ellipse cx="49" cy="56" rx="38" ry="46" fill="#ff9a6a" opacity=".45" filter="url(#sl)"/>
    <path d="M30 96 L24 62 L34 26 L52 12 L68 30 L74 64 L66 96 Z" fill="#ff9a6a"/><path d="M34 26 L52 12 L50 44 Z M24 62 L50 44 L30 96 Z" fill="#ffc29a"/><path d="M68 30 L74 64 L52 60 Z" fill="#e5784c"/>
    <rect x="22" y="96" width="54" height="12" rx="2" fill="#8b5e3c"/><rect x="22" y="96" width="54" height="3" fill="#a8774f"/>`],
  rgb_cube: [98, 80, `<defs>${glow('rc', 7)}<linearGradient id="rcg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${PINK}"/><stop offset=".5" stop-color="${VIO}"/><stop offset="1" stop-color="${CYAN}"/></linearGradient></defs>
    <rect x="22" y="12" width="54" height="54" fill="url(#rcg)" opacity=".55" filter="url(#rc)"/><rect x="28" y="18" width="42" height="42" fill="url(#rcg)"/>
    <rect x="34" y="24" width="30" height="30" fill="#fff" opacity=".25"/><rect x="24" y="60" width="50" height="16" rx="2" fill="${INK}"/><circle cx="66" cy="68" r="2" fill="${CYAN}"/>`],
  desk_fan: [98, 110, `<circle cx="49" cy="44" r="36" fill="#e8e6f2"/><circle cx="49" cy="44" r="30" fill="#c9ecf5"/>
    ${[0, 1, 2, 3, 4].map(i => `<ellipse cx="49" cy="28" rx="7" ry="15" fill="#9fd8e6" transform="rotate(${i * 72} 49 44)"/>`).join('')}
    ${[...Array(8)].map((_, i) => `<path d="M49 44 L${49 + Math.cos(i * .785) * 34} ${44 + Math.sin(i * .785) * 34}" stroke="#e8e6f2" stroke-width="2"/>`).join('')}
    <circle cx="49" cy="44" r="7" fill="${PINK}"/><rect x="44" y="78" width="10" height="20" fill="#e8e6f2"/><ellipse cx="49" cy="102" rx="26" ry="7" fill="#e8e6f2"/><circle cx="64" cy="102" r="2" fill="${CYAN}"/>`],
  humidifier: [98, 120, `<path d="M40 50 Q30 30 42 14 Q50 4 46 -6" stroke="#fff" stroke-width="6" fill="none" opacity=".35"/><path d="M54 50 Q64 32 56 18" stroke="#fff" stroke-width="5" fill="none" opacity=".25"/>
    <path d="M28 116 L70 116 L74 62 Q49 48 24 62 Z" fill="#f4f0ff"/><ellipse cx="49" cy="60" rx="24" ry="7" fill="#e8e6f2"/><ellipse cx="49" cy="60" rx="6" ry="2" fill="${INK}"/>
    <rect x="30" y="92" width="38" height="5" fill="${CYAN}" opacity=".7"/><circle cx="49" cy="106" r="3" fill="${CYAN}"/>`],
  succulents: [208, 70, `${[[20, '#8fd18e', 3], [86, '#b4a0e8', 2], [150, '#7fc6b0', 4]].map(([x, c, n], k) => `${pot(x, 44, 46, 22, ['#e76f51', '#f4f0ff', '#ffd65c'][k])}
    ${[...Array(n + 3)].map((_, i) => `<ellipse cx="${x + 22 + (i - (n + 2) / 2) * 7}" cy="${36 - (i % 2) * 6}" rx="7" ry="11" fill="${c}" transform="rotate(${(i - (n + 2) / 2) * 18} ${x + 22} 46)"/>`).join('')}`).join('')}`],
  bonsai: [208, 130, `<path d="M60 112 L148 112 L138 128 L70 128 Z" fill="#3b3170"/><rect x="52" y="104" width="104" height="10" rx="2" fill="#5a4a96"/>
    <path d="M100 106 Q96 84 108 74 Q122 64 114 48" stroke="#6b4429" stroke-width="10" fill="none"/><path d="M108 74 Q86 66 70 70" stroke="#6b4429" stroke-width="6" fill="none"/>
    ${[[70, 62, 30], [116, 36, 36], [148, 60, 24], [92, 44, 22]].map(([x, y, r]) => `<ellipse cx="${x}" cy="${y}" rx="${r}" ry="${r * .55}" fill="#3f8f6e"/><ellipse cx="${x - 4}" cy="${y - 5}" rx="${r * .7}" ry="${r * .35}" fill="#56b08a"/>`).join('')}
    <circle cx="74" cy="104" r="4" fill="#c9ccd6"/>`],
  lucky_cat: [98, 96, `<rect x="24" y="40" width="50" height="52" rx="16" fill="#f4f0ff"/><circle cx="49" cy="34" r="22" fill="#f4f0ff"/>
    <path d="M30 22 L32 6 L44 16 Z M68 22 L66 6 L54 16 Z" fill="#f4f0ff"/><path d="M33 18 L34 10 L40 16 Z M65 18 L64 10 L58 16 Z" fill="${PINK}"/>
    <path d="M38 34 q4 -4 8 0 M52 34 q4 -4 8 0" stroke="${INK}" stroke-width="2" fill="none"/><circle cx="49" cy="40" r="2" fill="${PINK}"/>
    <rect x="66" y="22" width="12" height="26" rx="6" fill="#f4f0ff"/><rect x="34" y="56" width="30" height="22" rx="4" fill="${GOLD}"/><rect x="36" y="64" width="26" height="3" fill="#e5a93c"/>
    <rect x="30" y="52" width="38" height="4" fill="${PINK}"/><circle cx="49" cy="56" r="4" fill="${GOLD}"/>`],
  rubik: [98, 50, `${[0, 1, 2].map(r => [0, 1, 2].map(c => `<rect x="${34 + c * 10}" y="${12 + r * 10}" width="9" height="9" fill="${[PINK, CYAN, GOLD, '#f4f0ff', VIO, '#56b08a', CYAN, PINK, GOLD][r * 3 + c]}"/>`).join('')).join('')}
    <path d="M33 11 L64 11 L70 5 L39 5 Z" fill="#c9b8ff"/><path d="M64 11 L70 5 L70 36 L64 42 Z" fill="${INK}"/>`],
  tissue: [208, 60, `<rect x="40" y="22" width="128" height="34" rx="6" fill="#e8e6f2"/><rect x="40" y="22" width="128" height="6" rx="3" fill="#fff"/>
    <rect x="80" y="30" width="48" height="14" rx="4" fill="#cfcbe0"/><path d="M92 30 Q104 6 116 30 Z" fill="#fff"/><rect x="44" y="50" width="120" height="4" fill="#c9b8ff"/>`],
  stream_deck: [98, 60, `<defs>${glow('sd', 3)}</defs><path d="M18 56 L80 56 L74 26 L24 26 Z" fill="${INK}"/><path d="M28 50 L70 50 L66 30 L32 30 Z" fill="${MID}"/>
    ${[0, 1].map(r => [0, 1, 2].map(c => `<rect x="${34 + c * 11 - r * 1}" y="${33 + r * 8}" width="8" height="6" fill="${[PINK, CYAN, GOLD, VIO, '#56b08a', PINK][r * 3 + c]}" filter="url(#sd)"/><rect x="${34 + c * 11 - r * 1}" y="${33 + r * 8}" width="8" height="6" fill="${[PINK, CYAN, GOLD, VIO, '#56b08a', PINK][r * 3 + c]}"/>`).join('')).join('')}`],
  neon_gg: [208, 110, `<defs>${glow('gg', 5)}</defs><rect x="4" y="4" width="200" height="102" rx="8" fill="#120a26" opacity=".6"/>
    <g filter="url(#gg)" stroke="${CYAN}" stroke-width="9" fill="none"><path d="M88 32 Q48 22 46 56 Q48 88 88 80 L88 58 L68 58"/><path d="M166 32 Q126 22 124 56 Q126 88 166 80 L166 58 L146 58"/></g>
    <g stroke="#cffffa" stroke-width="3" fill="none"><path d="M88 32 Q48 22 46 56 Q48 88 88 80 L88 58 L68 58"/><path d="M166 32 Q126 22 124 56 Q126 88 166 80 L166 58 L146 58"/></g>`],
  acoustic: [208, 120, `${[0, 1, 2].map(r => [0, 1, 2, 3].map(c => `<rect x="${8 + c * 49}" y="${6 + r * 37}" width="45" height="33" fill="${(r + c) % 2 ? '#3b3170' : '#2a2350'}"/>
    ${[0, 1, 2].map(k => `<path d="M${10 + c * 49} ${12 + r * 37 + k * 10} L${51 + c * 49} ${12 + r * 37 + k * 10}" stroke="${(r + c) % 2 ? '#2a2350' : '#3b3170'}" stroke-width="3"/>`).join('')}`).join('')).join('')}`],
  hex_light: [208, 120, `<defs>${glow('hx', 6)}</defs>${[[60, 40, PINK], [98, 62, VIO], [136, 40, CYAN], [98, 18, GOLD], [136, 84, PINK]].map(([x, y, c]) => {
      const p = [...Array(6)].map((_, i) => `${x + Math.cos(i * 1.047) * 22},${y + Math.sin(i * 1.047) * 22}`).join(' ');
      return `<polygon points="${p}" fill="${c}" opacity=".5" filter="url(#hx)"/><polygon points="${p}" fill="#1a1230" stroke="${c}" stroke-width="4"/>`;
    }).join('')}`],
  world_map: [208, 120, `<rect x="4" y="6" width="200" height="110" fill="#8b5e3c"/><rect x="10" y="12" width="188" height="98" fill="#1e3a6e"/>
    <path d="M24 30 q20 -10 40 2 q8 14 -4 24 q-14 4 -18 18 q-14 -6 -18 -20 Z M78 26 q16 -6 30 4 q-4 10 -14 10 q-6 20 -8 34 q-10 -6 -10 -22 Z M118 28 q30 -8 56 6 q6 16 -12 22 q-10 -2 -18 8 q-12 -8 -24 -12 Z M150 78 q12 -6 22 2 q0 12 -14 12 Z" fill="#56b08a"/>
    ${[[52, 44], [96, 40], [150, 46]].map(([x, y]) => `<circle cx="${x}" cy="${y}" r="3" fill="${PINK}"/>`).join('')}<path d="M52 44 Q74 26 96 40 Q122 26 150 46" stroke="${GOLD}" stroke-width="2" stroke-dasharray="4 3" fill="none"/>`],
  vinyl_frame: [98, 104, `<rect x="6" y="4" width="86" height="96" fill="${INK}"/><rect x="10" y="8" width="78" height="88" fill="#241a4a"/>
    <circle cx="49" cy="52" r="34" fill="#0b0816"/>${[26, 20, 14].map(r => `<circle cx="49" cy="52" r="${r}" fill="none" stroke="#2a2350" stroke-width="2"/>`).join('')}
    <circle cx="49" cy="52" r="10" fill="${PINK}"/><circle cx="49" cy="52" r="2" fill="#0b0816"/><path d="M28 34 Q40 24 54 24" stroke="#fff" stroke-width="2" opacity=".2" fill="none"/>`],
};

const top = {
  headphone_stand: (W, H) => `${csh(W / 2, H / 2, W * .36)}<circle cx="${W / 2}" cy="${H / 2}" r="${W * .36}" fill="${MID}"/>
    <rect x="${W * .1}" y="${H * .36}" width="${W * .8}" height="${H * .28}" rx="6" fill="${INK}"/><rect x="${W * .04}" y="${H * .3}" width="${W * .14}" height="${H * .4}" rx="4" fill="${PINK}"/><rect x="${W * .82}" y="${H * .3}" width="${W * .14}" height="${H * .4}" rx="4" fill="${PINK}"/>`,
  tumbler: (W, H) => `${csh(W / 2, H / 2, W * .4)}<circle cx="${W / 2}" cy="${H / 2}" r="${W * .42}" fill="#8b5e3c"/><circle cx="${W / 2}" cy="${H / 2}" r="${W * .32}" fill="${CYAN}"/><circle cx="${W / 2}" cy="${H / 2}" r="${W * .14}" fill="#1a6b66"/>`,
  book_stack: (W, H) => `${sh(2, 2, W - 4, H - 4)}<rect x="2" y="2" width="${W - 4}" height="${H - 4}" rx="2" fill="${GOLD}"/><rect x="${W * .12}" y="${H * .14}" width="${W * .7}" height="${H * .7}" fill="#e5a93c"/>
    <rect x="${W * .2}" y="${H * .3}" width="${W * .5}" height="4" fill="${INK}" opacity=".4"/><rect x="${W - 8}" y="4" width="5" height="${H - 8}" fill="#f4f0ff"/>`,
  salt_lamp: (W, H) => `<defs><radialGradient id="sg"><stop offset="0" stop-color="#ff9a6a" stop-opacity=".6"/><stop offset="1" stop-color="#ff9a6a" stop-opacity="0"/></radialGradient></defs>
    <circle cx="${W / 2}" cy="${H / 2}" r="${W * .5}" fill="url(#sg)"/>${csh(W / 2, H / 2, W * .3)}<circle cx="${W / 2}" cy="${H / 2}" r="${W * .32}" fill="#8b5e3c"/>
    <path d="M${W * .3} ${H * .4} L${W * .5} ${H * .22} L${W * .7} ${H * .42} L${W * .6} ${H * .7} L${W * .36} ${H * .66} Z" fill="#ff9a6a"/><path d="M${W * .3} ${H * .4} L${W * .5} ${H * .22} L${W * .48} ${H * .46} Z" fill="#ffc29a"/>`,
  rgb_cube: (W, H) => `<defs><linearGradient id="cg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${PINK}"/><stop offset="1" stop-color="${CYAN}"/></linearGradient></defs>
    <rect x="0" y="0" width="${W}" height="${H}" fill="url(#cg)" opacity=".25"/>${sh(W * .18, H * .18, W * .64, H * .64)}<rect x="${W * .18}" y="${H * .18}" width="${W * .64}" height="${H * .64}" fill="url(#cg)"/><rect x="${W * .3}" y="${H * .3}" width="${W * .4}" height="${H * .4}" fill="#fff" opacity=".3"/>`,
  desk_fan: (W, H) => `${sh(W * .2, H * .55, W * .6, H * .4, 8)}<rect x="${W * .2}" y="${H * .55}" width="${W * .6}" height="${H * .4}" rx="8" fill="#e8e6f2"/>
    <rect x="${W * .06}" y="${H * .08}" width="${W * .88}" height="${H * .3}" rx="8" fill="#e8e6f2"/><rect x="${W * .12}" y="${H * .14}" width="${W * .76}" height="${H * .18}" rx="4" fill="#9fd8e6"/><rect x="${W * .46}" y="${H * .38}" width="${W * .08}" height="${H * .2}" fill="#c9ccd6"/>`,
  humidifier: (W, H) => `${csh(W / 2, H / 2, W * .4)}<circle cx="${W / 2}" cy="${H / 2}" r="${W * .42}" fill="#f4f0ff"/><circle cx="${W / 2}" cy="${H / 2}" r="${W * .3}" fill="#e8e6f2"/><circle cx="${W / 2}" cy="${H / 2}" r="${W * .1}" fill="${INK}"/>
    <circle cx="${W * .44}" cy="${H * .42}" r="${W * .2}" fill="#fff" opacity=".35"/>`,
  succulents: (W, H) => [0, 1, 2].map(k => { const cx = W * (.18 + k * .32), cy = H / 2, r = Math.min(W * .14, H * .42);
    return `${csh(cx, cy, r)}<circle cx="${cx}" cy="${cy}" r="${r}" fill="${['#e76f51', '#f4f0ff', GOLD][k]}"/>${[...Array(7)].map((_, i) => `<ellipse cx="${cx + Math.cos(i * .9) * r * .45}" cy="${cy + Math.sin(i * .9) * r * .45}" rx="${r * .32}" ry="${r * .2}" fill="${['#8fd18e', '#b4a0e8', '#7fc6b0'][k]}" transform="rotate(${i * 51} ${cx + Math.cos(i * .9) * r * .45} ${cy + Math.sin(i * .9) * r * .45})"/>`).join('')}<circle cx="${cx}" cy="${cy}" r="${r * .2}" fill="#56b08a"/>`; }).join(''),
  bonsai: (W, H) => `${sh(W * .1, H * .25, W * .8, H * .5, 6)}<rect x="${W * .1}" y="${H * .25}" width="${W * .8}" height="${H * .5}" rx="6" fill="#5a4a96"/><rect x="${W * .14}" y="${H * .3}" width="${W * .72}" height="${H * .4}" rx="4" fill="#6b4429"/>
    ${[[.3, .4, .22], [.6, .5, .26], [.75, .35, .16]].map(([x, y, r]) => `<circle cx="${W * x}" cy="${H * y}" r="${W * r}" fill="#3f8f6e"/><circle cx="${W * x - 3}" cy="${H * y - 3}" r="${W * r * .6}" fill="#56b08a"/>`).join('')}`,
  lucky_cat: (W, H) => `${csh(W / 2, H / 2, W * .4)}<circle cx="${W / 2}" cy="${H * .55}" r="${W * .4}" fill="#f4f0ff"/><circle cx="${W / 2}" cy="${H * .4}" r="${W * .3}" fill="#f4f0ff"/>
    <path d="M${W * .2} ${H * .25} L${W * .28} ${H * .05} L${W * .4} ${H * .18} Z M${W * .8} ${H * .25} L${W * .72} ${H * .05} L${W * .6} ${H * .18} Z" fill="${PINK}"/><rect x="${W * .3}" y="${H * .62}" width="${W * .4}" height="4" fill="${PINK}"/>`,
  rubik: (W, H) => `${sh(2, 2, W - 4, H - 4, 1)}${[0, 1, 2].map(r => [0, 1, 2].map(c => `<rect x="${2 + c * (W - 4) / 3}" y="${2 + r * (H - 4) / 3}" width="${(W - 4) / 3 - 1}" height="${(H - 4) / 3 - 1}" fill="${[GOLD, PINK, CYAN, CYAN, '#f4f0ff', VIO, PINK, '#56b08a', GOLD][r * 3 + c]}"/>`).join('')).join('')}`,
  tissue: (W, H) => `${sh(2, 2, W - 4, H - 4, 6)}<rect x="2" y="2" width="${W - 4}" height="${H - 4}" rx="6" fill="#e8e6f2"/><rect x="${W * .3}" y="${H * .35}" width="${W * .4}" height="${H * .3}" rx="4" fill="#cfcbe0"/>
    <path d="M${W * .36} ${H * .5} Q${W / 2} ${H * .1} ${W * .64} ${H * .5} Q${W / 2} ${H * .8} ${W * .36} ${H * .5} Z" fill="#fff"/>`,
  stream_deck: (W, H) => `${sh(2, 2, W - 4, H - 4)}<rect x="2" y="2" width="${W - 4}" height="${H - 4}" rx="4" fill="${INK}"/>
    ${[0, 1].map(r => [0, 1, 2].map(c => `<rect x="${6 + c * (W - 12) / 3}" y="${6 + r * (H - 12) / 2}" width="${(W - 12) / 3 - 3}" height="${(H - 12) / 2 - 3}" rx="1" fill="${[PINK, CYAN, GOLD, VIO, '#56b08a', PINK][r * 3 + c]}"/>`).join('')).join('')}`,
};

// ---- 모니터: 인치마다 크기 · 스탠드 · 화면이 다름. [가로, 화면 높이, 테두리, 스탠드 모양, 화면, 빛]
const scrn = {
  doc: (x, y, w, h) => `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="#e8e6f2"/><rect x="${x}" y="${y}" width="${w}" height="${h * .1}" fill="#cfcbe0"/>${[0, 1, 2, 3, 4, 5].map(i => `<rect x="${x + w * .08}" y="${y + h * (.2 + i * .12)}" width="${w * (.4 + ((i * 37) % 40) / 100)}" height="${h * .05}" fill="#9a94b8"/>`).join('')}`,
  game: (x, y, w, h) => `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="#2a124a"/><rect x="${x}" y="${y + h * .58}" width="${w}" height="${h * .42}" fill="#1b0f3d"/><circle cx="${x + w / 2}" cy="${y + h * .58}" r="${h * .24}" fill="#ffd65c"/>${[0, 1, 2, 3].map(i => `<rect x="${x}" y="${y + h * (.64 + i * .08)}" width="${w}" height="2" fill="#ff4d8d"/>`).join('')}`,
  code: (x, y, w, h) => `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="#160f30"/>${[...Array(Math.floor(h / 10))].map((_, i) => `<rect x="${x + 8 + (i % 3) * 8}" y="${y + 6 + i * 10}" width="${w * (.2 + ((i * 29) % 50) / 100)}" height="4" fill="${['#2ee6d6', '#c9b8ff', '#ff4d8d', '#ffd65c'][i % 4]}"/>`).join('')}`,
  photo: (x, y, w, h) => `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="#1e3a6e"/><path d="M${x} ${y + h} L${x + w * .35} ${y + h * .45} L${x + w * .55} ${y + h * .7} L${x + w * .75} ${y + h * .35} L${x + w} ${y + h} Z" fill="#56b08a"/><circle cx="${x + w * .8}" cy="${y + h * .22}" r="${h * .1}" fill="#ffd65c"/>`,
};
const MON = {};   // id -> [가로, 세로, SVG, 화면 사각형]
const mon = (id, w, sh, frame, stand, screen, glowc, opt = {}) => {
  const h = sh + 12 + (opt.standH || 56);
  const bx = 6, by = 6, bw = w - 12;
  let st;
  if (opt.tripod) st = `<rect x="${w / 2 - 5}" y="${sh + 12}" width="10" height="${opt.standH - 14}" fill="${stand}"/><path d="M${w / 2} ${h - 16} L${w / 2 - 70} ${h} M${w / 2} ${h - 16} L${w / 2 + 70} ${h} M${w / 2} ${h - 16} L${w / 2} ${h}" stroke="${stand}" stroke-width="6"/>`;
  else if (opt.vstand) st = `<rect x="${w / 2 - 6}" y="${sh + 12}" width="12" height="${opt.standH - 10}" fill="${stand}"/><path d="M${w / 2} ${h - 10} L${w / 2 - 60} ${h} L${w / 2 - 48} ${h} L${w / 2} ${h - 4} L${w / 2 + 48} ${h} L${w / 2 + 60} ${h} Z" fill="${stand}"/>`;
  else if (opt.kick) st = `<path d="M${w * .3} ${sh + 12} L${w * .2} ${h} L${w * .26} ${h} L${w * .36} ${sh + 12} Z" fill="${stand}"/>`;
  else st = `<rect x="${w / 2 - 8}" y="${sh + 12}" width="16" height="${(opt.standH || 56) - 12}" fill="${stand}"/><path d="M${w / 2 - 44} ${h} L${w / 2 + 44} ${h} L${w / 2 + 36} ${h - 12} L${w / 2 - 36} ${h - 12} Z" fill="${stand}"/>`;
  MON[id] = [w, h, `<defs>${glow('g_' + id, 10)}</defs>
    <ellipse cx="${w / 2}" cy="${sh / 2}" rx="${w / 2 - 4}" ry="${sh / 2}" fill="${glowc}" opacity=".28" filter="url(#g_${id})"/>${st}
    <rect x="0" y="0" width="${w}" height="${sh + 12}" rx="4" fill="${frame}"/>${screen(bx, by, bw, sh)}
    <path d="M${w - 50} ${by} L${w - 6} ${by} L${w - 6} ${by + 30} Z" fill="#fff" opacity=".05"/>${opt.accent ? `<rect x="0" y="${sh + 8}" width="${w}" height="4" fill="${opt.accent}"/>` : ''}`, [bx, by, bx + bw, by + sh]];
};
mon('monitor_22', 190, 104, '#2a2440', '#3b3466', scrn.doc, '#2ee6d6');
mon('monitor_144', 208, 114, '#0f0a22', '#2a2350', scrn.game, '#ff4d8d', { accent: '#ff4d8d' });
mon('monitor_240', 216, 118, '#0f0a22', '#1c1830', scrn.game, '#ff4d8d', { vstand: true, standH: 60, accent: '#2ee6d6' });
mon('monitor_qhd165', 234, 128, '#14102a', '#2a2350', scrn.game, '#7b5cff', { accent: '#7b5cff' });
mon('monitor_4k', 276, 150, '#1a1830', '#3b3466', scrn.photo, '#2ee6d6', { standH: 60 });
mon('monitor_oled', 234, 128, '#0b0816', '#2a2350', scrn.game, '#ff4d8d', { tripod: true, standH: 72, accent: '#ff4d8d' });
mon('monitor_pivot', 110, 190, '#2a2440', '#3b3466', scrn.code, '#2ee6d6');
mon('monitor_portable', 140, 78, '#c9ccd6', '#9aa0b4', scrn.doc, '#2ee6d6', { kick: true, standH: 24 });
// 게이밍 노트북
const laptopG = [208, 130, `<path d="M20 4 L188 4 L188 110 L20 110 Z" fill="#14102a"/><rect x="28" y="12" width="152" height="90" fill="#2a124a"/>
    <rect x="28" y="58" width="152" height="44" fill="#1b0f3d"/><circle cx="104" cy="58" r="20" fill="#ffd65c"/>${[0, 1, 2].map(i => `<rect x="28" y="${64 + i * 9}" width="152" height="2" fill="#ff4d8d"/>`).join('')}
    <path d="M0 112 L208 112 L196 128 L12 128 Z" fill="#1c1830"/><rect x="24" y="114" width="160" height="3" fill="#ff4d8d"/><rect x="40" y="119" width="128" height="3" fill="#2ee6d6"/>`];
for (const [id, v] of Object.entries(MON)) front[id] = v.slice(0, 3);
front.laptop_gaming = laptopG;
const monTop = (body, top, glow) => (W, H) => `<path d="M6 ${H * .3} L${W - 6} ${H * .3} L${W - 24} ${H} L24 ${H} Z" fill="${glow}" opacity=".18"/>
  ${sh(2, 4, W - 4, H * .22, 3)}<rect x="2" y="4" width="${W - 4}" height="${H * .22}" rx="3" fill="${body}"/><rect x="2" y="4" width="${W - 4}" height="5" rx="2" fill="${top}"/><rect x="2" y="${4 + H * .22 - 3}" width="${W - 4}" height="3" fill="${glow}"/>
  <rect x="${W / 2 - 7}" y="${H * .26}" width="14" height="${H * .2}" fill="${top}"/>${sh(W * .32, H * .44, W * .36, H * .48, 8)}<rect x="${W * .32}" y="${H * .44}" width="${W * .36}" height="${H * .48}" rx="8" fill="${body}"/>`;
Object.assign(top, {
  monitor_22: monTop('#2a2440', '#3b3466', CYAN), monitor_144: monTop('#0f0a22', '#2a2350', PINK), monitor_240: monTop('#0f0a22', '#2a2350', CYAN),
  monitor_qhd165: monTop('#14102a', '#2a2350', VIO), monitor_4k: monTop('#1a1830', '#3b3466', CYAN), monitor_oled: monTop('#0b0816', '#2a2350', PINK),
  monitor_pivot: monTop('#2a2440', '#3b3466', CYAN), monitor_portable: (W, H) => `${sh(2, 2, W - 4, H - 6, 2)}<rect x="2" y="2" width="${W - 4}" height="${H - 6}" rx="2" fill="#c9ccd6"/><rect x="2" y="${H - 7}" width="${W - 4}" height="3" fill="${CYAN}"/>`,
  laptop_gaming: (W, H) => `${sh(2, 2, W - 4, H - 4, 5)}<rect x="2" y="2" width="${W - 4}" height="${H * .14}" rx="3" fill="#14102a"/><rect x="2" y="${2 + H * .14 - 3}" width="${W - 4}" height="3" fill="${PINK}"/>
    <rect x="2" y="${H * .18}" width="${W - 4}" height="${H * .8}" rx="4" fill="#1c1830"/>${[0, 1, 2, 3].map(r => `<rect x="${W * .1}" y="${H * (.26 + r * .11)}" width="${W * .8}" height="${H * .07}" fill="${[PINK, VIO, CYAN, VIO][r]}" opacity=".7"/>`).join('')}<rect x="${W * .35}" y="${H * .74}" width="${W * .3}" height="${H * .16}" rx="3" fill="#2a2350"/>`,
});
module.exports = { front, top, MON };
