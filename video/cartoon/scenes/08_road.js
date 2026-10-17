// Сцена 8 «Дорога»: рассвет, четверо бегут вправо по лугу к далёким парящим островам; «Вперёд!»;
// в конце камера поднимается к небу — склейка на мост над облаками.
B.addScene({
  id: "road",
  dur: 5,
  init(S) {
    const { el, f1, clamp, seg, lerp, E, K, tr, show, NAVY, makeBean, poseBean, crownShape } = B;
    const pal = B.PAL.dawn, rnd = B.rng(88);
    B.sky(S.L.sky, pal, "dawn");
    B.sun(S.L.sky, 1650, 560, 95);
    for (const [x, y, s] of [[150, 200, 1.2], [900, 90, 1.0], [1500, 260, 0.9], [2300, 150, 1.1]]) B.cloud(S.L.sky, x, y, s, pal, 0.9);
    // Дальний план: парящие острова с мостами в утренней дымке.
    const far = S.L.far;
    const isl = [[300, 430, 180, 140], [700, 380, 140, 110], [1180, 450, 220, 160], [1650, 380, 170, 130], [2100, 460, 230, 170], [2600, 400, 160, 120]];
    for (const [x, y, w, h] of isl) B.island(far, x, y, w, h, pal, { fall: w > 170, stroke: "#8a6a8a", sw: 3, rock: "#c4a8c0", rockDark: "#a68aa6", grass: "#9ad07a", grassDark: "#7ab862" });
    for (let i = 0; i < isl.length - 1; i++) B.bridge(far, isl[i][0] + isl[i][2] / 2 - 10, isl[i][1], isl[i + 1][0] - isl[i + 1][2] / 2 + 10, isl[i + 1][1], 36, "#8a6a7a", "#b08a7a", 2.5);
    el("rect", { x: -600, y: 480, width: 4000, height: 500, fill: B.vgrad("hazeDawn", [[0, "#ffe0c0", 0], [0.5, "#ffe0c0", 0.55], [1, "#ffd0b0", 0.3]]) }, far);
    // Средний план: холмы, дорога, деревья, указатель.
    const mid = S.L.mid;
    el("path", { d: "M-800 760 Q 0 650 800 720 Q 1600 640 2400 730 Q 3200 660 4600 740 L4600 1400 L-800 1400Z", fill: "#8fcf6a", stroke: NAVY, "stroke-width": 4 }, mid);
    el("path", { d: "M-800 840 Q 400 760 1400 820 Q 2600 760 4600 830 L4600 1400 L-800 1400Z", fill: "#7cc45c", stroke: NAVY, "stroke-width": 4 }, mid);
    el("path", { d: "M-800 900 C 200 880 600 760 1300 780 S 2600 700 4600 760", fill: "none", stroke: "#f0d9a8", "stroke-width": 46, "stroke-linecap": "round" }, mid);
    for (let i = 0; i < 18; i++) {
      const x = -600 + i * 280 + rnd() * 120, y = 760 + rnd() * 60, rr = 34 + rnd() * 26;
      el("rect", { x: x - 6, y: y - 10, width: 12, height: 44, fill: "#8a5a34", stroke: NAVY, "stroke-width": 3 }, mid);
      el("circle", { cx: x, cy: y - 10 - rr * 0.6, r: rr, fill: i % 2 ? "#5cb84e" : "#4fae4a", stroke: NAVY, "stroke-width": 3.5 }, mid);
      el("circle", { cx: x - rr * 0.3, cy: y - 10 - rr, r: rr * 0.4, fill: "#ffd8a0", opacity: 0.5 }, mid);
    }
    const sign = el("g", { transform: "translate(1500 780)" }, mid);
    el("rect", { x: -6, y: -110, width: 12, height: 110, fill: "#8a5a34", stroke: NAVY, "stroke-width": 3.5 }, sign);
    el("path", { d: "M-50 -110 L60 -110 L84 -90 L60 -70 L-50 -70Z", fill: "#c08a50", stroke: NAVY, "stroke-width": 3.5 }, sign);
    // Передний план: луг, герои, травинки перед ногами.
    const fg = S.L.fg;
    B.meadow(fg, 900, 9000, { grass: "#6cc552", grassDark: "#4fa046", grassLight: "#a0e080", edge: "#2f7a2a" }, 12, -1200);
    const dust = el("g", {}, fg);
    const puffs = Array.from({ length: 40 }, () => el("circle", { r: 10, fill: "#fff3e0", opacity: 0 }, dust));
    const H = [{ c: "yellow", acc: "bow", off: -510 }, { c: "green", off: -350 }, { c: "blue", off: -180 }, { c: "red", off: 0 }];
    for (const h of H) { h.b = makeBean(fg, h.c, { acc: h.acc, shadow: "#3a6a2a", rim: "#ffe6b0" }); h.s = h.c === "yellow" ? 1.35 : 1.65; }
    crownShape(el("g", { transform: "translate(-30 -30) rotate(-34) scale(0.95)" }, H[3].b.hold));
    B.tufts(fg, -1200, 8000, 990, 31, { grass: "#6cc552", grassLight: "#a0e080", edge: "#2f7a2a" });
    const birds = el("g", {}, S.L.far);
    el("rect", { x: 0, y: 0, width: 1920, height: 1080, fill: "url(#vignetteDay)" }, S.L.ui);
    const bGo = B.bubble(S.L.ui, ["Вперёд!"], 260, 92);

    const SPEED = 620;
    return function render(t) {
      const up = E.inC(seg(t, 3.4, 5.0));
      S.cam.x = SPEED * t; S.cam.y = 40 - 620 * up; S.cam.z = 1.05 - 0.05 * up;
      S.apply();
      if (!birds.childElementCount) for (let i = 0; i < 5; i++) el("path", { fill: "none", stroke: "#5a3a5a", "stroke-width": 3, "stroke-linecap": "round" }, birds);
      [...birds.children].forEach((b, i) => {
        const x = 900 + t * 160 + i * 40, y = 260 + i * 14 + (i % 2) * 10, upw = Math.floor(t * 12 + i) % 2 === 0;
        b.setAttribute("d", upw ? `M${f1(x)} ${f1(y)} q 8 -9 16 1 q 8 -10 16 -1` : `M${f1(x)} ${f1(y)} q 8 9 16 3 q 8 6 16 -3`);
      });
      let pn = 0;
      H.forEach((h, i) => {
        // Бегут вместе с камерой (передний план движется быстрее — множитель 1.35) и чуть её обгоняют.
        const base = 820 + S.cam.x * 1.35 + h.off + 40 * t, ph = t * 2 * Math.PI * 3.1 + i * 0.9;
        const p = { x: base, y: 980, s: h.s, dir: 1, t, shadowOp: 0.3, eyes: "open", mouth: "grin", brows: "angry", look: [3, 0], wind: 1.2 };
        p.lift = Math.abs(Math.sin(ph)) * 18; p.legF = Math.sin(ph) * 42; p.legB = -Math.sin(ph) * 42;
        p.armF = Math.sin(ph) * 50 + 20; p.armB = -Math.sin(ph) * 50 - 20; p.tilt = 12; p.sq = 1 + Math.cos(ph * 2) * 0.03;
        if (h.c === "red") { p.armB = -60 + Math.sin(ph) * 10; if (t > 0.4 && t < 1.9) { p.mouth = "scream"; p.armF = 150 + Math.sin(t * 12) * 8; } }
        poseBean(h.b, p);
        for (let k = 0; k < 40 && pn < puffs.length; k++) {
          const ts = Math.floor(t * 6.2) / 6.2 - k / 6.2, a = t - ts;
          if (a < 0 || a > 0.45 || ts < 0) continue;
          const xs = 820 + SPEED * ts * 1.35 + h.off + 40 * ts - 30 * h.s, c = puffs[pn++];
          c.setAttribute("cx", f1(xs - a * 80)); c.setAttribute("cy", f1(976 - a * 30)); c.setAttribute("r", f1((8 + a * 36) * h.s * 0.6)); show(c, 0.6 * (1 - a / 0.45));
        }
      });
      for (let k = pn; k < puffs.length; k++) show(puffs[k], 0);
      const red = H[3];
      // Герои на переднем плане (параллакс 1.35): экранные координаты считаем для этого слоя.
      const rx = 960 + S.cam.z * (820 + 40 * t - 960), ry = 540 + S.cam.z * (980 - red.s * 110 - 540 - S.cam.y * 1.35);
      B.placeBubble(bGo, t, 0.4, 1.9, clamp(rx + 120, 200, 1720), ry - 170, rx + 30, ry - 20);
    };
  },
});
