// 소품 · 배경 스프라이트(SVG → PNG) 생성: node tools/make_sprites.js
const sharp = require('sharp'), path = require('path');
const OUT = path.join(__dirname, '..', 'resource');
const S = {};
const shadow = (cx, y, rx) => `<ellipse cx="${cx}" cy="${y}" rx="${rx}" ry="4" fill="#000" opacity=".18"/>`;

// ---- 책상 위 (바닥선 = 높이). 1칸 = 98px, 2칸 = 208px ----
const glow = (id, sd) => `<filter id="${id}" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="${sd}"/></filter>`;
const RGB = (id, v) => `<linearGradient id="${id}" x1="0" y1="0" x2="${v ? 0 : 1}" y2="${v ? 1 : 0}"><stop offset="0" stop-color="#ff4d8d"/><stop offset=".5" stop-color="#7b5cff"/><stop offset="1" stop-color="#2ee6d6"/></linearGradient>`;
const code = [[0, 'k', 30], [0, 'f', 40], [1, 'v', 50], [1, 's', 34], [2, 'k', 22], [2, 'v', 44], [1, 'f', 60], [0, 'k', 18], [1, 's', 52]];
const CC = {k: '#ff4d8d', f: '#2ee6d6', v: '#c9b8ff', s: '#ffd65c'};
S.monitor = [208, 176, `<defs>${glow('mg', 10)}</defs>
  <ellipse cx="104" cy="70" rx="100" ry="56" fill="#ff4d8d" opacity=".35" filter="url(#mg)"/>
  <path d="M64 176 L144 176 L136 164 L72 164 Z" fill="#2a2350"/><rect x="64" y="172" width="80" height="4" fill="#3b3170"/>
  <rect x="96" y="124" width="16" height="42" fill="#231c44"/><rect x="100" y="124" width="3" height="42" fill="#3b3170"/>
  <rect x="0" y="0" width="208" height="128" rx="4" fill="#0f0a22"/><rect x="0" y="0" width="208" height="128" rx="4" fill="none" stroke="#3b3170" stroke-width="2"/>
  <rect x="6" y="6" width="196" height="110" fill="#160f30"/>
  <rect x="6" y="6" width="196" height="12" fill="#221848"/>
  <rect x="38" y="6" width="44" height="12" fill="#160f30"/><rect x="38" y="16" width="44" height="2" fill="#2ee6d6"/>
  <rect x="84" y="9" width="36" height="6" fill="#3a2d6e"/><rect x="124" y="9" width="30" height="6" fill="#3a2d6e"/>
  <rect x="6" y="18" width="30" height="92" fill="#1c1438"/>
  ${[0,1,2,3,4,5,6].map(i=>`<rect x="10" y="${24+i*11}" width="${8+((i*7)%14)}" height="4" fill="${i==2?'#2ee6d6':'#5a4a96'}"/>`).join('')}
  ${code.map(([ind,t,w],i)=>`<rect x="40" y="${23+i*9.5}" width="6" height="4" fill="#4a3d80"/><rect x="${52+ind*8}" y="${23+i*9.5}" width="${w}" height="4" fill="${CC[t]}"/><rect x="${56+ind*8+w}" y="${23+i*9.5}" width="${(w*7)%30+6}" height="4" fill="#8f80c8"/>`).join('')}
  <rect x="${52+16+22}" y="${23+4*9.5}" width="4" height="6" fill="#ffffff"/>
  <rect x="6" y="110" width="196" height="6" fill="#7b5cff"/><rect x="10" y="111" width="20" height="4" fill="#ffffff" opacity=".6"/>
  <rect x="98" y="120" width="12" height="3" fill="#2a2350"/><rect x="190" y="121" width="4" height="3" fill="#2ee6d6"/>
  <path d="M150 6 L202 6 L202 40 Z" fill="#fff" opacity=".05"/>`];
const kb = (body, key, under, mouse) => [98, 44, `<defs>${RGB('kr')}${glow('kg', 3)}</defs>
  ${under ? `<rect x="2" y="30" width="72" height="8" fill="url(#kr)" filter="url(#kg)"/>` : ''}
  <rect x="0" y="12" width="76" height="26" rx="3" fill="${body}"/><rect x="0" y="34" width="76" height="4" fill="#000" opacity=".25"/>
  ${[0,1,2,3].map(r=>[...Array(r==3?5:10)].map((_,c)=>{const w=r==3?(c==2?22:7):5.6, x=r==3?[3,12,21,45,55][c]:3+c*7.1;return `<rect x="${x}" y="${15+r*5.5}" width="${w}" height="4" fill="${key==='rgb'?`url(#kr)`:key}"/>`}).join('')).join('')}
  ${mouse}`];
S.keyboard = kb('#c9ccd6', '#f4f4fa', false, `<rect x="80" y="20" width="16" height="22" rx="8" fill="#e6e8f0"/><rect x="87" y="22" width="2" height="7" fill="#9aa0b4"/>`);
S.gaming_kb = kb('#14102a', 'rgb', true, `<rect x="80" y="20" width="16" height="22" rx="8" fill="#14102a"/><rect x="87" y="22" width="2" height="7" fill="#2ee6d6"/><rect x="80" y="36" width="16" height="3" fill="#ff4d8d"/>`);
const lamp = (shade, light) => [98, 180, `<defs>${glow('lg', 6)}</defs>
  <path d="M74 66 L98 180 L22 180 Z" fill="${light}" opacity=".18"/>
  <ellipse cx="74" cy="66" rx="16" ry="8" fill="${light}" filter="url(#lg)"/>
  <rect x="6" y="170" width="44" height="10" rx="2" fill="#2a2350"/><rect x="6" y="170" width="44" height="3" fill="#3b3170"/>
  <rect x="24" y="162" width="8" height="8" fill="#3b3170"/><circle cx="28" cy="160" r="5" fill="#ff4d8d"/>
  <path d="M28 160 L18 96" stroke="#3b3170" stroke-width="6"/><path d="M26 160 L16 96" stroke="#5a4a96" stroke-width="2"/>
  <circle cx="18" cy="96" r="5" fill="#2ee6d6"/>
  <path d="M18 96 L56 42" stroke="#3b3170" stroke-width="6"/><path d="M17 94 L55 40" stroke="#5a4a96" stroke-width="2"/>
  <circle cx="56" cy="42" r="5" fill="#2ee6d6"/>
  <path d="M50 30 L92 46 L82 70 L42 50 Z" fill="${shade}"/><path d="M50 30 L92 46 L90 52 L48 36 Z" fill="#fff" opacity=".25"/>
  <circle cx="74" cy="62" r="6" fill="#fffbe6"/>`];
S.lamp_warm = lamp('#f2a541', '#ffd27a');
S.lamp_cool = lamp('#7fd8f0', '#e8fbff');
S.book = [98, 112, `
  <rect x="4" y="96" width="90" height="16" fill="#7b5cff"/><rect x="4" y="96" width="90" height="3" fill="#c9b8ff"/><rect x="88" y="99" width="6" height="13" fill="#f4f0ff"/>
  ${[[8,18,'#ff4d8d',70],[27,14,'#2ee6d6',58],[42,20,'#ffd65c',76],[63,12,'#5a4a96',52],[76,16,'#e76f51',64]].map(([x,w,c,h])=>`<rect x="${x}" y="${96-h}" width="${w}" height="${h}" fill="${c}"/><rect x="${x+2}" y="${96-h+8}" width="${w-4}" height="3" fill="#fff" opacity=".6"/><rect x="${x+2}" y="${96-12}" width="${w-4}" height="3" fill="#000" opacity=".3"/><rect x="${x}" y="${96-h}" width="2" height="${h}" fill="#fff" opacity=".25"/>`).join('')}`];
S.mug = [98, 78, `
  <path d="M38 10 q-6 6 0 12 q6 6 0 12 M52 4 q-6 6 0 12 q6 6 0 12" stroke="#c9b8ff" stroke-width="3" fill="none" opacity=".7"/>
  <ellipse cx="46" cy="74" rx="34" ry="4" fill="#ff4d8d"/><ellipse cx="46" cy="73" rx="30" ry="3" fill="#2a2350"/>
  <rect x="24" y="30" width="44" height="42" rx="4" fill="#f4f0ff"/><rect x="24" y="30" width="44" height="6" fill="#d8ccff"/>
  <rect x="26" y="32" width="40" height="4" fill="#4a2c1c"/>
  <path d="M68 38 q16 0 16 13 q0 13 -16 13" stroke="#d8ccff" stroke-width="6" fill="none"/>
  <path d="M40 48 h4 v-2 h4 v2 h4 v4 h-2 v4 h-2 v2 h-4 v-2 h-2 v-4 h-2 Z" fill="#ff4d8d"/>`];
S.mini_plant = [98, 124, `
  ${[[49,70,-58,'#3f8f6e'],[49,70,-20,'#56b08a'],[49,70,15,'#3f8f6e'],[49,70,50,'#68c49b'],[49,70,-85,'#56b08a']].map(([x,y,r,c])=>`<g transform="rotate(${r} ${x} ${y})"><path d="M${x} ${y} C${x-20} ${y-26} ${x-12} ${y-58} ${x} ${y-66} C${x+12} ${y-58} ${x+20} ${y-26} ${x} ${y}" fill="${c}"/><path d="M${x} ${y} L${x} ${y-60}" stroke="#2c6b51" stroke-width="2"/></g>`).join('')}
  <path d="M24 78 L74 78 L68 124 L30 124 Z" fill="#2a2350"/><rect x="20" y="74" width="58" height="10" fill="#3b3170"/>
  ${[0,1,2,3].map(i=>`<rect x="${32+i*9}" y="94" width="5" height="5" fill="#2ee6d6"/><rect x="${36+i*9}" y="106" width="5" height="5" fill="#ff4d8d"/>`).join('')}`];
S.mic = [98, 180, `<defs>${glow('pg', 4)}</defs>
  <rect x="6" y="160" width="22" height="20" fill="#2a2350"/><rect x="2" y="174" width="30" height="6" fill="#3b3170"/>
  <path d="M17 160 L30 98" stroke="#3b3170" stroke-width="5"/><circle cx="30" cy="98" r="4" fill="#2ee6d6"/>
  <path d="M30 98 L62 50" stroke="#3b3170" stroke-width="5"/><path d="M28 98 L60 50" stroke="#5a4a96" stroke-width="1"/>
  <circle cx="66" cy="48" r="16" fill="none" stroke="#5a4a96" stroke-width="3"/>
  <rect x="56" y="6" width="22" height="50" rx="11" fill="#1c1438"/><rect x="56" y="6" width="22" height="50" rx="11" fill="none" stroke="#5a4a96" stroke-width="2"/>
  ${[0,1,2,3,4,5].map(i=>`<rect x="60" y="${12+i*6}" width="14" height="2" fill="#7b6bb8"/>`).join('')}
  <rect x="58" y="46" width="18" height="3" fill="#ff4d8d" filter="url(#pg)"/><rect x="58" y="46" width="18" height="3" fill="#ff4d8d"/>
  <circle cx="30" cy="40" r="18" fill="#2ee6d6" opacity=".12"/><circle cx="30" cy="40" r="18" fill="none" stroke="#2a2350" stroke-width="3"/>`];
S.headset = [98, 150, `<defs>${RGB('hr', 1)}${glow('hg', 4)}</defs>
  <ellipse cx="49" cy="146" rx="30" ry="4" fill="#3b3170"/><rect x="22" y="138" width="54" height="8" fill="#2a2350"/>
  <rect x="45" y="40" width="8" height="98" fill="#2a2350"/><rect x="47" y="40" width="2" height="98" fill="#5a4a96"/>
  <path d="M20 70 Q20 28 49 28 Q78 28 78 70" stroke="#14102a" stroke-width="9" fill="none"/>
  <path d="M20 70 Q20 28 49 28 Q78 28 78 70" stroke="#5a4a96" stroke-width="2" fill="none"/>
  ${[14,72].map(x=>`<rect x="${x-2}" y="62" width="16" height="34" rx="6" fill="url(#hr)" filter="url(#hg)" opacity=".8"/><rect x="${x}" y="64" width="12" height="30" rx="5" fill="#14102a"/><rect x="${x+3}" y="70" width="6" height="18" fill="url(#hr)"/>`).join('')}`];

S.speaker = [98, 132, `<defs>${glow('sg', 4)}</defs>
  <rect x="20" y="4" width="58" height="124" rx="4" fill="#14102a"/><rect x="20" y="4" width="58" height="124" rx="4" fill="none" stroke="#3b3170" stroke-width="2"/>
  <circle cx="49" cy="30" r="11" fill="#2a2350"/><circle cx="49" cy="30" r="5" fill="#5a4a96"/>
  <circle cx="49" cy="84" r="24" fill="#ffd65c" opacity=".5" filter="url(#sg)"/>
  <circle cx="49" cy="84" r="22" fill="#2a2350"/><circle cx="49" cy="84" r="22" fill="none" stroke="#ffd65c" stroke-width="2"/>
  <circle cx="49" cy="84" r="12" fill="#1c1438"/><circle cx="49" cy="84" r="4" fill="#5a4a96"/>
  <rect x="44" y="118" width="10" height="3" fill="#2ee6d6"/><rect x="24" y="128" width="50" height="4" fill="#0a0618"/>`];
S.webcam = [98, 100, `
  <path d="M49 60 L28 100 M49 60 L70 100 M49 60 L49 100" stroke="#3b3170" stroke-width="4"/>
  <rect x="44" y="50" width="10" height="12" fill="#2a2350"/>
  <rect x="18" y="16" width="62" height="36" rx="12" fill="#14102a"/><rect x="18" y="16" width="62" height="36" rx="12" fill="none" stroke="#5a4a96" stroke-width="2"/>
  <circle cx="49" cy="34" r="12" fill="#2a2350"/><circle cx="49" cy="34" r="8" fill="#1a3b6e"/><circle cx="46" cy="31" r="3" fill="#9fe9ff"/>
  <circle cx="70" cy="24" r="3" fill="#ff4d8d"/>`];

// ---- 벽 (밴드 안 가운데) ----
S.shelf = [208, 130, `
  ${[[14,14,'#ff4d8d',54],[30,12,'#2ee6d6',44],[44,16,'#7b5cff',60],[62,10,'#ffd65c',40]].map(([x,w,c,h])=>`<rect x="${x}" y="${100-h}" width="${w}" height="${h}" fill="${c}"/><rect x="${x+2}" y="${100-h+6}" width="${w-4}" height="2" fill="#fff" opacity=".6"/>`).join('')}
  <rect x="86" y="62" width="26" height="30" fill="#c9ccd6"/><rect x="88" y="64" width="22" height="16" fill="#1c1438"/><rect x="92" y="70" width="4" height="4" fill="#2ee6d6"/><rect x="102" y="70" width="4" height="4" fill="#2ee6d6"/>
  <rect x="96" y="54" width="6" height="8" fill="#c9ccd6"/><rect x="98" y="50" width="2" height="4" fill="#ff4d8d"/><rect x="82" y="92" width="34" height="8" fill="#9aa0b4"/>
  <rect x="130" y="70" width="22" height="22" fill="#56b08a"/><rect x="134" y="62" width="14" height="10" fill="#56b08a"/><rect x="128" y="80" width="6" height="8" fill="#56b08a"/><rect x="148" y="74" width="6" height="8" fill="#56b08a"/>
  <rect x="126" y="90" width="30" height="10" fill="#e76f51"/>
  <rect x="166" y="56" width="28" height="44" fill="#1c1438"/><circle cx="180" cy="70" r="7" fill="#3b3170"/><circle cx="180" cy="88" r="8" fill="#3b3170"/><circle cx="180" cy="88" r="3" fill="#2ee6d6"/>
  <rect x="0" y="100" width="208" height="12" fill="#2a2350"/><rect x="0" y="100" width="208" height="3" fill="#7b5cff"/><rect x="0" y="112" width="208" height="2" fill="#ff4d8d" opacity=".7"/>
  <path d="M26 114 L26 130 L42 114 Z M182 114 L182 130 L166 114 Z" fill="#1d1838"/>`];
S.frame = [98, 116, `<defs>${glow('fg', 4)}</defs>
  <rect x="6" y="4" width="86" height="108" fill="none" stroke="#ff4d8d" stroke-width="4" filter="url(#fg)"/>
  <rect x="6" y="4" width="86" height="108" fill="#120a26" stroke="#2a2350" stroke-width="6"/>
  <rect x="12" y="10" width="74" height="96" fill="#2a124a"/><rect x="12" y="10" width="74" height="50" fill="#4a1d6a"/>
  <circle cx="49" cy="60" r="22" fill="#ffd65c"/>${[0,1,2,3].map(i=>`<rect x="26" y="${48+i*5}" width="46" height="2" fill="#4a1d6a"/>`).join('')}
  <rect x="12" y="60" width="74" height="46" fill="#1b0f3d"/>
  ${[0,1,2,3,4].map(i=>`<rect x="12" y="${64+i*9}" width="74" height="1.5" fill="#ff4d8d"/>`).join('')}
  ${[-3,-2,-1,0,1,2,3].map(i=>`<path d="M49 60 L${49+i*16} 106" stroke="#2ee6d6" stroke-width="1.2"/>`).join('')}`];
S.rgb_bar = [208, 44, `<defs>${RGB('bar')}${glow('b', 7)}</defs>
  <rect x="8" y="16" width="192" height="12" rx="6" fill="url(#bar)" filter="url(#b)" opacity=".9"/>
  <rect x="8" y="18" width="192" height="8" fill="#14102a"/><rect x="10" y="20" width="188" height="4" fill="url(#bar)"/>`];
S.wall_light = [98, 120, `<defs><radialGradient id="wg"><stop offset="0" stop-color="#2ee6d6" stop-opacity=".6"/><stop offset="1" stop-color="#2ee6d6" stop-opacity="0"/></radialGradient></defs>
  <circle cx="49" cy="60" r="48" fill="url(#wg)"/>
  <rect x="40" y="14" width="18" height="92" fill="#14102a"/><rect x="44" y="20" width="10" height="80" fill="#2ee6d6"/><rect x="47" y="22" width="4" height="76" fill="#e8fffd"/>
  <rect x="36" y="8" width="26" height="8" fill="#2a2350"/><rect x="36" y="104" width="26" height="8" fill="#2a2350"/>`];
S.hanging_plant = [98, 140, `<path d="M49 0 L30 38 M49 0 L68 38" stroke="#7b5cff" stroke-width="2"/>
  <path d="M26 38 L72 38 L64 64 L34 64 Z" fill="#2a2350"/><rect x="26" y="38" width="46" height="5" fill="#ff4d8d"/>
  <path d="M34 60 q-12 30 -6 70 M44 64 q-4 24 2 52 M58 64 q8 26 2 60 M66 58 q16 18 12 46" stroke="#2c6b51" stroke-width="3" fill="none"/>
  ${[[28,84],[26,104],[30,124],[44,90],[46,110],[58,88],[62,108],[58,122],[74,74],[78,94]].map(([x,y],i)=>`<rect x="${x-5}" y="${y-3}" width="10" height="7" fill="${i%2?'#56b08a':'#68c49b'}"/>`).join('')}
  <path d="M30 38 q10 -16 19 -2 q9 -16 19 2" fill="#3f8f6e"/>`];
S.neon_sign = [208, 112, `<defs>${glow('ng', 5)}</defs>
  <rect x="2" y="2" width="204" height="108" rx="6" fill="#120a26" opacity=".6"/>
  <g filter="url(#ng)"><path d="M40 30 L18 56 L40 82 M168 30 L190 56 L168 82 M118 22 L90 90" stroke="#ff4d8d" stroke-width="8" fill="none"/></g>
  <path d="M40 30 L18 56 L40 82 M168 30 L190 56 L168 82" stroke="#ffd0e2" stroke-width="3" fill="none"/>
  <g filter="url(#ng)"><path d="M118 22 L90 90" stroke="#2ee6d6" stroke-width="8"/></g><path d="M118 22 L90 90" stroke="#e8fffd" stroke-width="3"/>`];

// ---- PC 케이스 (책상 위, 160 x 262) ----
const tower = (body, glass, fan, extra) => [160, 262, `<defs>${RGB('cr', 1)}${glow('cg', 5)}</defs>
  <rect x="2" y="2" width="156" height="254" rx="5" fill="${body}"/><rect x="2" y="250" width="156" height="12" fill="#0a0618"/>
  <rect x="12" y="14" width="104" height="226" fill="${glass}"/>
  <rect x="20" y="22" width="88" height="120" fill="#1c1438"/>
  <rect x="36" y="38" width="30" height="30" fill="#2a2350"/><circle cx="51" cy="53" r="11" fill="none" stroke="${fan}" stroke-width="3"/>
  ${[0,1,2,3].map(i=>`<rect x="${76+i*6}" y="34" width="3" height="40" fill="${fan}"/>`).join('')}
  <rect x="20" y="96" width="88" height="20" fill="#0f0a22"/><rect x="20" y="114" width="88" height="3" fill="${fan}"/>
  <circle cx="44" cy="106" r="7" fill="#2a2350"/><circle cx="72" cy="106" r="7" fill="#2a2350"/>
  <rect x="20" y="170" width="88" height="60" fill="#0f0a22"/><rect x="26" y="176" width="40" height="8" fill="#3b3170"/>
  ${[0,1,2].map(i=>`<circle cx="138" cy="${54+i*72}" r="18" fill="none" stroke="${fan}" stroke-width="5"/><circle cx="138" cy="${54+i*72}" r="5" fill="${fan}"/>`).join('')}
  <rect x="122" y="14" width="2" height="226" fill="#000" opacity=".3"/>
  <path d="M12 14 L60 14 L12 70 Z" fill="#fff" opacity=".07"/>${extra}`];
S.case1 = tower('#2a2350', '#120a26', '#5a4a96', `<rect x="146" y="6" width="6" height="4" fill="#2ee6d6"/>`);
S.case2 = tower('#e8e6f2', '#cfcbe0', '#9a94b8', `<rect x="146" y="6" width="6" height="4" fill="#2ee6d6"/>`);
S.case3 = tower('#14102a', '#0a0618', 'url(#cr)', `<rect x="12" y="236" width="104" height="4" fill="url(#cr)" filter="url(#cg)"/><rect x="146" y="6" width="6" height="4" fill="#ff4d8d"/>`);
S.case_empty = [160, 262, `<rect x="4" y="4" width="152" height="252" rx="5" fill="#120a26" opacity=".5" stroke="#2ee6d6" stroke-width="3" stroke-dasharray="10 8"/>
  <rect x="74" y="104" width="12" height="44" fill="#2ee6d6"/><rect x="58" y="120" width="44" height="12" fill="#2ee6d6"/>`];

// ---- 부품 아이콘 ----
S.part_CPU = [64, 64, `<rect x="10" y="10" width="44" height="44" rx="4" fill="#4a4e69"/><rect x="20" y="20" width="24" height="24" rx="2" fill="#c9ccd6"/>
  ${[16,26,36,46].map(v=>`<rect x="${v}" y="2" width="3" height="8" fill="#f2a541"/><rect x="${v}" y="54" width="3" height="8" fill="#f2a541"/><rect x="2" y="${v}" width="8" height="3" fill="#f2a541"/><rect x="54" y="${v}" width="8" height="3" fill="#f2a541"/>`).join('')}`];
S.part_GPU = [64, 64, `<rect x="2" y="16" width="60" height="30" rx="4" fill="#2b2d42"/><circle cx="20" cy="31" r="10" fill="#4a4e69"/><circle cx="44" cy="31" r="10" fill="#4a4e69"/>
  <circle cx="20" cy="31" r="3" fill="#8d99ae"/><circle cx="44" cy="31" r="3" fill="#8d99ae"/><rect x="8" y="46" width="30" height="5" fill="#f2a541"/>`];
S.part_RAM = [64, 64, `<rect x="4" y="20" width="56" height="20" rx="2" fill="#6a9c78"/>${[10,22,34,46].map(x=>`<rect x="${x}" y="24" width="8" height="10" fill="#2b2d42"/>`).join('')}
  <rect x="6" y="40" width="52" height="4" fill="#f2a541"/>`];
S.part_PSU = [64, 64, `<rect x="6" y="12" width="52" height="40" rx="4" fill="#3a3d55"/><circle cx="28" cy="32" r="13" fill="none" stroke="#8d99ae" stroke-width="3"/>
  <path d="M46 22 L50 30 L45 30 L49 40" stroke="#f2a541" stroke-width="3" fill="none"/>`];
S.part_MB = [64, 64, `<rect x="6" y="6" width="52" height="52" rx="3" fill="#163440"/><rect x="14" y="14" width="18" height="18" fill="#c9ccd6"/>
  <rect x="38" y="12" width="4" height="30" fill="#2e7d5b"/><rect x="46" y="12" width="4" height="30" fill="#2e7d5b"/><rect x="12" y="44" width="40" height="5" fill="#3b3170"/>
  <path d="M12 38 H30 M20 20 V36" stroke="#2ee6d6" stroke-width="1.5"/>`];
S.part_COOLER = [64, 64, `<rect x="8" y="8" width="48" height="48" rx="6" fill="#2a2350"/><circle cx="32" cy="32" r="20" fill="none" stroke="#2ee6d6" stroke-width="3"/>
  ${[0,1,2,3].map(i=>`<path d="M32 32 L${32+18*Math.cos(i*Math.PI/2)} ${32+18*Math.sin(i*Math.PI/2)}" stroke="#5a4a96" stroke-width="6"/>`).join('')}<circle cx="32" cy="32" r="6" fill="#2ee6d6"/>`];
S.part_CASE = [64, 64, `<rect x="16" y="4" width="32" height="56" rx="4" fill="#4a4e69"/><rect x="20" y="10" width="20" height="44" rx="2" fill="#5b6078"/><circle cx="30" cy="22" r="6" fill="none" stroke="#2ee6d6" stroke-width="2"/>`];

// ---- 사이버 도시 (창밖 · 타이틀) ----
function city(w, h, seed, scale = 1) {
  let r = seed; const rnd = () => (r = (r * 16807) % 2147483647) / 2147483647;
  const neon = ['#ff4d8d', '#2ee6d6', '#7b5cff', '#ffd65c'];
  let out = '', x = -10;
  for (const layer of [{c: '#3a2470', hMin: .35, hMax: .7, win: .25}, {c: '#241446', hMin: .2, hMax: .55, win: .5}]) {
    x = -10;
    while (x < w) {
      const bw = (30 + rnd() * 60) * scale, bh = h * (layer.hMin + rnd() * (layer.hMax - layer.hMin));
      out += `<rect x="${x}" y="${h - bh}" width="${bw}" height="${bh}" fill="${layer.c}"/>`;
      for (let wy = h - bh + 8 * scale; wy < h - 6; wy += 10 * scale)
        for (let wx = x + 5 * scale; wx < x + bw - 6 * scale; wx += 9 * scale)
          if (rnd() < layer.win) out += `<rect x="${wx}" y="${wy}" width="${4 * scale}" height="${4 * scale}" fill="${rnd() < .7 ? '#ffd65c' : '#2ee6d6'}" opacity=".85"/>`;
      if (rnd() < .45) {
        const c = neon[Math.floor(rnd() * 4)], sy = h - bh + 12 * scale;
        out += `<rect x="${x + bw * .2}" y="${sy}" width="${bw * .6}" height="${12 * scale}" fill="none" stroke="${c}" stroke-width="${3 * scale}"/>`;
      }
      if (rnd() < .3) out += `<rect x="${x + bw / 2 - scale}" y="${h - bh - 20 * scale}" width="${2 * scale}" height="${20 * scale}" fill="${layer.c}"/><rect x="${x + bw / 2 - 2 * scale}" y="${h - bh - 22 * scale}" width="${4 * scale}" height="${4 * scale}" fill="#ff4d8d"/>`;
      x += bw + rnd() * 6 * scale;
    }
  }
  return out;
}
const sky = (id) => `<linearGradient id="${id}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#1b0f3d"/><stop offset=".6" stop-color="#5a2a7a"/><stop offset="1" stop-color="#c4467e"/></linearGradient>`;
const stars = (w, h, n, seed) => { let r = seed, o = ''; const rnd = () => (r = (r * 48271) % 2147483647) / 2147483647;
  for (let i = 0; i < n; i++) o += `<rect x="${rnd() * w}" y="${rnd() * h}" width="3" height="3" fill="#fff" opacity="${.4 + rnd() * .6}"/>`; return o; };

// ---- 방 배경 (x 270~1280, y 0~650 영역 = 1010 x 650). 화면 y = 650 - 배경 y ----
const W = 1010, H = 650;
S.room_bg = [W, H, `<defs>
  <linearGradient id="wall" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#1e1038"/><stop offset="1" stop-color="#341c5c"/></linearGradient>
  <linearGradient id="under" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ff4d8d" stop-opacity=".55"/><stop offset="1" stop-color="#ff4d8d" stop-opacity="0"/></linearGradient>
  ${sky('sky')}</defs>
  <rect width="${W}" height="${H}" fill="url(#wall)"/>
  ${[...Array(14)].map((_, i) => `<rect x="${i * 76 + 30}" y="0" width="2" height="420" fill="#4a2c7c" opacity=".5"/>`).join('')}
  <rect x="0" y="0" width="${W}" height="6" fill="#2ee6d6"/><rect x="0" y="6" width="${W}" height="8" fill="#2ee6d6" opacity=".2"/>
  <g transform="translate(40 254)"><rect x="-12" y="-12" width="744" height="190" fill="#0d0720"/>
    <rect width="720" height="166" fill="url(#sky)"/>${stars(720, 70, 30, 9)}<circle cx="620" cy="34" r="14" fill="#ffe9a8"/>
    <g transform="translate(0 30)">${city(720, 136, 21, 1)}</g>
    ${[...Array(40)].map((_, i) => `<rect x="${(i * 97) % 720}" y="${(i * 53) % 150}" width="2" height="12" fill="#9fe9ff" opacity=".22"/>`).join('')}
    ${[180, 360, 540].map(x => `<rect x="${x - 3}" y="0" width="6" height="166" fill="#0d0720"/>`).join('')}
    <rect x="-12" y="-12" width="744" height="190" fill="none" stroke="#ff4d8d" stroke-width="3"/></g>
  <rect x="0" y="418" width="${W}" height="34" fill="#2b2252"/><rect x="0" y="418" width="${W}" height="4" fill="#3d3274"/>
  <rect x="24" y="424" width="790" height="24" fill="#110a24"/><rect x="24" y="424" width="790" height="24" fill="none" stroke="#2ee6d6" stroke-width="1.5" opacity=".7"/>
  <rect x="0" y="452" width="${W}" height="5" fill="#2ee6d6"/>
  <rect x="0" y="457" width="${W}" height="${H - 457}" fill="#160f30"/><rect x="0" y="457" width="${W}" height="40" fill="url(#under)"/>
  ${[0, 1, 2].map(i => `<rect x="${60 + i * 300}" y="500" width="260" height="120" fill="none" stroke="#2b2252" stroke-width="3"/><rect x="${170 + i * 300}" y="530" width="40" height="5" fill="#7b5cff"/>`).join('')}`];

// 타이틀 배경 1280 x 720
S.title_bg = [1280, 720, `<defs>${sky('tsky')}</defs><rect width="1280" height="720" fill="url(#tsky)"/>${stars(1280, 360, 80, 3)}
  <circle cx="1040" cy="150" r="46" fill="#ffe9a8"/>
  <g transform="translate(0 300)">${city(1280, 420, 5, 1.6)}</g>
  <rect y="660" width="1280" height="60" fill="#120a26"/><rect y="660" width="1280" height="4" fill="#2ee6d6"/>
  <rect x="100" y="150" width="700" height="250" fill="#120a26" opacity=".55"/>`];

(async () => {
  for (const [name, [w, h, body]] of Object.entries(S)) {
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">${body}</svg>`;
    const f = w > 500 ? 3 : 2;  // 도트 느낌: 작게 줄였다가 nearest로 다시 키움
    const small = await sharp(Buffer.from(svg)).resize(Math.ceil(w / f), Math.ceil(h / f), { kernel: 'nearest' }).png().toBuffer();
    await sharp(small).resize(w, h, { kernel: 'nearest' }).png().toFile(path.join(OUT, name + '.png'));
  }
  console.log(Object.keys(S).length, 'sprites');
})();
