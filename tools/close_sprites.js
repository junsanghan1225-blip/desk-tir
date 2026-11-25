// 진단 '근접' 뷰 그림: 실제 매크로 사진처럼 보이게. node tools/close_sprites.js
// 칸 크기는 diag.gd CLOSE_* 영역과 같음 (RAM · 팬 단자 · GPU 전원 = 602x244, 방열판 292x244, 콘덴서 282x244)
const sharp = require('sharp'), path = require('path');
const OUT = path.join(__dirname, '..', 'resource');
const R = (n, f) => [...Array(n)].map((_, i) => f(i)).join('');

// 무광 검정 기판 + 흐릿한 배선 + 작은 부품 + 흰 실크 글씨
const board = (w, h, seed, silk = '') => `<rect width="${w}" height="${h}" fill="#16151d"/>
  ${R(14, i => { const y = (i * 37 + seed * 13) % h, x = (i * 71 + seed * 29) % w; return `<path d="M${x} ${y} H${x + 60 + i % 4 * 30} L${x + 80 + i % 4 * 30} ${y + 14} H${x + 160 + i * 7 % 90}" stroke="#22212c" stroke-width="2" fill="none"/>`; })}
  ${R(10, i => `<rect x="${(i * 97 + seed * 41) % (w - 12)}" y="${(i * 61 + seed * 17) % (h - 8)}" width="${i % 2 ? 8 : 12}" height="${i % 2 ? 5 : 6}" fill="${i % 3 ? '#2c2a36' : '#8a6a3a'}"/>`)}
  <circle cx="${w - 18}" cy="18" r="7" fill="#0b0a10" stroke="#8a8f9c" stroke-width="2"/>${silk}`;
const silk = (x, y, s, sz = 13) => `<text x="${x}" y="${y}" font-family="monospace" font-weight="700" font-size="${sz}" fill="#d9d7e2">${s}</text>`;

const S = {
  // ---- RAM: 옆에서 본 모습 (기판 위에 선 슬롯) ----
  close_ram_bg: [602, 244, `<rect width="602" height="244" fill="#0f0e15"/>
    <path d="M0 150 L602 150 L602 244 L0 244 Z" fill="#17161e"/>${R(9, i => `<path d="M${i * 75} 244 L${260 + i * 12} 150" stroke="#201f29" stroke-width="2"/>`)}
    ${silk(30, 232, 'DIMM_A1  DIMM_A2  DIMM_B1  DIMM_B2', 12)}`],
  close_ram: [480, 120, `<rect x="0" y="0" width="480" height="86" rx="3" fill="#2b2a34"/><rect x="0" y="0" width="480" height="6" fill="#4a4858"/>
    <path d="M0 6 L480 6 L480 22 L0 22 Z" fill="#33323d"/><rect x="0" y="40" width="480" height="4" fill="#c2364f"/>
    <rect x="150" y="50" width="180" height="26" rx="2" fill="#e8e6f0"/>${silk(160, 68, 'DDR4 3200 8GB', 13).replace('#d9d7e2', '#2b2a34')}
    <rect x="0" y="86" width="480" height="20" fill="#1d6a45"/>${R(12, i => `<rect x="${14 + i * 39}" y="92" width="8" height="5" fill="#0e0d12"/>`)}
    <rect x="0" y="106" width="480" height="14" fill="#1d6a45"/>${R(60, i => i === 34 ? '' : `<rect x="${6 + i * 7.8}" y="107" width="5" height="13" fill="#e0b043"/>`)}`],
  close_ram_slot: [520, 34, `<rect x="0" y="0" width="520" height="34" rx="2" fill="#0b0a10"/><rect x="0" y="0" width="520" height="7" fill="#2a2934"/><rect x="0" y="27" width="520" height="7" fill="#05050a"/>`],
  close_latch: [18, 64, `<rect x="2" y="0" width="14" height="64" rx="3" fill="#d6d4de"/><rect x="2" y="0" width="14" height="12" rx="3" fill="#f2f0f8"/><rect x="9" y="12" width="9" height="10" fill="#d6d4de"/>`],
  close_latch_open: [40, 40, `<path d="M4 38 L30 4 L40 12 L14 40 Z" fill="#d6d4de"/><path d="M26 6 L30 4 L40 12 L36 16 Z" fill="#f2f0f8"/>`],

  // ---- CPU_FAN 4핀 단자: 위에서 본 기판 ----
  close_fan_bg: [602, 244, board(602, 244, 3, silk(250, 96, 'CPU_FAN') + silk(250, 210, 'SYS_FAN1') +
    `<rect x="180" y="185" width="56" height="30" rx="2" fill="#1a1922" stroke="#3a3946" stroke-width="2"/>${R(4, i => `<rect x="${188 + i * 11}" y="196" width="6" height="6" fill="#d9a93a"/>`)}<rect x="180" y="209" width="56" height="6" fill="#3a3946"/>`)],
  close_fan_header: [80, 44, `<rect x="0" y="0" width="80" height="44" rx="2" fill="#1a1922" stroke="#454452" stroke-width="3"/><rect x="0" y="34" width="80" height="10" fill="#454452"/>
    ${R(4, i => `<rect x="${10 + i * 17}" y="13" width="9" height="9" fill="#e0b043"/><rect x="${12 + i * 17}" y="15" width="5" height="5" fill="#fff1b8"/>`)}`],
  close_fan_plug: [96, 56, `<rect x="0" y="0" width="96" height="40" rx="3" fill="#121117"/><rect x="0" y="0" width="96" height="6" fill="#2c2b36"/>
    <rect x="62" y="40" width="10" height="8" fill="#121117"/>${R(4, i => `<rect x="${12 + i * 20}" y="12" width="10" height="16" fill="#26252f"/>`)}`],

  // ---- 그래픽카드 8핀 전원: 옆에서 본 카드 윗면 ----
  close_gpu_bg: [602, 244, `<rect width="602" height="244" fill="#0f0e15"/>
    <rect x="20" y="118" width="562" height="10" fill="#1d1c24"/>${R(30, i => `<rect x="${24 + i * 18}" y="120" width="8" height="4" fill="#3a3946"/>`)}
    <path d="M10 128 L592 128 L592 244 L10 244 Z" fill="#2a2933"/><path d="M10 128 L592 128 L592 138 L10 138 Z" fill="#3c3b48"/>
    <rect x="10" y="140" width="582" height="4" fill="#7b5cff" opacity=".7"/>
    <circle cx="150" cy="250" r="96" fill="#1a1922"/><circle cx="450" cy="250" r="96" fill="#1a1922"/>
    ${[150, 450].map(c => R(7, i => `<path d="M${c} 250 Q${c + Math.cos(i * .9 + 3.4) * 60} ${250 + Math.sin(i * .9 + 3.4) * 60} ${c + Math.cos(i * .9 + 3.9) * 92} ${250 + Math.sin(i * .9 + 3.9) * 92}" stroke="#34333f" stroke-width="10" fill="none"/>`)).join('')}
    <circle cx="150" cy="250" r="96" fill="none" stroke="#3c3b48" stroke-width="5"/><circle cx="450" cy="250" r="96" fill="none" stroke="#3c3b48" stroke-width="5"/>
    <rect x="236" y="90" width="132" height="30" rx="2" fill="#0b0a10"/><rect x="236" y="90" width="132" height="5" fill="#2a2934"/>
    ${silk(40, 112, 'PCIe 8-pin', 12)}`],
  close_gpu_plug: [128, 64, `<rect x="0" y="0" width="128" height="64" rx="3" fill="#141319"/><rect x="0" y="0" width="128" height="7" fill="#2c2b36"/>
    <path d="M52 64 L52 46 L76 46 L76 64 Z" fill="#26252f"/>${R(8, i => `<rect x="${8 + i * 15}" y="14" width="9" height="22" rx="2" fill="#1f1e27"/>`)}`],

  // ---- 방열판: 타워 쿨러를 앞에서 (가로 핀을 층층이, 구리 히트파이프) ----
  close_fins: [292, 244, `<rect width="292" height="244" fill="#0f0e15"/>
    <rect x="36" y="24" width="160" height="206" fill="#2a2a33"/>${R(34, i => `<rect x="36" y="${26 + i * 6}" width="160" height="3" fill="${i % 2 ? '#b8bbc6' : '#a9acb8'}"/>`)}
    ${R(4, i => `<rect x="${60 + i * 34}" y="10" width="12" height="220" fill="#c07a4a"/><rect x="${60 + i * 34}" y="6" width="12" height="10" rx="6" fill="#d89466"/><rect x="${62 + i * 34}" y="10" width="3" height="220" fill="#e0a77c" opacity=".7"/>`)}
    <rect x="200" y="30" width="78" height="196" rx="6" fill="#16151c"/><rect x="206" y="36" width="66" height="184" rx="4" fill="#0b0a10"/>
    ${R(5, i => `<path d="M239 128 Q${239 + Math.cos(i * 1.25) * 30} ${128 + Math.sin(i * 1.25) * 60} ${239 + Math.cos(i * 1.25 + .5) * 30} ${128 + Math.sin(i * 1.25 + .5) * 86}" stroke="#2c2b36" stroke-width="10" fill="none"/>`)}
    <circle cx="239" cy="128" r="12" fill="#2c2b36"/>`],
  close_dust: [292, 244, (() => { let z = 7; const rnd = () => (z = (z * 16807) % 2147483647) / 2147483647; let o = '';   // 핀 사이 · 팬날에 회색 솜먼지
    for (let i = 0; i < 70; i++) { const x = 40 + rnd() * 156, y = 28 + rnd() * 200; o += `<ellipse cx="${x}" cy="${y}" rx="${4 + rnd() * 10}" ry="${2 + rnd() * 3}" fill="${rnd() < .5 ? '#8e8a84' : '#a39e96'}" opacity=".85"/>`; }
    for (let i = 0; i < 26; i++) { const x = 210 + rnd() * 60, y = 40 + rnd() * 176; o += `<circle cx="${x}" cy="${y}" r="${3 + rnd() * 6}" fill="#9a958e" opacity=".8"/>`; }
    for (let i = 0; i < 24; i++) { const x = 40 + rnd() * 150, y = 30 + rnd() * 190; o += `<path d="M${x} ${y} q4 -5 9 0 q5 5 9 0" stroke="#c4bfb6" stroke-width="2" fill="none" opacity=".7"/>`; }
    return o; })()],
  // ---- 콘덴서: 기판 위 원통 (윗면 K자 홈) ----
  close_cap_bg: [282, 244, board(282, 244, 7, silk(16, 232, 'EC12  EC13  EC14', 12) +
    `<rect x="190" y="18" width="64" height="54" rx="3" fill="#3a3a44"/><rect x="196" y="24" width="52" height="42" fill="#4c4c58"/>${silk(204, 50, 'R22', 13)}`)],
  close_cap: [56, 120, `<rect x="2" y="16" width="52" height="98" fill="#22213a"/><rect x="2" y="16" width="8" height="98" fill="#2e2c4c"/><rect x="40" y="16" width="10" height="98" fill="#bfb6e8"/>
    <ellipse cx="28" cy="114" rx="26" ry="6" fill="#1a1930"/><ellipse cx="28" cy="16" rx="26" ry="10" fill="#b9bcc8"/><ellipse cx="28" cy="16" rx="22" ry="8" fill="#a3a6b3"/>
    <path d="M28 9 L28 23 M16 12 L28 16 L40 12 M28 16 L22 22 M28 16 L34 22" stroke="#7d8090" stroke-width="2.5" fill="none"/>`],
  close_cap_bulge: [56, 120, `<rect x="2" y="16" width="52" height="98" fill="#22213a"/><rect x="2" y="16" width="8" height="98" fill="#2e2c4c"/><rect x="40" y="16" width="10" height="98" fill="#bfb6e8"/>
    <ellipse cx="28" cy="114" rx="26" ry="6" fill="#1a1930"/><path d="M2 18 Q28 -10 54 18 Q28 28 2 18 Z" fill="#c7cad6"/><path d="M10 14 Q22 2 34 6" stroke="#eef0f6" stroke-width="3" fill="none"/>
    <path d="M18 8 Q28 4 40 10 Q34 18 24 16 Z" fill="#7a4a22"/><path d="M40 12 Q48 30 44 40" stroke="#6a3e1c" stroke-width="4" fill="none"/>`],

  // ===== 보드 위쪽 (2쪽) =====
  // CPU 8핀 보조전원(EPS): 보드 왼쪽 위, VRM 방열판 옆
  close_eps_bg: [602, 244, board(602, 244, 11, `<rect x="20" y="20" width="250" height="70" rx="4" fill="#2c2b36"/>${R(16, i => `<rect x="${26 + i * 15}" y="24" width="8" height="62" fill="#3c3b48"/>`)}
    <rect x="300" y="110" width="116" height="62" rx="2" fill="#141319" stroke="#454452" stroke-width="3"/>${R(8, i => `<rect x="${312 + (i % 4) * 26}" y="${122 + Math.floor(i / 4) * 26}" width="16" height="14" rx="${i % 2 ? 2 : 6}" fill="#0b0a10"/>`)}
    ${silk(300, 196, 'CPU_PWR1 (ATX12V 8PIN)')}${silk(24, 112, 'VRM')}`)],
  close_eps_plug: [120, 72, `<rect x="0" y="0" width="120" height="72" rx="3" fill="#121117"/><rect x="0" y="0" width="120" height="7" fill="#2c2b36"/>
    <rect x="46" y="-0" width="28" height="12" fill="#26252f"/>${R(8, i => `<rect x="${12 + (i % 4) * 26}" y="${20 + Math.floor(i / 4) * 24}" width="16" height="14" fill="#1f1e27"/>`)}`],
  // 프런트 패널 핀 (F_PANEL): 2x5 핀 + 실크 글씨
  close_fp_bg: [602, 244, board(602, 244, 5, `<rect x="200" y="80" width="170" height="70" rx="2" fill="#1a1922" stroke="#454452" stroke-width="2"/>
    ${R(10, i => i === 9 ? '' : `<rect x="${214 + (i % 5) * 32}" y="${92 + Math.floor(i / 5) * 32}" width="12" height="12" fill="#e0b043"/>`)}
    ${silk(200, 72, 'PLED+ PLED-  PWR_SW', 12)}${silk(200, 172, 'HDD+  HDD-   RESET', 12)}${silk(200, 214, 'F_PANEL', 14)}`)],
  close_fp_plug: [70, 36, `<rect x="0" y="0" width="70" height="36" rx="2" fill="#121117"/><rect x="0" y="0" width="70" height="5" fill="#2c2b36"/>
    <text x="35" y="25" text-anchor="middle" font-family="monospace" font-weight="700" font-size="11" fill="#e8e6f0">POWER SW</text>`],
  // RAM 슬롯 배치 (위에서): A1 A2 B1 B2
  close_dimm_bg: [602, 244, board(602, 244, 9, R(4, i => `<rect x="${150 + i * 80}" y="20" width="22" height="200" rx="2" fill="#0b0a10" stroke="#2c2b36" stroke-width="2"/>
    <rect x="${148 + i * 80}" y="14" width="26" height="10" fill="#d6d4de"/><rect x="${148 + i * 80}" y="216" width="26" height="10" fill="#d6d4de"/>`) +
    silk(146, 240, 'A1      A2      B1      B2', 13) + silk(470, 60, '2 DIMMs:', 13) + silk(470, 80, 'A2 + B2', 13) + silk(470, 100, 'FIRST', 13))],
  close_dimm_stick: [30, 196, `<rect x="0" y="0" width="30" height="196" rx="2" fill="#2b2a34"/><rect x="0" y="0" width="30" height="196" rx="2" fill="none" stroke="#4a4858" stroke-width="3"/>
    <rect x="12" y="10" width="6" height="176" fill="#c2364f"/>`],
  // CMOS 배터리 (CR2032)
  close_cmos_bg: [602, 244, board(602, 244, 13, `<circle cx="200" cy="122" r="74" fill="#1a1922" stroke="#454452" stroke-width="3"/><rect x="186" y="40" width="28" height="18" fill="#8a8f9c"/>${silk(140, 222, 'BAT1  CR2032')}`)],
  close_cmos: [124, 124, `<circle cx="62" cy="62" r="60" fill="#b9bcc8"/><circle cx="62" cy="62" r="52" fill="#cfd2dc"/><circle cx="50" cy="48" r="20" fill="#e6e8ef" opacity=".7"/>
    <text x="62" y="58" text-anchor="middle" font-family="monospace" font-weight="700" font-size="15" fill="#5a5d6a">CR2032</text><text x="62" y="80" text-anchor="middle" font-family="monospace" font-weight="700" font-size="15" fill="#5a5d6a">3V  +</text>`],
};
(async () => {
  for (const [name, [w, h, body]] of Object.entries(S)) {
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">${body}</svg>`;
    const small = await sharp(Buffer.from(svg)).resize(Math.ceil(w / 2), Math.ceil(h / 2), { kernel: 'nearest' }).png().toBuffer();
    await sharp(small).resize(w, h, { kernel: 'nearest' }).png().toFile(path.join(OUT, name + '.png'));
  }
  console.log(Object.keys(S).length, 'close sprites');
})();
