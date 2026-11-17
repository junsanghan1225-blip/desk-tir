// 붙는 소품의 정면 그림 (Godot 전용, 실제 비율): 모니터 위 라이트바 · 모니터에 끼운 웹캠 · 책상 앞 모서리에 거는 헤드셋 걸이.
// → resource/real/ (pico2d는 책상 위에 세우는 원래 그림을 그대로 씀).  실행: node tools/mount_sprites.js
const real = require('./real_scale');
const CYAN = '#2ee6d6', PINK = '#ff4d8d';
const S = {
  // 라이트바: 모니터 윗변에 걸쳐 앉고(아래 14px가 모니터 위로 내려옴), 빛이 화면 쪽으로 떨어짐
  monitor_bar: [120, 34, `<defs><linearGradient id="cone" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#e8f6ff" stop-opacity=".45"/><stop offset="1" stop-color="#e8f6ff" stop-opacity="0"/></linearGradient></defs>
    <path d="M12 14 L108 14 L120 34 L0 34 Z" fill="url(#cone)"/>
    <rect x="50" y="12" width="20" height="10" fill="#1c1830"/>
    <rect x="6" y="3" width="108" height="11" rx="4" fill="#2a2440"/><rect x="6" y="3" width="108" height="3" rx="2" fill="#4a4370"/>
    <rect x="10" y="11" width="100" height="3" fill="#ffffff"/><rect x="102" y="6" width="4" height="3" fill="${CYAN}"/>`],
  // 웹캠: 몸통은 모니터 위, 집게(아래 14px)가 모니터 윗변을 물고 있음
  webcam: [56, 40, `<rect x="21" y="24" width="14" height="16" fill="#2a2440"/><rect x="21" y="36" width="14" height="4" fill="#1c1830"/>
    <rect x="6" y="3" width="44" height="22" rx="9" fill="#1c1830"/><rect x="6" y="3" width="44" height="5" rx="4" fill="#3e3760"/>
    <circle cx="28" cy="14" r="8" fill="#2a2440"/><circle cx="28" cy="14" r="5" fill="#3a7ac8"/><circle cx="26" cy="12" r="2" fill="#cfefff"/>
    <rect x="41" y="8" width="4" height="4" fill="${PINK}"/>`],
  // 헤드셋 걸이: 맨 위 집게가 책상 상판 앞 모서리를 물고, 걸이에 헤드셋이 매달림
  headset: [72, 132, `<defs><linearGradient id="hb" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="${PINK}"/><stop offset=".5" stop-color="#7b5cff"/><stop offset="1" stop-color="${CYAN}"/></linearGradient></defs>
    <rect x="22" y="0" width="28" height="7" fill="#4a4370"/><rect x="22" y="7" width="6" height="12" fill="#4a4370"/><rect x="22" y="16" width="28" height="5" fill="#3e3760"/><rect x="40" y="21" width="5" height="6" fill="#8a84a8"/>
    <rect x="33" y="21" width="6" height="16" fill="#5a4fa0"/><rect x="20" y="34" width="32" height="6" rx="3" fill="#5a4fa0"/>
    <path d="M13 104 Q13 36 36 36 Q59 36 59 104" stroke="#4a4370" stroke-width="8" fill="none"/>
    <path d="M13 104 Q13 40 36 40 Q59 40 59 104" stroke="url(#hb)" stroke-width="2" fill="none"/>
    <rect x="3" y="92" width="20" height="38" rx="9" fill="#1c1830"/><rect x="9" y="99" width="5" height="24" fill="${PINK}"/>
    <rect x="49" y="92" width="20" height="38" rx="9" fill="#1c1830"/><rect x="58" y="99" width="5" height="24" fill="${CYAN}"/>`],
};
(async () => {
  for (const [name, [w, h, body]] of Object.entries(S)) {
    await real(name, w, h, body);
  }
  console.log(Object.keys(S).length, 'mount sprites');
})();
