// 케이스 안 조립 화면용 실사풍 부품 그림. build_mode.py의 좌표(보드 기준)와 1:1로 맞춘다.
// 보드 좌표: 위가 0인 SVG 좌표. ATX 460x364, mATX 370x300.
module.exports = (S, h) => {
  const { glow, RGB } = h;
  const board = (W, H, pcb, trace, heat, accent, slots) => {
    const ram = [...Array(slots)].map((_, i) => {
      const x = 214 + i * 26;
      return `<rect x="${x - 3}" y="20" width="20" height="180" rx="2" fill="#1a1a22"/><rect x="${x}" y="24" width="14" height="172" fill="#0c0c12"/>
        <rect x="${x - 2}" y="18" width="18" height="6" fill="#d8d8e0"/><rect x="${x - 2}" y="196" width="18" height="6" fill="#d8d8e0"/>`;
    }).join('');
    return [W, H, `<rect width="${W}" height="${H}" rx="6" fill="${pcb}"/>
      ${[...Array(18)].map((_, i) => `<path d="M${(i * 53) % W} ${(i * 37) % H} h${30 + (i * 7) % 60} v${(i % 3 - 1) * 24} h${20 + i % 5 * 8}" stroke="${trace}" stroke-width="1.4" fill="none"/>`).join('')}
      ${[...Array(40)].map((_, i) => `<rect x="${(i * 89) % (W - 6)}" y="${(i * 61) % (H - 6)}" width="3" height="2" fill="${trace}"/>`).join('')}
      <rect x="0" y="0" width="54" height="120" fill="${heat}"/>${[...Array(9)].map((_, i) => `<rect x="4" y="${6 + i * 12}" width="46" height="5" fill="${accent}" opacity=".5"/>`).join('')}
      <rect x="60" y="0" width="120" height="40" fill="${heat}"/>${[...Array(10)].map((_, i) => `<rect x="${64 + i * 11}" y="4" width="5" height="32" fill="${accent}" opacity=".5"/>`).join('')}
      <rect x="54" y="44" width="112" height="112" fill="#0c0c12"/><rect x="60" y="50" width="100" height="100" fill="#2a2a34"/>
      ${[...Array(12)].map((_, r) => [...Array(12)].map((_, c) => `<rect x="${64 + c * 8}" y="${54 + r * 8}" width="2" height="2" fill="#b89a4a"/>`).join('')).join('')}
      <rect x="28" y="48" width="20" height="104" fill="#0c0c12"/>
      ${ram}
      <rect x="16" y="10" width="74" height="20" fill="#111118"/>${[...Array(8)].map((_, i) => `<rect x="${20 + i * 9}" y="14" width="6" height="12" fill="#2a2a34"/>`).join('')}
      <rect x="${W - 30}" y="40" width="20" height="110" fill="#111118"/>${[...Array(12)].map((_, i) => `<rect x="${W - 27}" y="${44 + i * 9}" width="14" height="6" fill="#2a2a34"/>`).join('')}
      <rect x="20" y="${H - 70}" width="${W - 60}" height="14" fill="#14141c"/><rect x="24" y="${H - 66}" width="${W - 68}" height="6" fill="#050508"/><rect x="${W - 54}" y="${H - 72}" width="10" height="18" fill="#d8d8e0"/>
      <rect x="60" y="${H - 104}" width="130" height="16" rx="2" fill="#0c0c12"/><rect x="186" y="${H - 100}" width="6" height="8" fill="#d8d8e0"/>
      <rect x="${W - 60}" y="${H - 130}" width="48" height="20" fill="#111118"/>${[...Array(5)].map((_, i) => `<rect x="${W - 56 + i * 9}" y="${H - 126}" width="4" height="4" fill="#d8b84a"/><rect x="${W - 56 + i * 9}" y="${H - 118}" width="4" height="4" fill="#d8b84a"/>`).join('')}
      <rect x="${W - 150}" y="${H - 150}" width="64" height="56" rx="4" fill="${heat}"/><rect x="${W - 140}" y="${H - 140}" width="44" height="36" rx="3" fill="${accent}" opacity=".35"/>
      ${[...Array(6)].map((_, i) => `<circle cx="${70 + i * 18}" cy="170" r="5" fill="#2a2a34"/><circle cx="${70 + i * 18}" cy="170" r="2" fill="#8a8a96"/>`).join('')}
      <circle cx="10" cy="10" r="4" fill="#8a8a96"/><circle cx="${W - 10}" cy="10" r="4" fill="#8a8a96"/><circle cx="10" cy="${H - 10}" r="4" fill="#8a8a96"/><circle cx="${W - 10}" cy="${H - 10}" r="4" fill="#8a8a96"/>`];
  };
  const DARK = ['#14323a', '#1f4a54', '#2a2a34', '#5a5a66'];
  S.inb_mb1 = board(370, 300, DARK[0], DARK[1], DARK[2], '#ff4d8d', 2);
  S.inb_mb2 = board(370, 300, DARK[0], DARK[1], DARK[2], '#2ee6d6', 2);
  S.inb_mb3 = board(460, 364, '#16161e', '#2a2a3a', '#3a3a48', '#7b5cff', 4);
  S.inb_mb4 = board(460, 364, '#16161e', '#2a2a3a', '#3a3a48', '#ff4d8d', 4);
  S.inb_mb5 = board(460, 364, '#dcdbe6', '#c4c2d2', '#f4f4fa', '#9aa0b4', 4);

  S.inb_cpu = [100, 100, `<rect width="100" height="100" fill="#1f6b3a"/><rect x="8" y="8" width="84" height="84" rx="3" fill="#c8ccd6"/>
    <rect x="8" y="8" width="84" height="84" rx="3" fill="url(#ih)"/><defs><linearGradient id="ih" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".5"/><stop offset=".5" stop-color="#fff" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity=".2"/></linearGradient></defs>
    <rect x="22" y="40" width="56" height="5" fill="#8a8e9a"/><rect x="28" y="52" width="44" height="4" fill="#8a8e9a"/><path d="M8 92 L16 92 L8 84 Z" fill="#d8b84a"/>`];
  S.inb_paste = [100, 100, `<path d="M50 22 Q72 24 78 50 Q76 76 50 78 Q24 76 22 50 Q26 26 50 22 Z" fill="#b8bcc6"/><path d="M40 36 Q52 32 60 40" stroke="#e8eaf0" stroke-width="4" fill="none"/>`];
  const fan = (cx, cy, r, blade, hub, ring) => `<circle cx="${cx}" cy="${cy}" r="${r}" fill="#0c0c12"/>${[...Array(7)].map((_, i) => `<path d="M${cx} ${cy} Q${cx + r * 0.9 * Math.cos(i * 0.9)} ${cy + r * 0.9 * Math.sin(i * 0.9)} ${cx + r * 0.8 * Math.cos(i * 0.9 + 0.7)} ${cy + r * 0.8 * Math.sin(i * 0.9 + 0.7)} Z" fill="${blade}"/>`).join('')}
    <circle cx="${cx}" cy="${cy}" r="${r * 0.28}" fill="${hub}"/><circle cx="${cx}" cy="${cy}" r="${r}" fill="none" stroke="${ring}" stroke-width="${Math.max(2, r * 0.06)}"/>`;
  S.inb_cool1 = [136, 136, `<rect x="18" y="18" width="100" height="100" rx="10" fill="#2a2a34"/>${fan(68, 68, 46, '#3a3a46', '#5a5a66', '#1a1a22')}<text x="68" y="73" font-size="11" fill="#c8ccd6" text-anchor="middle" font-family="monospace">STOCK</text>`];
  S.inb_cool2 = [136, 136, `<rect x="4" y="10" width="128" height="116" rx="4" fill="#9aa0ac"/>${[...Array(24)].map((_, i) => `<rect x="6" y="${12 + i * 4.6}" width="124" height="2" fill="#6e7480"/>`).join('')}
    ${[30, 54, 82, 106].map(x => `<rect x="${x}" y="6" width="6" height="124" rx="3" fill="#c88a4a"/>`).join('')}<rect x="44" y="0" width="48" height="136" rx="4" fill="#14141c"/>${fan(68, 68, 22, '#2a2a3a', '#ff4d8d', '#ff4d8d')}`];
  S.inb_cool3 = [136, 136, `<defs>${RGB('wb')}${glow('wg', 4)}</defs><path d="M110 40 Q132 40 132 0 M110 96 Q136 96 136 0" stroke="#14141c" stroke-width="10" fill="none"/>
    <circle cx="68" cy="68" r="52" fill="#14141c"/><circle cx="68" cy="68" r="44" fill="none" stroke="url(#wb)" stroke-width="6" filter="url(#wg)"/><circle cx="68" cy="68" r="44" fill="none" stroke="url(#wb)" stroke-width="3"/>
    <circle cx="68" cy="68" r="30" fill="#1f1f2a"/><text x="68" y="74" font-size="16" fill="#2ee6d6" text-anchor="middle" font-family="monospace">42°</text>`];
  const stick = (body, top, chips) => [28, 344, `<rect x="4" y="0" width="20" height="344" fill="#1f6b3a"/>${[...Array(8)].map((_, i) => `<rect x="7" y="${14 + i * 40}" width="14" height="28" fill="#111"/>`).join('')}
    <rect x="0" y="6" width="28" height="332" rx="3" fill="${body}"/><rect x="0" y="6" width="6" height="332" fill="${top}"/>${chips}
    <rect x="4" y="338" width="20" height="6" fill="#d8b84a"/>`];
  S.inb_ram1 = stick('#2a7a4a', '#3c9a62', '');
  S.inb_ram2 = stick('#2a2a34', '#ff4d8d', `<rect x="10" y="140" width="10" height="60" fill="#3a3a46"/>`);
  S.inb_ram3 = stick('#3a2d6e', '#c9b8ff', `<rect x="10" y="120" width="10" height="100" fill="#7b5cff"/>`);
  S.inb_ram4 = [28, 344, `<defs>${RGB('rr', 1)}${glow('rg', 3)}</defs><rect x="0" y="6" width="28" height="332" rx="3" fill="#14141c"/><rect x="0" y="6" width="8" height="332" fill="url(#rr)" filter="url(#rg)"/><rect x="0" y="6" width="6" height="332" fill="url(#rr)"/><rect x="4" y="338" width="20" height="6" fill="#d8b84a"/>`];
  S.inb_ssd = [130, 16, `<rect width="130" height="16" rx="2" fill="#1f6b3a"/><rect x="8" y="3" width="30" height="10" fill="#111"/><rect x="44" y="3" width="30" height="10" fill="#111"/><rect x="80" y="4" width="16" height="8" fill="#2a2a34"/>
    <rect x="0" y="2" width="6" height="12" fill="#d8b84a"/><rect x="104" y="1" width="26" height="14" rx="2" fill="#3a3a46"/><text x="117" y="11" font-size="7" fill="#2ee6d6" text-anchor="middle" font-family="monospace">NVMe</text>`];
  const gpu = (len, shroud, accent, fans, white) => {
    const W = Math.round(len * 1.25), r = 22;
    const gap = (W - 30) / fans;
    return [W, 60, `<rect x="0" y="0" width="${W}" height="56" rx="6" fill="${shroud}"/><rect x="0" y="52" width="${W}" height="8" fill="#1f6b3a"/>
      ${[...Array(Math.floor(W / 14))].map((_, i) => `<rect x="${8 + i * 14}" y="56" width="8" height="4" fill="#d8b84a"/>`).join('')}
      <rect x="0" y="0" width="${W}" height="6" fill="${accent}"/>${[...Array(fans)].map((_, i) => fan(15 + gap * (i + 0.5), 29, r, white ? '#c8ccd6' : '#2a2a3a', accent, white ? '#f4f4fa' : '#0c0c12')).join('')}
      <rect x="${W - 12}" y="8" width="8" height="40" fill="${accent}" opacity=".6"/>`];
  };
  S.inb_gpu1 = gpu(180, '#2a2a34', '#8a8e9a', 1);
  S.inb_gpu4 = gpu(200, '#2a2a34', '#2ee6d6', 2);
  S.inb_gpu2 = gpu(280, '#1c1c26', '#7b5cff', 2);
  S.inb_gpu5 = gpu(300, '#e8e6f2', '#c9b8ff', 2, true);
  S.inb_gpu3 = gpu(340, '#14141c', '#ff4d8d', 3);
  S.inb_gpu6 = gpu(360, '#0c0c12', '#ffd65c', 3);
  const psu = (body, label) => [214, 112, `<rect width="214" height="112" rx="4" fill="${body}"/><rect x="0" y="0" width="214" height="8" fill="#000" opacity=".25"/>
    <circle cx="70" cy="56" r="44" fill="#0c0c12"/>${[...Array(8)].map((_, i) => `<circle cx="70" cy="56" r="${6 + i * 5}" fill="none" stroke="${body}" stroke-width="1.5"/>`).join('')}
    <path d="M26 56 L114 56 M70 12 L70 100" stroke="${body}" stroke-width="2"/><rect x="128" y="34" width="70" height="44" rx="3" fill="#000" opacity=".25"/><text x="163" y="61" font-size="12" fill="#c8ccd6" text-anchor="middle" font-family="monospace">${label}</text>`];
  S.inb_casefan = [80, 80, `<rect width="80" height="80" rx="8" fill="#1a1a22"/>${fan(40, 40, 34, '#2a2a3a', '#3a3a46', '#0c0c12')}${[[6, 6], [74, 6], [6, 74], [74, 74]].map(([x, y]) => `<circle cx="${x}" cy="${y}" r="3" fill="#5a5a66"/>`).join('')}`];
  S.inb_psu = psu('#2a2a34', 'PSU');
  S.inb_psu_white = psu('#dcdbe6', 'PSU');
};
