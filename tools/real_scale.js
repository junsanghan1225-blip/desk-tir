// Godot용 '실제 비율' 정면 그림: 그림 속 물건의 너비가 items.json foot(cm) x 5.5px 이 되게 다시 그림 → resource/real/<이름>.png
// (pico2d 버전은 칸 배치라 원래 크기 그림을 그대로 씀)
const sharp = require('sharp'), path = require('path'), fs = require('fs');
const ITEMS = require('../data/items.json');
const UNIT = 5.5;
const OUT = path.join(__dirname, '..', 'resource', 'real');
fs.mkdirSync(OUT, { recursive: true });

module.exports = async (name, w, h, body, tints = 0) => {
  const it = ITEMS.find(i => i.id === name);
  if (!it || it.layer !== 'desk' || !it.foot) return;
  const svg = (W, H) => Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${w} ${h}" preserveAspectRatio="none">${body}</svg>`);
  const { info } = await sharp(svg(w, h)).trim({ threshold: 1 }).toBuffer({ resolveWithObject: true });   // 그림 속 물건의 실제 너비
  const k = it.foot[0] * UNIT / info.width;
  const ky = it.fh ? it.fh * UNIT / info.height : k;   // fh: 정면에서 보이는 높이(cm). 키보드처럼 납작한 물건
  const W = Math.round(w * k), H = Math.round(h * ky);
  const small = await sharp(svg(W, H)).resize(Math.ceil(W / 2), Math.ceil(H / 2), { kernel: 'nearest' }).png().toBuffer();
  await sharp(small).resize(W, H, { kernel: 'nearest' }).png().toFile(path.join(OUT, name + '.png'));
  for (let c = 1; c <= tints; c++)
    await sharp(small).modulate({ hue: 90 * c }).resize(W, H, { kernel: 'nearest' }).png().toFile(path.join(OUT, `${name}__c${c}.png`));
};
