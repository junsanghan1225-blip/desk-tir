// 손님 초상화(표정 3종) · 날씨별 방 배경. make_sprites.js가 불러서 S에 더한다.
// 초상화는 게임과 같은 분위기: 어두운 밤 도시 배경 + 네온 링 + 양쪽 네온 조명(시안 · 핑크) + 굵은 도트.
module.exports = (S, h) => {
  const { city, stars } = h;
  const INK = '#120a26', CYAN = '#2ee6d6', PINK = '#ff4d8d';

  const hairs = {
    short: c => `<path d="M75 130 Q70 50 140 50 Q210 50 205 130 Q190 95 140 95 Q90 95 75 130 Z" fill="${c}"/>`,
    long: c => `<rect x="65" y="100" width="30" height="135" fill="${c}"/><rect x="185" y="100" width="30" height="135" fill="${c}"/>${hairs.short(c)}`,
    bob: c => `<rect x="65" y="100" width="25" height="80" fill="${c}"/><rect x="190" y="100" width="25" height="80" fill="${c}"/>${hairs.short(c)}`,
    bun: c => `<rect x="120" y="20" width="40" height="40" rx="10" fill="${c}"/>${hairs.short(c)}`,
    spiky: c => `<path d="M75 125 L85 55 L105 85 L115 40 L135 80 L155 35 L170 80 L195 55 L205 125 Q190 95 140 95 Q90 95 75 125 Z" fill="${c}"/>`,
    beanie: c => `<path d="M75 115 Q75 40 140 40 Q205 40 205 115 Z" fill="${c}"/><rect x="70" y="100" width="140" height="20" fill="#fff" opacity=".3"/><rect x="130" y="25" width="20" height="20" fill="${c}"/>`,
    side: c => `<path d="M75 130 Q70 50 140 50 Q210 50 205 130 Q195 100 170 95 Q120 110 75 130 Z" fill="${c}"/>`,
  };
  const accs = {
    glasses: c => `<rect x="95" y="125" width="40" height="30" fill="${c}" fill-opacity=".25" stroke="${INK}" stroke-width="5"/><rect x="145" y="125" width="40" height="30" fill="${c}" fill-opacity=".25" stroke="${INK}" stroke-width="5"/><rect x="135" y="135" width="10" height="5" fill="${INK}"/>`,
    visor: c => `<rect x="85" y="122" width="110" height="26" fill="${c}" opacity=".85"/><rect x="85" y="122" width="110" height="6" fill="#fff" opacity=".5"/>`,
    headset: c => `<path d="M72 140 Q72 38 140 38 Q208 38 208 140" stroke="${INK}" stroke-width="12" fill="none"/><rect x="58" y="115" width="26" height="52" fill="${c}"/><rect x="196" y="115" width="26" height="52" fill="${c}"/><path d="M72 167 Q80 198 120 192" stroke="${INK}" stroke-width="6" fill="none"/><rect x="115" y="186" width="12" height="10" fill="${c}"/>`,
    beard: () => `<path d="M92 165 Q98 216 140 216 Q182 216 188 165 Q172 186 140 186 Q108 186 92 165 Z" fill="#d8d4ec"/>`,
    leaf: () => `<path d="M175 60 Q200 36 216 58 Q198 80 175 60 Z" fill="#5ff0a8"/>`,
    cap: c => `<path d="M75 105 Q75 44 140 44 Q205 44 205 105 Z" fill="${c}"/><rect x="55" y="98" width="115" height="14" fill="${c}"/><rect x="75" y="92" width="130" height="6" fill="#fff" opacity=".3"/>`,
  };
  const face = (o, mood, seed) => {
    const neon = o.neon;
    const eyes = mood === 'happy'
      ? `<path d="M105 146 L115 134 L127 146 M153 146 L165 134 L175 146" stroke="${INK}" stroke-width="7" fill="none"/>`
      : `<rect x="108" y="130" width="14" height="20" fill="${INK}"/><rect x="158" y="130" width="14" height="20" fill="${INK}"/><rect x="110" y="132" width="6" height="6" fill="${CYAN}"/><rect x="160" y="132" width="6" height="6" fill="${CYAN}"/>`;
    const brows = mood === 'sad' ? `<path d="M100 126 L128 114 M180 126 L152 114" stroke="${INK}" stroke-width="6"/>` : '';
    const mouth = mood === 'happy' ? `<path d="M116 166 L164 166 L154 186 L126 186 Z" fill="#5a1430"/><rect x="124" y="166" width="32" height="7" fill="#fff"/>`
      : mood === 'sad' ? `<path d="M122 184 L132 172 L148 172 L158 184" stroke="${INK}" stroke-width="6" fill="none"/>`
        : `<rect x="126" y="172" width="28" height="6" fill="${INK}"/>`;
    const extra = mood === 'happy' ? `<rect x="92" y="156" width="18" height="10" fill="${PINK}" opacity=".6"/><rect x="170" y="156" width="18" height="10" fill="${PINK}" opacity=".6"/>`
      : mood === 'sad' ? `<path d="M222 92 L214 112 L222 122 L230 112 Z" fill="#9fe9ff"/>` : '';
    const ring = { happy: '#ffd65c', neutral: neon, sad: '#5a6ab0' }[mood];
    return [280, 300, `<defs><linearGradient id="fbg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#120a26"/><stop offset=".7" stop-color="#3a1d6e"/><stop offset="1" stop-color="#a03a7a"/></linearGradient></defs>
      <rect width="280" height="300" fill="url(#fbg)"/>${stars(280, 110, 12, seed)}
      <g transform="translate(0 150)" opacity=".9">${city(280, 150, seed, 0.9)}</g>
      <circle cx="140" cy="128" r="112" fill="none" stroke="${ring}" stroke-width="10" opacity="${mood === 'sad' ? .5 : .95}"/><circle cx="140" cy="128" r="112" fill="${ring}" opacity=".12"/>
      <path d="M30 300 Q30 232 100 222 L180 222 Q250 232 250 300 Z" fill="${o.cloth}"/>
      <path d="M30 300 Q30 232 100 222 L110 222 Q46 236 46 300 Z" fill="${CYAN}" opacity=".7"/><path d="M250 300 Q250 232 180 222 L170 222 Q234 236 234 300 Z" fill="${PINK}" opacity=".7"/>
      <path d="M108 222 L140 256 L172 222 Z" fill="${neon}"/><rect x="60" y="270" width="160" height="6" fill="${neon}" opacity=".8"/>
      <rect x="120" y="188" width="40" height="40" fill="${o.skin}"/><rect x="120" y="188" width="40" height="16" fill="#3a1d6e" opacity=".45"/>
      ${o.hair === 'long' ? `<rect x="65" y="100" width="150" height="135" fill="${o.hairC}"/>` : ''}
      <rect x="72" y="130" width="14" height="24" fill="${o.skin}"/><rect x="194" y="130" width="14" height="24" fill="${o.skin}"/>
      <rect x="82" y="66" width="116" height="136" rx="40" fill="${INK}"/><rect x="86" y="70" width="108" height="128" rx="36" fill="${o.skin}"/>
      <rect x="86" y="96" width="12" height="80" fill="${CYAN}" opacity=".55"/><rect x="170" y="90" width="24" height="96" rx="10" fill="#7b3aa8" opacity=".35"/><rect x="186" y="100" width="8" height="70" fill="${PINK}" opacity=".6"/>
      ${o.acc === 'beard' ? accs.beard() : ''}${eyes}${brows}${mouth}${extra}
      ${hairs[o.hair](o.hairC)}<path d="M96 76 Q120 58 150 58" stroke="#fff" stroke-width="6" fill="none" opacity=".35"/>
      ${(o.accs || []).map(a => accs[a](a === 'headset' || a === 'cap' || a === 'visor' ? neon : CYAN)).join('')}
      ${[...Array(30)].map((_, i) => `<rect x="0" y="${i * 10}" width="280" height="2" fill="#000" opacity=".1"/>`).join('')}`];
  };
  const PEOPLE = {
    student: { skin: '#f2c9a0', hair: 'short', hairC: '#4a3a8a', cloth: '#1c1438', neon: CYAN },
    office: { skin: '#e8b890', hair: 'side', hairC: '#1c1c3a', cloth: '#2a2350', neon: '#7b5cff', accs: ['glasses'] },
    grad: { skin: '#f2c9a0', hair: 'bun', hairC: '#3a8a6a', cloth: '#143a30', neon: '#5ff0a8', accs: ['leaf'] },
    dev: { skin: '#d8a880', hair: 'beanie', hairC: '#3b3170', cloth: '#14102a', neon: CYAN, accs: ['glasses'] },
    writer: { skin: '#f2c9a0', hair: 'long', hairC: '#a8327a', cloth: '#3a1d4e', neon: '#ffd65c', accs: ['glasses'] },
    grandma: { skin: '#e8c0a0', hair: 'bun', hairC: '#c9c0ec', cloth: '#5a1d4a', neon: PINK, accs: ['glasses'] },
    streamer: { skin: '#f2c9a0', hair: 'bob', hairC: '#ff5ca8', cloth: '#14102a', neon: CYAN, accs: ['headset'] },
    progamer: { skin: '#d8a880', hair: 'spiky', hairC: '#2ee6d6', cloth: '#3a0f2a', neon: PINK, accs: ['headset', 'visor'] },
    designer: { skin: '#f2d0b0', hair: 'bob', hairC: '#e8e6f2', cloth: '#1c1c3a', neon: '#c9b8ff' },
    cafe: { skin: '#d8a880', hair: 'side', hairC: '#5a2a3a', cloth: '#3a2030', neon: '#ffd65c', accs: ['cap'] },
    professor: { skin: '#e8c0a0', hair: 'side', hairC: '#b8b4d8', cloth: '#231c44', neon: '#7b5cff', acc: 'beard', accs: ['glasses'] },
    granddaughter: { skin: '#f2c9a0', hair: 'long', hairC: '#7b5cff', cloth: '#14102a', neon: PINK, accs: ['cap'] },
  };
  Object.entries(PEOPLE).forEach(([id, o], i) => {
    for (const mood of ['happy', 'neutral', 'sad']) S[`face_${id}_${mood}`] = face(o, mood, 7 + i * 13);
  });

  // ---------- 날씨별 방 배경 (room_bg와 같은 구도, 창밖만 다름) ----------
  const W = 1010, H = 650;
  const WEATHER = {
    rain: { sky: ['#1b0f3d', '#5a2a7a', '#c4467e'], stars: 30, orb: ['#ffe9a8', 620, 34, 14], fall: 'rain' },
    night: { sky: ['#0a0824', '#1e1650', '#4a2c7c'], stars: 90, orb: ['#fff4c9', 600, 40, 20] },
    sunset: { sky: ['#ff9a5c', '#ff5c8a', '#7b3aa8'], stars: 0, orb: ['#ffe07a', 360, 120, 34] },
    snow: { sky: ['#2a3a6a', '#5a6a9a', '#aab4d8'], stars: 0, orb: ['#f4f8ff', 610, 36, 14], fall: 'snow' },
    sunny: { sky: ['#4aa8ff', '#8ad0ff', '#d8f0ff'], stars: 0, orb: ['#fff4a8', 610, 40, 24], clouds: true },
  };
  for (const [name, w] of Object.entries(WEATHER)) {
    const fall = w.fall === 'rain' ? [...Array(40)].map((_, i) => `<rect x="${(i * 97) % 720}" y="${(i * 53) % 150}" width="2" height="12" fill="#9fe9ff" opacity=".22"/>`).join('')
      : w.fall === 'snow' ? [...Array(60)].map((_, i) => `<rect x="${(i * 97) % 716}" y="${(i * 41) % 162}" width="4" height="4" fill="#fff" opacity="${0.5 + (i % 5) / 10}"/>`).join('') + `<rect x="0" y="158" width="720" height="8" fill="#f4f8ff"/>` : '';
    const clouds = w.clouds ? [[90, 30], [300, 54], [500, 24]].map(([x, y]) => `<rect x="${x}" y="${y}" width="80" height="16" rx="8" fill="#fff"/><rect x="${x + 16}" y="${y - 10}" width="44" height="16" rx="8" fill="#fff"/>`).join('') : '';
    S['room_bg_' + name] = [W, H, `<defs>
      <linearGradient id="wall" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#1e1038"/><stop offset="1" stop-color="#341c5c"/></linearGradient>
      <linearGradient id="under" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ff4d8d" stop-opacity=".55"/><stop offset="1" stop-color="#ff4d8d" stop-opacity="0"/></linearGradient>
      <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${w.sky[0]}"/><stop offset=".6" stop-color="${w.sky[1]}"/><stop offset="1" stop-color="${w.sky[2]}"/></linearGradient></defs>
      <rect width="${W}" height="${H}" fill="url(#wall)"/>
      ${[...Array(14)].map((_, i) => `<rect x="${i * 76 + 30}" y="0" width="2" height="420" fill="#4a2c7c" opacity=".5"/>`).join('')}
      <rect x="0" y="0" width="${W}" height="6" fill="#2ee6d6"/><rect x="0" y="6" width="${W}" height="8" fill="#2ee6d6" opacity=".2"/>
      <g transform="translate(40 254)"><rect x="-12" y="-12" width="744" height="190" fill="#0d0720"/>
        <rect width="720" height="166" fill="url(#sky)"/>${w.stars ? stars(720, 70, w.stars, 9) : ''}<circle cx="${w.orb[1]}" cy="${w.orb[2]}" r="${w.orb[3]}" fill="${w.orb[0]}"/>${clouds}
        <g transform="translate(0 30)">${city(720, 136, 21, 1)}</g>${fall}
        ${[180, 360, 540].map(x => `<rect x="${x - 3}" y="0" width="6" height="166" fill="#0d0720"/>`).join('')}
        <rect x="-12" y="-12" width="744" height="190" fill="none" stroke="#ff4d8d" stroke-width="3"/></g>
      <rect x="0" y="418" width="${W}" height="34" fill="#2b2252"/><rect x="0" y="418" width="${W}" height="4" fill="#3d3274"/>
      <rect x="24" y="424" width="790" height="24" fill="#110a24"/><rect x="24" y="424" width="790" height="24" fill="none" stroke="#2ee6d6" stroke-width="1.5" opacity=".7"/>
      <rect x="0" y="452" width="${W}" height="5" fill="#2ee6d6"/>
      <rect x="0" y="457" width="${W}" height="${H - 457}" fill="#160f30"/><rect x="0" y="457" width="${W}" height="40" fill="url(#under)"/>
      ${[0, 1, 2].map(i => `<rect x="${60 + i * 300}" y="500" width="260" height="120" fill="none" stroke="#2b2252" stroke-width="3"/><rect x="${170 + i * 300}" y="530" width="40" height="5" fill="#7b5cff"/>`).join('')}`];
  }
};
