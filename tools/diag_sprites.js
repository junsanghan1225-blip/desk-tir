// 진단 화면 그림: 본체 뒷면(diag_back), 그래픽카드 브래킷(diag_gpu_bracket). node tools/diag_sprites.js
// 좌표는 diag.gd의 단자 위치와 맞물림 (뒷면 그림 560x560을 게임 좌표 [300, 50, 860, 610]에 놓음)
const sharp = require('sharp'), path = require('path');
const OUT = path.join(__dirname, '..', 'resource');
const screws = (pts) => pts.map(([x, y]) => `<circle cx="${x}" cy="${y}" r="5" fill="#8a87a0"/><path d="M${x - 3} ${y} L${x + 3} ${y} M${x} ${y - 3} L${x} ${y + 3}" stroke="#4a4860" stroke-width="1.5"/>`).join('');
const vents = (x, y, w, h, n) => [...Array(n)].map((_, i) => `<rect x="${x + 4}" y="${y + 3 + i * (h - 6) / n}" width="${w - 8}" height="${(h - 6) / n * .45}" rx="1" fill="#0b0916"/>`).join('');
const grille = (cx, cy, r) => [...Array(5)].map((_, i) => `<circle cx="${cx}" cy="${cy}" r="${r - i * r / 5}" fill="none" stroke="#5a5672" stroke-width="2.5"/>`).join('') +
  [0, 1, 2, 3].map(i => `<path d="M${cx + Math.cos(i * .785) * r} ${cy + Math.sin(i * .785) * r} L${cx - Math.cos(i * .785) * r} ${cy - Math.sin(i * .785) * r}" stroke="#5a5672" stroke-width="2.5"/>`).join('');
const port = (x, y, w, h, body, inner) => `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="1" fill="#c9ccd6"/><rect x="${x + 2}" y="${y + 2}" width="${w - 4}" height="${h - 4}" fill="${body}"/>${inner || ''}`;

const S = {
  diag_back: [560, 560, `<rect x="0" y="0" width="560" height="560" rx="10" fill="#1d1834"/><rect x="6" y="6" width="548" height="548" rx="8" fill="#241e40"/>
    <rect x="6" y="6" width="548" height="6" fill="#3b3466"/>${screws([[22, 22], [538, 22], [22, 538], [538, 538]])}
    <!-- 메인보드 뒷단자 (I/O 실드) -->
    <rect x="40" y="30" width="130" height="250" rx="3" fill="#3a3a48"/><rect x="44" y="34" width="122" height="242" fill="#4a4a5a"/>
    ${port(60, 46, 40, 18, '#1f5bd1', '<rect x="66" y="52" width="28" height="5" fill="#e8e6f2"/>')}${port(110, 46, 40, 18, '#1f5bd1', '<rect x="116" y="52" width="28" height="5" fill="#e8e6f2"/>')}
    ${port(60, 74, 40, 18, '#1f5bd1', '<rect x="66" y="80" width="28" height="5" fill="#e8e6f2"/>')}${port(110, 74, 40, 18, '#1f5bd1', '<rect x="116" y="80" width="28" height="5" fill="#e8e6f2"/>')}
    ${port(60, 104, 40, 28, '#1a1a22', '<rect x="66" y="108" width="28" height="12" fill="#2a2a34"/><rect x="62" y="104" width="6" height="4" fill="#ffd65c"/><rect x="92" y="104" width="6" height="4" fill="#56b08a"/>')}
    <path d="M60 148 L120 148 L120 162 L114 168 L66 168 L60 162 Z" fill="#c9ccd6"/><path d="M63 151 L117 151 L117 161 L112 165 L68 165 L63 161 Z" fill="#14121c"/>
    <path d="M60 180 L120 180 L120 198 L68 198 L60 192 Z" fill="#c9ccd6"/><path d="M63 183 L117 183 L117 195 L69 195 L63 190 Z" fill="#14121c"/>
    ${port(60, 212, 40, 18, '#14121c', '<rect x="66" y="218" width="28" height="5" fill="#8a87a0"/>')}${port(110, 212, 40, 18, '#14121c', '<rect x="116" y="218" width="28" height="5" fill="#8a87a0"/>')}
    ${[['#56b08a', 72], ['#ff8fb4', 105], ['#6fa8ff', 138]].map(([c, x]) => `<circle cx="${x}" cy="252" r="11" fill="${c}"/><circle cx="${x}" cy="252" r="5" fill="#14121c"/>`).join('')}
    <!-- 뒷면 팬 -->
    <rect x="250" y="56" width="168" height="168" rx="6" fill="#16131f"/>${screws([[262, 68], [406, 68], [262, 212], [406, 212]])}
    <circle cx="334" cy="140" r="78" fill="#0b0916"/>${grille(334, 140, 78)}
    <!-- 확장 슬롯 덮개 7칸 -->
    <rect x="200" y="282" width="330" height="178" fill="#16131f"/>
    ${[...Array(7)].map((_, i) => `<rect x="210" y="${290 + i * 24}" width="310" height="18" fill="#3a3a48"/>${vents(236, 290 + i * 24, 270, 18, 2)}<circle cx="218" cy="${299 + i * 24}" r="3" fill="#8a87a0"/>`).join('')}
    <!-- 파워 -->
    <rect x="40" y="440" width="480" height="100" rx="4" fill="#16131f"/><rect x="44" y="444" width="472" height="92" fill="#1f1b2c"/>${screws([[54, 454], [506, 454], [54, 526], [506, 526]])}
    <circle cx="160" cy="490" r="42" fill="#0b0916"/>${grille(160, 490, 42)}
    <rect x="292" y="464" width="62" height="52" rx="4" fill="#0b0916"/><path d="M300 472 L346 472 L346 500 L336 508 L310 508 L300 500 Z" fill="#14121c" stroke="#5a5672" stroke-width="2"/>
    ${[[312, 482], [334, 482], [323, 496]].map(([x, y]) => `<rect x="${x - 3}" y="${y - 5}" width="6" height="10" fill="#8a87a0"/>`).join('')}
    <rect x="372" y="462" width="56" height="56" rx="4" fill="#0b0916"/>
    <rect x="446" y="470" width="58" height="40" fill="#e8e6f2"/><rect x="450" y="476" width="50" height="4" fill="#9aa0b4"/><rect x="450" y="486" width="36" height="4" fill="#9aa0b4"/><rect x="450" y="496" width="44" height="4" fill="#9aa0b4"/>`],
  diag_gpu_bracket: [310, 46, `<rect x="0" y="0" width="310" height="46" fill="#c9ccd6"/><rect x="0" y="0" width="310" height="4" fill="#e8e6f2"/>
    ${vents(150, 4, 150, 40, 3)}<circle cx="8" cy="23" r="4" fill="#8a87a0"/>
    ${[30, 72, 114].map(x => `<path d="M${x} 16 L${x + 36} 16 L${x + 36} 30 L${x + 8} 30 L${x} 24 Z" fill="#14121c" stroke="#5a5672" stroke-width="2"/>`).join('')}`],
};
(async () => {
  for (const [name, [w, h, body]] of Object.entries(S)) {
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">${body}</svg>`;
    const small = await sharp(Buffer.from(svg)).resize(Math.ceil(w / 2), Math.ceil(h / 2), { kernel: 'nearest' }).png().toBuffer();
    await sharp(small).resize(w, h, { kernel: 'nearest' }).png().toFile(path.join(OUT, name + '.png'));
  }
  console.log(Object.keys(S).length, 'diag sprites');
})();
