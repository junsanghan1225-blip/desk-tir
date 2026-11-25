// 키보드를 정면(앞)에서 본 실제 모습: 얇은 몸통 + 키캡 줄이 살짝 보임 (위에서 본 그림을 눌러 놓은 게 아니라)
// → resource/real/<id>.png (Godot 정면 뷰 전용, 실제 크기 cm x 5.5). 실행: node tools/profile_sprites.js
const sharp = require('sharp'), path = require('path');
const ITEMS = require('../data/items.json');
const OUT = path.join(__dirname, '..', 'resource', 'real');
const UNIT = 5.5;
const PINK = '#ff4d8d', CYAN = '#2ee6d6';
// [몸통, 몸통 윗면, 키캡, 키캡 윗면, 밑빛(RGB면 true)]
const KB = {
  keyboard: ['#9aa0b4', '#c9ccd6', '#e8e8f0', '#ffffff', false],
  gaming_kb: ['#0f0a22', '#1c1830', '#1c1830', '#3e3760', true],
  kb_white: ['#e0dfea', '#f4f2fa', '#ffffff', '#ffffff', false],
  kb_mini: ['#3b3466', '#5a4fa0', '#c9b8ff', '#e8e0ff', false],
};
const body = (W, H, [b, bt, k, kt, rgb]) => {
  const base = H * .42, cap = H * .3;
  const n = Math.round(W / 9);
  const kw = W / n;
  let s = `<defs><linearGradient id="rg" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="${PINK}"/><stop offset=".5" stop-color="#7b5cff"/><stop offset="1" stop-color="${CYAN}"/></linearGradient></defs>`;
  if (rgb) s += `<rect x="2" y="${H - 3}" width="${W - 4}" height="3" fill="url(#rg)" opacity=".8"/>`;
  s += `<rect x="0" y="${H - base}" width="${W}" height="${base - 2}" rx="2" fill="${b}"/><rect x="0" y="${H - base}" width="${W}" height="2" fill="${bt}"/>`;
  for (let r = 0; r < 2; r++)   // 뒷줄이 살짝 높게 보임 (키보드는 뒤가 높게 기울어짐)
    for (let i = 0; i < n; i++) {
      const x = i * kw + 1 + (r ? kw / 2 : 0), y = H - base - cap * (r ? 1.55 : 1) + 1;
      if (x + kw - 2 > W) continue;
      s += `<rect x="${x}" y="${y}" width="${kw - 2}" height="${cap}" rx="1" fill="${k}"/><rect x="${x}" y="${y}" width="${kw - 2}" height="1.5" fill="${kt}"/>`;
    }
  if (rgb) s += [...Array(n)].map((_, i) => `<rect x="${i * kw + 2}" y="${H - base - 1}" width="${kw - 4}" height="1" fill="url(#rg)"/>`).join('');
  return s;
};
(async () => {
  for (const [id, pal] of Object.entries(KB)) {
    const it = ITEMS.find(i => i.id === id);
    const W = Math.round(it.foot[0] * UNIT), H = Math.round((it.fh || 4) * UNIT);
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${body(W, H, pal)}</svg>`;
    const small = await sharp(Buffer.from(svg)).resize(Math.ceil(W / 2), Math.ceil(H / 2), { kernel: 'nearest' }).png().toBuffer();
    await sharp(small).resize(W, H, { kernel: 'nearest' }).png().toFile(path.join(OUT, id + '.png'));
    if (it.tint) for (let c = 1; c <= 3; c++) await sharp(small).modulate({ hue: 90 * c }).resize(W, H, { kernel: 'nearest' }).png().toFile(path.join(OUT, `${id}__c${c}.png`));
  }
  console.log(Object.keys(KB).length, 'keyboard profiles');
})();
