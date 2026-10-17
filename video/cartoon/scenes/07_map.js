// Сцена 7 «Карта»: старый боб подходит к героям и разворачивает свиток; камера ныряет в карту —
// путь пунктиром проходит через все миры игры до замка призраков на облаках.
B.addScene({
  id: "map",
  dur: 8,
  init(S) {
    const { el, f1, clamp, seg, lerp, E, K, tr, show, NAVY, makeBean, poseBean, crownShape } = B;
    const P = B.square(S, "day", { lit: false });
    B.sun(S.L.sky, 1500, 40, 80);
    for (const [x, y, s] of [[200, 160, 1.2], [1100, 70, 0.9], [1750, 280, 1.1]]) B.cloud(S.L.sky, x, y, s, P.pal);
    const mid = S.L.mid;
    const cast = el("g", {}, mid);
    const grandpa = makeBean(cast, "grandpa", { acc: "grandpa", shadow: "#6a4a20", rim: "#fff6c8" });
    const H = [{ c: "red", x: 1060 }, { c: "blue", x: 1180 }, { c: "yellow", acc: "bow", x: 1290 }, { c: "green", x: 1400 }];
    for (const h of H) { h.b = makeBean(cast, h.c, { acc: h.acc, shadow: "#6a4a20", rim: "#fff6c8" }); h.s = h.c === "yellow" ? 1.3 : 1.6; }
    crownShape(el("g", { transform: "translate(-4 -44) rotate(-12) scale(1.1)" }, H[0].b.hold));

    // ── Карта: рисунок в своих координатах 1600×1000, в мире — 400×250 (масштаб 0.25) у рук старика.
    const MAP_X = 880, MAP_Y = 470, MS = 0.25;
    const map = el("g", {}, mid);
    const sheet = el("g", {}, map);
    const art = el("g", {}, sheet);
    el("rect", { x: 0, y: 0, width: 1600, height: 1000, rx: 18, fill: "url(#paper)", stroke: "#8a5a2a", "stroke-width": 10 }, art);
    el("path", { d: "M1180 40 Q 1300 120 1560 90 L1560 600 Q 1420 520 1300 560 Q 1180 600 1100 520 Q 1020 420 1180 40Z", fill: "#bfe3f0", stroke: "#8a5a2a", "stroke-width": 5, opacity: 0.85 }, art);
    for (const [x, y, s] of [[1250, 160, 0.7], [1420, 300, 0.55]]) {
      const g = el("g", { transform: `translate(${x} ${y}) scale(${s})` }, art);
      for (const [cx, cy, r] of [[0, 0, 60], [70, -25, 70], [150, 0, 55]]) el("circle", { cx, cy, r, fill: "#ffffff", stroke: "#8a5a2a", "stroke-width": 6 }, g);
    }
    for (let i = 0; i < 40; i++) { const rr = B.rng(i + 1); el("circle", { cx: f1(rr() * 1600), cy: f1(rr() * 1000), r: 3, fill: "#c9a46a", opacity: 0.5 }, art); }
    // Значки миров: [x, y, рисунок].
    const icon = (x, y, draw) => { const g = el("g", { transform: `translate(${x} ${y})` }, art); draw(g); return g; };
    const ink = { stroke: "#5a3a1a", "stroke-width": 6, "stroke-linejoin": "round" };
    const ICONS = [
      [110, 880, (g) => { // Царство бобов — маленький замок
        el("rect", { x: -50, y: -60, width: 100, height: 60, fill: "#f3e2c4", ...ink }, g);
        for (const [x, c] of [[-35, "#e84a3f"], [0, "#3a7fe6"], [35, "#f7c531"]]) el("path", { d: `M${x - 18} -60 Q ${x} -110 ${x + 18} -60Z`, fill: c, ...ink }, g);
      }],
      [330, 740, (g) => { // 1. Забытые мосты — скалы, арка и мост
        for (const x of [-90, 90]) el("path", { d: `M${x - 45} -20 L${x + 45} -20 L${x + 20} 70 L${x - 20} 70Z`, fill: "#a6a2b8", ...ink }, g);
        el("path", { d: "M-130 -60 L-130 -20 L-110 -20 L-110 -50 Q -90 -78 -70 -50 L-70 -20 L-50 -20 L-50 -60 Q -90 -110 -130 -60Z", fill: "#c4bfd4", ...ink }, g);
        el("path", { d: "M-45 -20 Q 0 20 45 -20", fill: "none", ...ink }, g);
        for (let k = -3; k <= 3; k++) el("rect", { x: k * 12 - 4, y: Math.abs(k) * -5 - 4, width: 8, height: 8, fill: "#9a6a3c" }, g);
      }],
      [610, 560, (g) => { // 2. Мастерские — шестерня и труба
        el("rect", { x: -60, y: -40, width: 90, height: 80, fill: "#d9785a", ...ink }, g);
        el("rect", { x: 10, y: -100, width: 22, height: 60, fill: "#8a6a5a", ...ink }, g);
        const gear = el("g", { transform: "translate(50 30)" }, g);
        for (let k = 0; k < 8; k++) el("rect", { x: -8, y: -48, width: 16, height: 20, fill: "#f0b43a", ...ink, transform: `rotate(${k * 45})` }, gear);
        el("circle", { r: 34, fill: "#f0b43a", ...ink }, gear); el("circle", { r: 12, fill: "#8a6a5a", ...ink }, gear);
      }],
      [880, 760, (g) => { // 3. Стражи — статуя-боб на постаменте и кусты
        el("rect", { x: -40, y: 10, width: 80, height: 40, fill: "#c4bfd4", ...ink }, g);
        el("path", { d: "M0 -90 C 30 -90 38 -60 34 -30 C 30 0 20 10 0 10 C -20 10 -34 0 -34 -30 C -38 -60 -30 -90 0 -90Z", fill: "#b8b4c8", ...ink }, g);
        for (const x of [-90, 90]) el("circle", { cx: x, cy: 30, r: 34, fill: "#5aa84e", ...ink }, g);
      }],
      [1150, 520, (g) => { // 4. Затопленный город — башни в воде
        for (const [x, h] of [[-50, 110], [0, 150], [50, 90]]) { el("rect", { x: x - 18, y: -h, width: 36, height: h, fill: "#8fb0c8", ...ink }, g); el("path", { d: `M${x - 22} ${-h} Q ${x} ${-h - 34} ${x + 22} ${-h}Z`, fill: "#3a8db0", ...ink }, g); }
        el("path", { d: "M-100 -10 q 25 -16 50 0 q 25 16 50 0 q 25 -16 50 0 q 25 16 50 0", fill: "none", stroke: "#2f78a8", "stroke-width": 8 }, g);
      }],
      [820, 330, (g) => { // 5. Ледяные вершины — снежные горы
        el("path", { d: "M-130 60 L-50 -80 L10 20 L70 -110 L150 60Z", fill: "#a8c4e0", ...ink }, g);
        el("path", { d: "M-74 -40 L-50 -80 L-28 -42 L-44 -30Z M44 -66 L70 -110 L96 -62 L72 -50Z", fill: "#ffffff", ...ink }, g);
      }],
      [1300, 200, (g) => { // 6. Небесная кузница — замок призраков на парящем острове
        el("path", { d: "M-120 40 L120 40 L40 140 L-30 150Z", fill: "#8a7a9a", ...ink }, g);
        el("rect", { x: -80, y: -60, width: 160, height: 100, fill: "#5a4a7a", ...ink }, g);
        for (const [x, h] of [[-80, 130], [0, 180], [80, 130]]) { el("rect", { x: x - 22, y: -h + 40, width: 44, height: h - 40, fill: "#5a4a7a", ...ink }, g); el("path", { d: `M${x - 28} ${-h + 40} L${x} ${-h} L${x + 28} ${-h + 40}Z`, fill: "#3a2d5a", ...ink }, g); }
        el("path", { d: "M0 -140 L0 -200 M0 -200 Q 30 -190 50 -200 Q 30 -180 0 -184", fill: "#ffffff", ...ink }, g);
        el("circle", { cx: 0, cy: 0, r: 16, fill: "#ffd27a", ...ink }, g);
      }],
    ];
    const icons = ICONS.map(([x, y, draw]) => ({ x, y, g: icon(x, y, draw) }));
    // Пунктир пути через значки.
    const pathPts = [];
    for (let i = 0; i < icons.length - 1; i++) {
      const a = icons[i], b = icons[i + 1];
      for (let k = 0; k < 14; k++) { const u = k / 14; pathPts.push([lerp(a.x, b.x, u) + Math.sin(u * Math.PI) * (i % 2 ? 60 : -60), lerp(a.y, b.y, u) + 40]); }
    }
    pathPts.push([icons[icons.length - 1].x, icons[icons.length - 1].y + 40]);
    const dots = pathPts.map(([x, y]) => el("circle", { cx: f1(x), cy: f1(y), r: 9, fill: "#d8342c", opacity: 0 }, art));
    const xMark = el("path", { d: "M-30 -30 L30 30 M30 -30 L-30 30", stroke: "#d8342c", "stroke-width": 14, "stroke-linecap": "round", opacity: 0 }, art);
    // Свёрнутые края свитка.
    const rollL = el("rect", { x: -26, y: -20, width: 52, height: 1040, rx: 26, fill: "#e8cf9a", stroke: "#8a5a2a", "stroke-width": 8 }, sheet);
    const rollR = el("rect", { x: -26, y: -20, width: 52, height: 1040, rx: 26, fill: "#e8cf9a", stroke: "#8a5a2a", "stroke-width": 8 }, sheet);
    const clip = el("clipPath", { id: "mapClip" }, B.defs);
    const clipRect = el("rect", { x: 0, y: -40, width: 1600, height: 1080 }, clip);
    art.setAttribute("clip-path", "url(#mapClip)");

    el("rect", { x: 0, y: 0, width: 1920, height: 1080, fill: "url(#vignetteDay)" }, S.L.ui);
    const bG1 = B.bubble(S.L.ui, ["Замок призраков — за облаками,", "у Небесной кузницы."], 820, 140);
    const bG2 = B.bubble(S.L.ui, ["Путь лежит через", "Забытые мосты…"], 470, 140);

    const OPEN = 1.0, DIVE = 3.5, PATH0 = 4.3, PATH1 = 7.0;
    return function render(t) {
      // Камера: старик и герои → ныряем в карту → к замку на облаках.
      const dive = E.ioC(seg(t, DIVE, DIVE + 1.1)), end = E.inC(seg(t, 7.2, 8.0));
      const cx = MAP_X + 200, cy = MAP_Y + 125;
      S.cam.x = lerp(120, cx - 960, dive) + end * (1300 * MS - 800 * MS);
      S.cam.y = lerp(20, cy - 540, dive) + end * (200 * MS - 500 * MS);
      S.cam.z = lerp(1.1, 4.6, dive) + end * 3;
      S.apply();
      P.wave(t, 0.4);

      // Старик идёт к героям с посохом, разворачивает свиток.
      const walk = seg(t, 0, 0.9);
      const gp = { x: lerp(560, 800, E.outQ(walk)), y: 664, s: 1.55, dir: 1, t, shadowOp: 0.35, eyes: "happy", mouth: "smile", armF: 30, armB: -20 };
      gp.lift = walk < 1 ? Math.abs(Math.sin(walk * Math.PI * 3)) * 8 : 0;
      gp.tilt = walk < 1 ? 4 : 0;
      if (t > OPEN) Object.assign(gp, { eyes: "open", look: [3, 0], armF: 60, armB: -70, mouth: t > 1.5 && t < 3.6 && Math.sin(t * 18) > 0 ? "o" : "smile" });
      poseBean(grandpa, gp);
      // Свиток раскрывается от центра.
      const open = E.outBack(seg(t, OPEN, OPEN + 0.7));
      const half = 800 * open;
      tr(map, MAP_X, MAP_Y, 0, MS);
      clipRect.setAttribute("x", f1(800 - half)); clipRect.setAttribute("width", f1(half * 2));
      tr(rollL, 800 - half, 0); tr(rollR, 800 + half, 0);
      show(map, t > OPEN ? 1 : 0);
      // Путь пунктиром и значки миров.
      const prog = seg(t, PATH0, PATH1) * (dots.length + 3);
      dots.forEach((d, k) => show(d, k < prog ? 1 : 0));
      icons.forEach((ic, k) => {
        const reach = k === 0 ? PATH0 - 0.3 : PATH0 + (k * 14 / (dots.length + 3)) * (PATH1 - PATH0);
        const u = E.outBack(seg(t, reach, reach + 0.3));
        tr(ic.g, ic.x, ic.y, 0, 1.45 * (t < DIVE ? 1 : 0.6 + 0.4 * u + (k === 6 ? 0.25 * Math.sin(Math.PI * seg(t, 7.0, 7.6)) : 0)));
      });
      const xm = E.outBack(seg(t, PATH1, PATH1 + 0.3));
      show(xMark, xm > 0 ? 1 : 0); tr(xMark, 1300, 300, 0, Math.max(0.001, xm));

      // Герои слушают, поворачиваются к старику, тянутся к карте.
      H.forEach((h, i) => {
        const p = { x: h.x, y: 664, s: h.s, dir: t > 0.4 + i * 0.1 ? -1 : 1, t, shadowOp: 0.35, eyes: "open", mouth: "smile", look: [3, 0] };
        if (t > OPEN + 0.3) Object.assign(p, { eyes: "wide", mouth: "o", brows: "up", tilt: 8, look: [4, 2] });
        if (i === 0) Object.assign(p, { armB: -40 });
        poseBean(h.b, p);
      });

      const [gx, gy] = S.toScreen(gp.x + 20, 664 - 1.55 * 110);
      B.placeBubble(bG1, t, 1.4, 3.4, clamp(gx + 160, 430, 1490), gy - 190, gx + 10, gy - 20);
      B.placeBubble(bG2, t, 4.6, 6.6, 340, 900, 40, 1060);
    };
  },
});
