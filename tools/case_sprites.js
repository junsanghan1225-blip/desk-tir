// 책상 위 본체 옆모습(196x210): side_<케이스>.png. 유리창 자리는 투명 → Godot가 그 밑에 실제 조립 부품을 그림.
// 유리창 = x 10~154, y 12~196 (desk.gd SIDE_WIN과 같음). 앞면(오른쪽 x 158~196)에 전원 버튼 · USB.  실행: node tools/case_sprites.js
const sharp = require('sharp'), path = require('path');
const OUT = path.join(__dirname, '..', 'resource');
const W = 196, H = 210;
// [몸통, 밝은 면, 어두운 면, 앞면 무늬, 옆판(glass|solid|vent), 다리]
const CASES = {
  case1: ['#2a2350', '#3e3570', '#1a1534', 'plain', 'glass'],
  case2: ['#e6e4f0', '#ffffff', '#b9b6cc', 'plain', 'glass'],
  case3: ['#16112c', '#2a2350', '#0b0818', 'rgb', 'glass'],
  case4: ['#e6e4f0', '#ffffff', '#b9b6cc', 'glassfront', 'glass'],
  case5: ['#2a2350', '#3e3570', '#1a1534', 'wood', 'glass'],
  case6: ['#3a3a48', '#55556a', '#26262f', 'plain', 'vent'],
  case7: ['#14121c', '#2a2836', '#0a0910', 'mesh', 'glass'],
  case8: ['#2a2836', '#3e3c50', '#1a1824', 'plain', 'solid'],
};
const svg = ([b, hi, lo, front, side]) => {
  let s = `<defs><mask id="win"><rect width="${W}" height="${H}" fill="#fff"/>${side === 'glass' ? `<rect x="10" y="12" width="144" height="184" rx="3" fill="#000"/>` : ''}</mask>
    <linearGradient id="rgb" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ff4d8d"/><stop offset=".5" stop-color="#7b5cff"/><stop offset="1" stop-color="#2ee6d6"/></linearGradient></defs>`;
  s += `<rect x="16" y="202" width="26" height="8" rx="2" fill="#0a0814"/><rect x="146" y="202" width="26" height="8" rx="2" fill="#0a0814"/>`;   // 다리
  s += `<g mask="url(#win)"><rect x="0" y="0" width="${W}" height="204" rx="4" fill="${b}"/>
    <rect x="0" y="0" width="${W}" height="3" rx="2" fill="${hi}"/><rect x="0" y="200" width="${W}" height="4" fill="${lo}"/>
    <rect x="0" y="0" width="4" height="204" fill="${lo}"/>`;
  if (side === 'glass') s += `<rect x="7" y="9" width="150" height="190" rx="5" fill="none" stroke="${lo}" stroke-width="5"/>${[[14, 16], [150, 16], [14, 192], [150, 192]].map(([x, y]) => `<circle cx="${x}" cy="${y}" r="2.5" fill="${hi}"/>`).join('')}`;
  if (side === 'vent') s += `<rect x="12" y="14" width="140" height="184" rx="3" fill="${hi}" opacity=".25"/>${[...Array(8)].map((_, r) => [...Array(10)].map((_, c) => `<rect x="${30 + c * 10}" y="${30 + r * 9}" width="6" height="4" rx="1" fill="${lo}"/>`).join('')).join('')}`;
  if (side === 'solid') s += `<rect x="12" y="14" width="140" height="184" rx="3" fill="${hi}" opacity=".18"/><rect x="12" y="14" width="140" height="3" fill="${hi}" opacity=".5"/>`;
  s += `</g>`;
  // 윗면 통풍구
  s += [...Array(12)].map((_, i) => `<rect x="${14 + i * 11}" y="3" width="7" height="3" fill="${lo}"/>`).join('');
  // 앞면 (오른쪽 끝)
  s += `<rect x="158" y="0" width="38" height="204" rx="3" fill="${lo}"/><rect x="160" y="2" width="34" height="200" rx="2" fill="${b}"/>`;
  if (front === 'rgb') s += `<rect x="164" y="40" width="4" height="150" fill="url(#rgb)"/><rect x="186" y="40" width="4" height="150" fill="url(#rgb)" opacity=".6"/>`;
  if (front === 'mesh') s += [...Array(18)].map((_, r) => [...Array(3)].map((_, c) => `<circle cx="${168 + c * 9 + (r % 2) * 4}" cy="${46 + r * 8.5}" r="2.2" fill="#000"/>`).join('')).join('');
  if (front === 'wood') s += `<rect x="162" y="38" width="30" height="160" fill="#8b5e3c"/>${[0, 1, 2, 3, 4].map(i => `<rect x="${164 + i * 6}" y="40" width="2" height="156" fill="#a8774f"/>`).join('')}`;
  if (front === 'glassfront') s += `<rect x="162" y="38" width="30" height="160" fill="#9fe9ff" opacity=".25"/><rect x="164" y="40" width="3" height="156" fill="#fff" opacity=".4"/>`;
  // 전원 버튼(테두리만, 불빛은 코드) + 리셋 + USB · 오디오
  s += `<circle cx="175" cy="23" r="9" fill="#0a0814"/><circle cx="175" cy="23" r="7" fill="${hi}"/><circle cx="175" cy="23" r="4" fill="#0a0814"/>`;
  s += `<rect x="168" y="40" width="14" height="5" rx="1" fill="#0a0814"/><rect x="170" y="41" width="10" height="2" fill="#1f5bd1"/>`;
  s += `<rect x="168" y="49" width="14" height="5" rx="1" fill="#0a0814"/><rect x="170" y="50" width="10" height="2" fill="#1f5bd1"/>`;
  s += `<circle cx="186" cy="44" r="2.5" fill="#0a0814"/><circle cx="186" cy="52" r="2.5" fill="#0a0814"/>`;
  return s;
};
// ---- 정면(앞면) 100x210: 책상 위에서 보이는 모습. 전원 버튼 (50, 20) · 앞 팬 자리 3개 (50, 70/115/160)
const FW = 100;
const frontSvg = ([b, hi, lo, front, side], id) => {
  let s = `<defs><linearGradient id="rgb" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ff4d8d"/><stop offset=".5" stop-color="#7b5cff"/><stop offset="1" stop-color="#2ee6d6"/></linearGradient></defs>`;
  s += `<rect x="8" y="202" width="22" height="8" rx="2" fill="#0a0814"/><rect x="70" y="202" width="22" height="8" rx="2" fill="#0a0814"/>`;
  s += `<rect x="0" y="0" width="${FW}" height="204" rx="5" fill="${lo}"/><rect x="3" y="2" width="${FW - 6}" height="199" rx="4" fill="${b}"/><rect x="3" y="2" width="${FW - 6}" height="3" fill="${hi}"/>`;
  const panel = [10, 44, 80, 150];   // 앞판 가운데
  if (front === 'mesh') s += `<rect x="${panel[0]}" y="${panel[1]}" width="${panel[2]}" height="${panel[3]}" fill="#0a0910"/>` + [...Array(19)].map((_, r) => [...Array(9)].map((_, c) => `<circle cx="${14 + c * 9 + (r % 2) * 4}" cy="${48 + r * 7.8}" r="2.6" fill="#22202e"/>`).join('')).join('');
  if (front === 'rgb') s += `<rect x="${panel[0]}" y="${panel[1]}" width="${panel[2]}" height="${panel[3]}" fill="#0b0818"/><rect x="${panel[0]}" y="${panel[1]}" width="${panel[2]}" height="${panel[3]}" fill="#7b5cff" opacity=".12"/><rect x="6" y="40" width="4" height="158" fill="url(#rgb)"/><rect x="90" y="40" width="4" height="158" fill="url(#rgb)"/>`;
  if (front === 'glassfront') s += `<rect x="${panel[0]}" y="${panel[1]}" width="${panel[2]}" height="${panel[3]}" fill="#16122c"/><rect x="${panel[0]}" y="${panel[1]}" width="${panel[2]}" height="${panel[3]}" fill="#9fe9ff" opacity=".12"/><path d="M14 190 L40 48" stroke="#fff" stroke-width="3" opacity=".18"/>`;
  if (front === 'wood') s += `<rect x="${panel[0]}" y="${panel[1]}" width="${panel[2]}" height="${panel[3]}" fill="#8b5e3c"/>` + [...Array(8)].map((_, i) => `<rect x="${12 + i * 10}" y="46" width="5" height="146" fill="#a8774f"/>`).join('');
  if (front === 'plain' && side === 'vent') s += `<rect x="14" y="46" width="72" height="10" rx="1" fill="${lo}"/><rect x="16" y="50" width="20" height="2" fill="${hi}"/><circle cx="78" cy="51" r="2" fill="${hi}"/>` + [...Array(6)].map((_, r) => [...Array(7)].map((_, c) => `<rect x="${17 + c * 10}" y="${150 + r * 8}" width="6" height="4" rx="1" fill="${lo}"/>`).join('')).join('');   // 사무용: 광드라이브 자리 + 아래 통풍구
  else if (front === 'plain') s += `<rect x="${panel[0]}" y="${panel[1]}" width="${panel[2]}" height="${panel[3]}" fill="${hi}" opacity=".15"/><rect x="${FW / 2 - 1}" y="60" width="2" height="120" fill="${lo}" opacity=".6"/><rect x="38" y="186" width="24" height="3" fill="${lo}"/>`;
  // 위쪽 버튼 · 단자
  s += `<rect x="10" y="10" width="80" height="28" rx="3" fill="${lo}" opacity=".55"/>`;
  s += `<circle cx="50" cy="20" r="8" fill="#0a0814"/><circle cx="50" cy="20" r="6" fill="${hi}"/><circle cx="50" cy="20" r="3.5" fill="#0a0814"/>`;
  s += `<rect x="16" y="15" width="16" height="6" rx="1" fill="#0a0814"/><rect x="18" y="17" width="12" height="2" fill="#1f5bd1"/><rect x="16" y="26" width="16" height="6" rx="1" fill="#0a0814"/><rect x="18" y="28" width="12" height="2" fill="#1f5bd1"/>`;
  s += `<circle cx="74" cy="18" r="3" fill="#0a0814"/><circle cx="74" cy="18" r="1.4" fill="#56b08a"/><circle cx="84" cy="18" r="3" fill="#0a0814"/><circle cx="84" cy="18" r="1.4" fill="#ff8fb4"/>`;
  s += `<rect x="66" y="27" width="22" height="4" rx="2" fill="#0a0814"/>`;   // HDD LED 자리
  return s;
};

(async () => {
  for (const [id, pal] of Object.entries(CASES)) {
    const fb = `<svg xmlns="http://www.w3.org/2000/svg" width="${FW}" height="${H}" viewBox="0 0 ${FW} ${H}">${frontSvg(pal, id)}</svg>`;
    const fs = await sharp(Buffer.from(fb)).resize(FW / 2, H / 2, { kernel: 'nearest' }).png().toBuffer();
    await sharp(fs).resize(FW, H, { kernel: 'nearest' }).png().toFile(path.join(OUT, `front_${id}.png`));
    const body = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${svg(pal)}</svg>`;
    const small = await sharp(Buffer.from(body)).resize(W / 2, H / 2, { kernel: 'nearest' }).png().toBuffer();
    await sharp(small).resize(W, H, { kernel: 'nearest' }).png().toFile(path.join(OUT, `side_${id}.png`));
  }
  console.log(Object.keys(CASES).length, 'case side sprites');
})();
