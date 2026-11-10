// 확장 상품 스프라이트. make_sprites.js가 불러서 S에 더한다.
module.exports = (S, h) => {
  const { glow, RGB, kb, lamp, tower } = h;
  // 모니터 계열: 화면 내용(screen)과 프레임 색만 바꾼 템플릿
  const mon = (w, frame, stand, screen, glowc) => [w, 176, `<defs>${glow('mg', 10)}</defs>
    <ellipse cx="${w / 2}" cy="70" rx="${w / 2 - 4}" ry="56" fill="${glowc}" opacity=".3" filter="url(#mg)"/>
    <path d="M${w / 2 - 40} 176 L${w / 2 + 40} 176 L${w / 2 + 32} 164 L${w / 2 - 32} 164 Z" fill="${stand}"/>
    <rect x="${w / 2 - 8}" y="124" width="16" height="42" fill="${stand}"/>
    <rect x="0" y="0" width="${w}" height="128" rx="4" fill="${frame}"/>
    <rect x="6" y="6" width="${w - 12}" height="110" fill="#160f30"/>${screen(w)}
    <path d="M${w - 60} 6 L${w - 6} 6 L${w - 6} 40 Z" fill="#fff" opacity=".05"/>`];
  const gameScreen = w => `<rect x="6" y="6" width="${w - 12}" height="110" fill="#2a124a"/><rect x="6" y="70" width="${w - 12}" height="46" fill="#1b0f3d"/>
    <circle cx="${w / 2}" cy="70" r="26" fill="#ffd65c"/>${[0, 1, 2, 3].map(i => `<rect x="6" y="${76 + i * 9}" width="${w - 12}" height="2" fill="#ff4d8d"/>`).join('')}
    <rect x="${w / 2 - 70}" y="92" width="20" height="10" fill="#2ee6d6"/><rect x="${w / 2 + 40}" y="96" width="14" height="8" fill="#ff4d8d"/>`;
  const docScreen = w => `<rect x="6" y="6" width="${w - 12}" height="110" fill="#e8e6f2"/><rect x="6" y="6" width="${w - 12}" height="12" fill="#cfcbe0"/>
    ${[0, 1, 2, 3, 4, 5].map(i => `<rect x="20" y="${28 + i * 13}" width="${(w - 40) * (0.5 + ((i * 37) % 50) / 100)}" height="5" fill="#9a94b8"/>`).join('')}`;
  S.monitor_27 = mon(208, '#0f0a22', '#2a2350', gameScreen, '#7b5cff');
  S.monitor_white = mon(208, '#e8e6f2', '#cfcbe0', docScreen, '#2ee6d6');
  S.monitor_curve = [318, 176, `<defs>${glow('cg2', 10)}${RGB('cv')}</defs>
    <ellipse cx="159" cy="70" rx="150" ry="56" fill="#ff4d8d" opacity=".3" filter="url(#cg2)"/>
    <path d="M119 176 L199 176 L191 164 L127 164 Z" fill="#2a2350"/><rect x="151" y="120" width="16" height="46" fill="#2a2350"/>
    <path d="M0 10 Q159 -6 318 10 L318 122 Q159 138 0 122 Z" fill="#0f0a22"/>
    <path d="M8 16 Q159 2 310 16 L310 112 Q159 126 8 112 Z" fill="#2a124a"/>
    <path d="M8 70 Q159 60 310 70 L310 112 Q159 126 8 112 Z" fill="#1b0f3d"/>
    <circle cx="159" cy="64" r="24" fill="#ffd65c"/>${[0, 1, 2, 3].map(i => `<path d="M8 ${76 + i * 9} Q159 ${68 + i * 9} 310 ${76 + i * 9}" stroke="#ff4d8d" stroke-width="2" fill="none"/>`).join('')}
    <path d="M8 112 Q159 126 310 112" stroke="url(#cv)" stroke-width="4" fill="none"/>`];
  S.laptop = [208, 130, `<path d="M20 4 L188 4 L188 110 L20 110 Z" fill="#c9ccd6"/><rect x="28" y="12" width="152" height="90" fill="#160f30"/>
    <rect x="28" y="12" width="152" height="90" fill="#1e1440"/>${[0, 1, 2, 3, 4].map(i => `<rect x="40" y="${24 + i * 14}" width="${60 + ((i * 29) % 60)}" height="5" fill="${['#2ee6d6', '#c9b8ff', '#ff4d8d', '#ffd65c', '#c9b8ff'][i]}"/>`).join('')}
    <path d="M0 112 L208 112 L196 128 L12 128 Z" fill="#e8e6f2"/><rect x="84" y="114" width="40" height="4" fill="#9aa0b4"/>`];
  S.tablet = [98, 60, `<path d="M4 58 L94 58 L84 30 L14 30 Z" fill="#14102a"/><path d="M18 52 L80 52 L74 34 L22 34 Z" fill="#2a2350"/>
    <path d="M60 10 L74 48" stroke="#c9ccd6" stroke-width="4"/><circle cx="74" cy="48" r="2" fill="#2ee6d6"/><rect x="8" y="54" width="6" height="3" fill="#2ee6d6"/>`];
  // 키보드 · 마우스
  S.kb_white = kb('#f4f2fa', '#ffffff', false, `<rect x="80" y="20" width="16" height="22" rx="8" fill="#f4f2fa"/><rect x="87" y="22" width="2" height="7" fill="#c9b8ff"/>`);
  S.kb_mini = [98, 44, `<rect x="16" y="14" width="62" height="24" rx="3" fill="#2a2350"/>${[0, 1, 2, 3].map(r => [...Array(r == 3 ? 3 : 8)].map((_, c) => `<rect x="${r == 3 ? [19, 30, 66][c] : 19 + c * 7.2}" y="${17 + r * 5.3}" width="${r == 3 && c == 1 ? 32 : 5.4}" height="4" fill="${(r + c) % 5 == 0 ? '#ff4d8d' : '#c9b8ff'}"/>`).join('')).join('')}
    <rect x="84" y="22" width="12" height="18" rx="6" fill="#c9b8ff"/>`];
  S.mouse_gaming = [98, 40, `<defs>${RGB('mr')}</defs><rect x="4" y="30" width="90" height="8" rx="2" fill="#14102a"/><rect x="4" y="36" width="90" height="2" fill="url(#mr)"/>
    <path d="M40 30 Q40 6 54 6 Q68 6 68 30 Z" fill="#14102a"/><rect x="53" y="8" width="2" height="10" fill="#2ee6d6"/><path d="M42 26 L66 26" stroke="url(#mr)" stroke-width="2"/>`];
  S.mouse_vertical = [98, 56, `<path d="M34 56 L70 56 Q74 20 56 6 Q40 10 34 56 Z" fill="#4a4e69"/><path d="M56 6 Q62 26 60 56" stroke="#2a2350" stroke-width="3" fill="none"/>
    <rect x="46" y="22" width="6" height="10" rx="3" fill="#2ee6d6"/>`];
  // 조명
  S.monitor_bar = [98, 70, `<defs>${glow('bg', 5)}</defs><path d="M10 26 L88 26 L98 70 L0 70 Z" fill="#fff6d6" opacity=".18"/>
    <rect x="6" y="14" width="86" height="12" rx="5" fill="#2a2350"/><rect x="10" y="22" width="78" height="4" fill="#fff6d6" filter="url(#bg)"/><rect x="10" y="22" width="78" height="3" fill="#fffbe6"/>
    <rect x="44" y="26" width="10" height="8" fill="#2a2350"/><text x="49" y="60" font-size="9" fill="#9a94b8" text-anchor="middle" font-family="monospace">BAR</text>`];
  S.mood_lamp = [98, 110, `<defs>${glow('ml', 8)}<linearGradient id="mlg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ff4d8d"/><stop offset="1" stop-color="#7b5cff"/></linearGradient></defs>
    <ellipse cx="49" cy="50" rx="36" ry="44" fill="url(#mlg)" opacity=".5" filter="url(#ml)"/><path d="M32 96 L66 96 L60 18 Q49 6 38 18 Z" fill="url(#mlg)"/>
    <path d="M38 30 Q49 22 60 30" stroke="#fff" stroke-width="2" fill="none" opacity=".5"/><rect x="26" y="96" width="46" height="14" rx="3" fill="#2a2350"/>`];
  S.moon_lamp = [98, 110, `<defs>${glow('mo', 8)}</defs><circle cx="49" cy="48" r="38" fill="#ffe9a8" opacity=".4" filter="url(#mo)"/><circle cx="49" cy="48" r="32" fill="#fff4c9"/>
    <circle cx="38" cy="38" r="6" fill="#efe0a6"/><circle cx="60" cy="56" r="8" fill="#efe0a6"/><circle cx="56" cy="30" r="4" fill="#efe0a6"/>
    <path d="M30 102 L68 102 L60 80 L38 80 Z" fill="#8b5e3c"/><rect x="24" y="102" width="50" height="8" rx="2" fill="#6b4429"/>`];
  S.neon_heart = [98, 100, `<defs>${glow('nh', 5)}</defs><rect x="4" y="4" width="90" height="92" rx="6" fill="#120a26" opacity=".6"/>
    <g filter="url(#nh)"><path d="M49 78 L22 50 Q10 34 26 24 Q40 18 49 34 Q58 18 72 24 Q88 34 76 50 Z" stroke="#ff4d8d" stroke-width="8" fill="none"/></g>
    <path d="M49 78 L22 50 Q10 34 26 24 Q40 18 49 34 Q58 18 72 24 Q88 34 76 50 Z" stroke="#ffd0e2" stroke-width="3" fill="none"/>`];
  // 오디오
  S.speaker_bt = [98, 90, `<defs>${glow('sb', 4)}</defs><rect x="28" y="8" width="42" height="80" rx="18" fill="#2a2350"/>
    ${[0, 1, 2, 3, 4, 5, 6, 7].map(i => `<rect x="32" y="${18 + i * 7}" width="34" height="3" fill="#3b3170"/>`).join('')}
    <rect x="40" y="76" width="18" height="4" rx="2" fill="#2ee6d6" filter="url(#sb)"/><rect x="40" y="76" width="18" height="3" rx="1" fill="#2ee6d6"/>`];
  S.soundbar = [208, 40, `<defs>${RGB('sr')}</defs><rect x="4" y="10" width="200" height="26" rx="12" fill="#14102a"/>
    ${[...Array(30)].map((_, i) => `<circle cx="${18 + i * 6}" cy="23" r="1.6" fill="#3b3170"/>`).join('')}<rect x="20" y="34" width="168" height="3" fill="url(#sr)"/>`];
  S.mic_desk = [98, 110, `<ellipse cx="49" cy="104" rx="26" ry="6" fill="#2a2350"/><rect x="45" y="60" width="8" height="44" fill="#3b3170"/>
    <rect x="34" y="6" width="30" height="58" rx="15" fill="#c9ccd6"/>${[0, 1, 2, 3, 4, 5].map(i => `<rect x="38" y="${14 + i * 7}" width="22" height="2" fill="#9aa0b4"/>`).join('')}
    <rect x="34" y="50" width="30" height="5" fill="#ff4d8d"/>`];
  S.headphones = [98, 110, `<path d="M18 70 Q18 18 49 18 Q80 18 80 70" stroke="#e8e6f2" stroke-width="10" fill="none"/>
    <rect x="8" y="58" width="22" height="40" rx="9" fill="#e8e6f2"/><rect x="68" y="58" width="22" height="40" rx="9" fill="#e8e6f2"/>
    <rect x="12" y="64" width="14" height="28" rx="6" fill="#c9b8ff"/><rect x="72" y="64" width="14" height="28" rx="6" fill="#c9b8ff"/><rect x="40" y="102" width="18" height="6" rx="2" fill="#9aa0b4"/>`];
  S.turntable = [208, 80, `<rect x="4" y="40" width="200" height="38" rx="4" fill="#8b5e3c"/><rect x="4" y="40" width="200" height="6" fill="#a8774f"/>
    <ellipse cx="88" cy="40" rx="70" ry="14" fill="#14102a"/><ellipse cx="88" cy="40" rx="50" ry="10" fill="none" stroke="#2a2350" stroke-width="2"/>
    <ellipse cx="88" cy="40" rx="14" ry="4" fill="#ff4d8d"/><path d="M180 20 L180 34 L130 42" stroke="#c9ccd6" stroke-width="3" fill="none"/><circle cx="180" cy="20" r="6" fill="#c9ccd6"/>
    <circle cx="186" cy="62" r="5" fill="#2ee6d6"/>`];
  // 식물
  const pot = (c) => `<path d="M26 92 L72 92 L66 124 L32 124 Z" fill="${c}"/><rect x="22" y="86" width="54" height="10" fill="${c}"/>`;
  S.cactus = [98, 124, `${pot('#e76f51')}<rect x="38" y="30" width="22" height="58" rx="10" fill="#56b08a"/><rect x="20" y="48" width="12" height="26" rx="6" fill="#56b08a"/><rect x="26" y="66" width="14" height="8" fill="#56b08a"/>
    <rect x="66" y="40" width="12" height="24" rx="6" fill="#56b08a"/><rect x="58" y="56" width="12" height="8" fill="#56b08a"/><circle cx="49" cy="28" r="5" fill="#ff4d8d"/>
    ${[[42, 44], [54, 56], [44, 70], [24, 56], [70, 48]].map(([x, y]) => `<rect x="${x}" y="${y}" width="2" height="2" fill="#e8fffd"/>`).join('')}`];
  S.monstera = [98, 160, `${[[49, 96, -40], [49, 96, 0], [49, 96, 38], [49, 96, -72], [49, 96, 70]].map(([x, y, r], i) => `<g transform="rotate(${r} ${x} ${y})"><path d="M${x} ${y} L${x} ${y - 50}" stroke="#2c6b51" stroke-width="3"/>
      <ellipse cx="${x}" cy="${y - 72}" rx="${22 - i}" ry="26" fill="${i % 2 ? '#3f8f6e' : '#56b08a'}"/><path d="M${x - 14} ${y - 76} L${x - 4} ${y - 72} M${x + 14} ${y - 68} L${x + 4} ${y - 72} M${x - 12} ${y - 60} L${x - 3} ${y - 62}" stroke="#160f30" stroke-width="3"/></g>`).join('')}
    <path d="M26 128 L72 128 L66 160 L32 160 Z" fill="#2a2350"/><rect x="22" y="122" width="54" height="10" fill="#3b3170"/>`];
  S.terrarium = [98, 100, `<path d="M20 30 Q20 14 49 12 Q78 14 78 30 L82 92 L16 92 Z" fill="#9fe9ff" opacity=".25" stroke="#c9ecf5" stroke-width="2"/>
    <ellipse cx="49" cy="82" rx="30" ry="8" fill="#6b4429"/><path d="M34 80 Q30 60 38 52 Q44 64 40 80 M52 80 Q54 54 62 46 Q66 62 58 80" fill="#56b08a"/>
    <circle cx="66" cy="78" r="4" fill="#c9ccd6"/><rect x="14" y="92" width="70" height="6" rx="2" fill="#3b3170"/>`];
  S.moss_frame = [98, 104, `<rect x="6" y="4" width="86" height="96" fill="#8b5e3c"/><rect x="12" y="10" width="74" height="84" fill="#3f8f6e"/>
    ${[...Array(26)].map((_, i) => `<circle cx="${16 + (i * 29) % 66}" cy="${14 + (i * 17) % 76}" r="${5 + i % 4}" fill="${['#56b08a', '#68c49b', '#2c6b51'][i % 3]}"/>`).join('')}`];
  // 소품
  S.figure = [98, 110, `<defs>${glow('fg2', 3)}</defs><rect x="30" y="100" width="38" height="8" fill="#2a2350"/><rect x="38" y="60" width="22" height="40" rx="4" fill="#c9ccd6"/>
    <rect x="28" y="64" width="10" height="26" rx="4" fill="#9aa0b4"/><rect x="60" y="64" width="10" height="26" rx="4" fill="#9aa0b4"/>
    <rect x="34" y="24" width="30" height="34" rx="6" fill="#e8e6f2"/><rect x="38" y="34" width="22" height="12" rx="3" fill="#14102a"/>
    <rect x="42" y="38" width="5" height="4" fill="#2ee6d6" filter="url(#fg2)"/><rect x="51" y="38" width="5" height="4" fill="#2ee6d6" filter="url(#fg2)"/><rect x="47" y="14" width="4" height="10" fill="#9aa0b4"/><circle cx="49" cy="12" r="4" fill="#ff4d8d"/>`];
  S.block_ship = [98, 80, `<rect x="10" y="70" width="78" height="8" fill="#2a2350"/><rect x="46" y="54" width="6" height="16" fill="#3b3170"/>
    <path d="M8 44 L40 30 L80 30 L92 40 L80 50 L40 50 Z" fill="#e8e6f2"/><rect x="40" y="24" width="24" height="8" fill="#5b8db8"/><rect x="58" y="36" width="12" height="6" fill="#2ee6d6"/>
    <rect x="2" y="36" width="10" height="16" fill="#ff4d8d"/>${[16, 28, 40, 52, 64].map(x => `<rect x="${x}" y="27" width="6" height="3" fill="#c9ccd6"/>`).join('')}`];
  S.candle = [98, 80, `<defs>${glow('cd', 5)}</defs><ellipse cx="49" cy="26" rx="18" ry="22" fill="#ffd27a" opacity=".35" filter="url(#cd)"/>
    <rect x="32" y="38" width="34" height="40" rx="4" fill="#f4f0ff"/><rect x="32" y="52" width="34" height="10" fill="#c9b8ff"/><path d="M49 20 Q44 30 49 36 Q54 30 49 20" fill="#ffd27a"/><rect x="48" y="34" width="2" height="6" fill="#2a2350"/>`];
  S.diffuser = [98, 110, `<path d="M36 110 L62 110 L66 76 Q49 68 32 76 Z" fill="#c9b8ff" opacity=".6"/><rect x="44" y="62" width="10" height="14" fill="#2a2350"/>
    ${[-20, -8, 4, 14].map((r, i) => `<path d="M49 66 L${49 + Math.sin(r * Math.PI / 180) * 60} ${66 - Math.cos(r * Math.PI / 180) * 60}" stroke="#8b5e3c" stroke-width="2"/>`).join('')}`];
  S.desk_clock = [98, 60, `<rect x="16" y="10" width="66" height="44" rx="6" fill="#2a2350"/><rect x="22" y="16" width="25" height="32" rx="2" fill="#14102a"/><rect x="51" y="16" width="25" height="32" rx="2" fill="#14102a"/>
    <text x="34" y="40" font-size="20" fill="#ffd65c" text-anchor="middle" font-family="monospace">2</text><text x="63" y="40" font-size="20" fill="#ffd65c" text-anchor="middle" font-family="monospace">3</text>
    <rect x="22" y="31" width="54" height="2" fill="#2a2350"/><rect x="24" y="54" width="10" height="6" fill="#14102a"/><rect x="64" y="54" width="10" height="6" fill="#14102a"/>`];
  S.calendar = [98, 70, `<path d="M18 68 L80 68 L74 10 L24 10 Z" fill="#f4f0ff"/><rect x="24" y="10" width="50" height="12" fill="#ff4d8d"/>
    ${[...Array(15)].map((_, i) => `<rect x="${28 + (i % 5) * 9}" y="${28 + Math.floor(i / 5) * 10}" width="6" height="6" fill="${i == 7 ? '#ff4d8d' : '#c9b8ff'}"/>`).join('')}
    <rect x="30" y="4" width="3" height="10" fill="#9aa0b4"/><rect x="64" y="4" width="3" height="10" fill="#9aa0b4"/>`];
  S.pen_holder = [98, 90, `<rect x="30" y="44" width="38" height="46" rx="4" fill="#2a2350"/><rect x="30" y="44" width="38" height="6" fill="#3b3170"/>
    <rect x="36" y="10" width="4" height="40" fill="#ff4d8d" transform="rotate(-8 38 30)"/><rect x="46" y="4" width="4" height="46" fill="#2ee6d6"/><rect x="56" y="14" width="4" height="36" fill="#ffd65c" transform="rotate(10 58 32)"/>
    <rect x="40" y="62" width="18" height="2" fill="#7b5cff"/>`];
  S.photo = [98, 90, `<path d="M20 86 L78 86 L74 12 L24 12 Z" fill="#8b5e3c"/><rect x="28" y="18" width="42" height="56" fill="#bfd7ea"/>
    <circle cx="44" cy="40" r="7" fill="#ffd65c"/><path d="M28 74 L40 54 L50 64 L58 56 L70 74 Z" fill="#6a9c78"/><circle cx="58" cy="38" r="5" fill="#ff4d8d"/>`];
  S.globe = [98, 120, `<circle cx="49" cy="48" r="34" fill="#5b8db8"/><path d="M30 30 Q40 24 46 34 Q38 44 30 40 Z M54 52 Q66 46 72 58 Q62 70 52 64 Z M40 60 Q46 58 48 66 Q42 72 38 68 Z" fill="#56b08a"/>
    <path d="M14 48 Q14 92 49 92" stroke="#c9ccd6" stroke-width="3" fill="none"/><rect x="46" y="92" width="6" height="16" fill="#c9ccd6"/><ellipse cx="49" cy="112" rx="22" ry="6" fill="#2a2350"/>`];
  S.gamepad = [98, 80, `<defs>${RGB('gp')}</defs><path d="M18 74 L80 74 L72 52 L26 52 Z" fill="#2a2350"/><rect x="26" y="70" width="46" height="3" fill="url(#gp)"/>
    <path d="M14 34 Q14 14 34 16 L64 16 Q84 14 84 34 Q86 52 74 52 Q66 52 62 42 L36 42 Q32 52 24 52 Q12 52 14 34 Z" fill="#e8e6f2"/>
    <rect x="24" y="26" width="14" height="4" fill="#2a2350"/><rect x="29" y="21" width="4" height="14" fill="#2a2350"/>
    <circle cx="66" cy="24" r="3" fill="#ff4d8d"/><circle cx="72" cy="30" r="3" fill="#2ee6d6"/><circle cx="60" cy="30" r="3" fill="#ffd65c"/><circle cx="66" cy="36" r="3" fill="#7b5cff"/>`];
  // 벽 장식
  const poster = (inner) => [98, 124, `<rect x="8" y="4" width="82" height="116" fill="#f4f0ff"/><rect x="12" y="8" width="74" height="108" fill="#14102a"/>${inner}`];
  S.poster_game = poster(`<rect x="12" y="8" width="74" height="108" fill="#1b0f3d"/>${[[20, 20], [70, 30], [40, 50], [26, 80], [66, 90]].map(([x, y]) => `<rect x="${x}" y="${y}" width="2" height="2" fill="#fff"/>`).join('')}
    <path d="M49 40 L60 70 L49 64 L38 70 Z" fill="#2ee6d6"/><rect x="45" y="70" width="8" height="8" fill="#ff4d8d"/><rect x="20" y="96" width="58" height="10" fill="#ff4d8d"/>`);
  S.poster_city = poster(`<rect x="12" y="8" width="74" height="60" fill="#ffb3c6"/><circle cx="49" cy="54" r="18" fill="#ffd65c"/><rect x="12" y="62" width="74" height="54" fill="#5b8db8"/>
    ${[0, 1, 2].map(i => `<rect x="12" y="${70 + i * 10}" width="74" height="2" fill="#9fe9ff"/>`).join('')}<path d="M70 116 L72 70 M72 70 Q60 60 56 66 M72 70 Q84 60 88 68 M72 70 Q70 56 64 54" stroke="#14102a" stroke-width="3" fill="none"/>`);
  S.shelf_white = [208, 130, `<rect x="20" y="66" width="24" height="34" fill="#e8e6f2"/><path d="M24 66 Q32 40 40 66" fill="#56b08a"/><rect x="60" y="76" width="18" height="24" rx="9" fill="#c9b8ff"/>
    <rect x="96" y="70" width="40" height="30" fill="#f4f0ff"/><rect x="100" y="74" width="32" height="22" fill="#bfd7ea"/><circle cx="160" cy="88" r="12" fill="#ffd65c"/><rect x="176" y="62" width="12" height="38" fill="#e8e6f2"/>
    <rect x="0" y="100" width="208" height="12" fill="#f4f0ff"/><rect x="0" y="100" width="208" height="3" fill="#ffffff"/><path d="M26 112 L26 128 L42 112 Z M182 112 L182 128 L166 112 Z" fill="#cfcbe0"/>`];
  S.cork = [98, 104, `<rect x="6" y="4" width="86" height="96" fill="#8b5e3c"/><rect x="12" y="10" width="74" height="84" fill="#c9965f"/>
    <rect x="18" y="16" width="26" height="22" fill="#ffd65c" transform="rotate(-6 31 27)"/><rect x="52" y="20" width="28" height="20" fill="#f4f0ff"/><rect x="22" y="52" width="30" height="24" fill="#bfd7ea" transform="rotate(5 37 64)"/>
    <rect x="58" y="56" width="22" height="26" fill="#ff8fb3"/>${[[30, 18], [66, 22], [36, 54], [69, 58]].map(([x, y]) => `<circle cx="${x}" cy="${y}" r="3" fill="#ff4d8d"/>`).join('')}`];
  S.whiteboard = [208, 120, `<rect x="4" y="4" width="200" height="104" fill="#c9ccd6"/><rect x="10" y="10" width="188" height="92" fill="#f8f8fc"/>
    <path d="M24 30 L90 30 M24 46 L120 46 M24 62 L70 62" stroke="#5b8db8" stroke-width="3"/><path d="M130 28 L180 28 L180 78 L130 78 Z" stroke="#ff4d8d" stroke-width="3" fill="none"/>
    <path d="M140 52 L152 64 L172 38" stroke="#6a9c78" stroke-width="4" fill="none"/><rect x="40" y="108" width="128" height="6" fill="#9aa0b4"/><rect x="60" y="104" width="16" height="4" fill="#ff4d8d"/>`];
  S.wall_clock = [98, 98, `<circle cx="49" cy="49" r="44" fill="#14102a"/><circle cx="49" cy="49" r="38" fill="#f4f0ff"/>
    ${[...Array(12)].map((_, i) => `<rect x="48" y="14" width="2" height="6" fill="#2a2350" transform="rotate(${i * 30} 49 49)"/>`).join('')}
    <path d="M49 49 L49 24" stroke="#2a2350" stroke-width="4"/><path d="M49 49 L66 58" stroke="#ff4d8d" stroke-width="3"/><circle cx="49" cy="49" r="3" fill="#2a2350"/>`];
  S.pegboard = [208, 124, `<rect x="4" y="4" width="200" height="116" fill="#2a2350"/>${[...Array(9)].map((_, r) => [...Array(19)].map((_, c) => `<circle cx="${14 + c * 10.4}" cy="${14 + r * 12.4}" r="1.5" fill="#14102a"/>`).join('')).join('')}
    <path d="M30 20 L30 34 M24 34 Q24 64 46 64 M36 34 Q36 58 46 58" stroke="#9aa0b4" stroke-width="3" fill="none"/><path d="M60 26 Q60 10 80 10 Q100 10 100 26" stroke="#e8e6f2" stroke-width="6" fill="none"/>
    <rect x="56" y="24" width="10" height="18" rx="4" fill="#e8e6f2"/><rect x="94" y="24" width="10" height="18" rx="4" fill="#e8e6f2"/>
    <rect x="130" y="30" width="50" height="8" fill="#ffd65c"/><rect x="130" y="50" width="24" height="40" fill="#ff4d8d"/><rect x="160" y="60" width="26" height="30" fill="#56b08a"/>`];
  // 부품
  S.case4 = tower('#e8e6f2', '#9fe9ff22', '#ff4d8d', `<rect x="2" y="2" width="156" height="12" fill="#c9ccd6"/><rect x="12" y="14" width="140" height="226" fill="#9fe9ff" opacity=".12"/>`);
  S.case5 = tower('#2a2350', '#120a26', '#ffd65c', `<rect x="122" y="14" width="34" height="226" fill="#8b5e3c"/>${[0, 1, 2, 3, 4, 5, 6, 7].map(i => `<rect x="126" y="${20 + i * 28}" width="26" height="2" fill="#a8774f"/>`).join('')}`);
  S.part_SSD = [64, 64, `<rect x="6" y="24" width="52" height="16" rx="2" fill="#2c6b51"/><rect x="12" y="27" width="14" height="10" fill="#14102a"/><rect x="30" y="27" width="14" height="10" fill="#14102a"/>
    <rect x="48" y="28" width="6" height="8" fill="#c9ccd6"/>${[0, 1, 2, 3, 4].map(i => `<rect x="${8 + i * 3}" y="38" width="2" height="2" fill="#ffd65c"/>`).join('')}<text x="32" y="54" font-size="9" fill="#2ee6d6" text-anchor="middle" font-family="monospace">M.2</text>`];
};
