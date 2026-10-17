// Сцена 3 «Руины»: из крупного плана далёкого салюта камера отъезжает к старым руинам на скале —
// оттуда на праздник грустно смотрят призраки. Вожак придумывает план, все срываются к Царству (склейка в налёт).
B.addScene({
  id: "ruins",
  dur: 13,
  init(S) {
    const { el, f1, clamp, seg, lerp, E, K, tr, show, NAVY, makeGhost, poseGhost } = B;
    const pal = B.PAL.dusk, rnd = B.rng(33);
    B.sky(S.L.sky, pal, "dusk");
    const stars = B.stars(S.L.sky, 40, 5, [-300, -700, 2520, 900]);
    for (const [x, y, s] of [[100, 150, 1.3], [900, 60, 1.1], [1650, 220, 1.2]]) B.cloud(S.L.sky, x, y, s, pal, 0.7);

    // Дальний план: горы, далёкое Царство с огнями праздника и салютом.
    const far = S.L.far;
    el("path", { d: "M-600 600 L-300 470 L0 560 L300 430 L640 580 L950 470 L1250 590 L1700 450 L2100 580 L2600 500 L2600 1700 L-600 1700Z", fill: "#5a467e" }, far);
    el("path", { d: "M-600 650 Q 200 560 900 640 Q 1500 560 2600 650 L2600 1700 L-600 1700Z", fill: "#4a3a72" }, far);
    const town = el("g", { transform: "translate(1500 600) scale(0.32)" }, far);
    el("ellipse", { cx: 0, cy: -150, rx: 700, ry: 300, fill: "url(#warm)", opacity: 0.55 }, town);
    el("path", { d: "M-420 40 Q -220 -230 0 -250 Q 220 -230 420 40Z", fill: "#3a2d62", stroke: "#241c46", "stroke-width": 6 }, town);
    for (const [x, y, w] of [[-170, -420, 60], [-80, -520, 70], [20, -600, 90], [120, -520, 70], [200, -430, 60]]) {
      el("rect", { x: x - w / 2, y, width: w, height: -y - 200, fill: "#3a2d62", stroke: "#241c46", "stroke-width": 6 }, town);
      el("path", { d: `M${x - w * 0.62} ${y} C ${x - w * 0.7} ${y - w * 0.7} ${x - w * 0.3} ${y - w} ${x} ${y - w} C ${x + w * 0.3} ${y - w} ${x + w * 0.7} ${y - w * 0.7} ${x + w * 0.62} ${y}Z`, fill: "#4a3a76", stroke: "#241c46", "stroke-width": 6 }, town);
      for (let k = 0; k < 3; k++) el("rect", { x: x - 8, y: y + 30 + k * 60, width: 16, height: 26, rx: 8, fill: "#ffd27a" }, town);
    }
    for (let i = 0; i < 26; i++) el("circle", { cx: f1(-380 + rnd() * 760), cy: f1(-60 - rnd() * 140), r: 7, fill: "#ffd27a" }, town);
    const fwG = el("g", { style: "mix-blend-mode:screen" }, far);
    const FW = [];
    for (let i = 0; i < 9; i++) {
      const c = ["#ffd23f", "#ff7a9a", "#8fe0ff", "#a6f07a"][i % 4], g = el("g", {}, fwG), sp = [];
      for (let k = 0; k < 16; k++) sp.push(el("circle", { r: 3, fill: c }, g));
      FW.push({ g, sp, x: 1500 + (rnd() - 0.5) * 300, y: 380 + rnd() * 90, t0: i * 0.95 + rnd() * 0.4, c });
    }
    el("rect", { x: -600, y: 600, width: 3400, height: 1100, fill: B.vgrad("mistDusk", [[0, "#ff9a8a", 0], [0.25, "#ff9a8a", 0.3], [1, "#7a5aa0", 0.5]]) }, far);

    // Средний план: скала с руинами (арка, колонны, мох, лианы).
    const mid = S.L.mid;
    const STONE = "#8f84ab", STONE_D = "#6c6290", MOSS = "#6fa070";
    el("path", { d: "M-700 800 L1120 800 Q 1170 812 1160 880 L1090 1500 L-700 1500Z", fill: "#5c4f80", stroke: NAVY, "stroke-width": 5 }, mid);
    el("path", { d: "M-700 800 L1120 800 Q 1150 806 1150 830 L-700 840Z", fill: "#5f8a64", stroke: NAVY, "stroke-width": 4 }, mid);
    for (let x = -680; x < 1120; x += 30) el("path", { d: `M${x} 806 q 8 ${-14 - rnd() * 14} 16 0`, fill: "#6fa070", stroke: "#2f5a3a", "stroke-width": 2 }, mid);
    const behind = el("g", {}, mid); // призраки за колонной
    function pillar(x, top, h, broken) {
      const g = el("g", {}, mid);
      el("rect", { x: x - 46, y: top, width: 92, height: h, fill: STONE, stroke: NAVY, "stroke-width": 5 }, g);
      el("rect", { x: x + 14, y: top + 3, width: 28, height: h - 6, fill: STONE_D, opacity: 0.7 }, g);
      for (let y = top + 26; y < top + h - 10; y += 44) el("line", { x1: x - 46, y1: y, x2: x + 46, y2: y, stroke: NAVY, "stroke-width": 3, opacity: 0.6 }, g);
      if (broken) el("path", { d: `M${x - 46} ${top} L${x - 20} ${top - 22} L${x} ${top - 6} L${x + 18} ${top - 30} L${x + 46} ${top}Z`, fill: STONE, stroke: NAVY, "stroke-width": 5 }, g);
      el("ellipse", { cx: x - 22, cy: top + h * 0.35, rx: 20, ry: 12, fill: MOSS, stroke: "#2f5a3a", "stroke-width": 2.5 }, g);
      return g;
    }
    pillar(300, 470, 330); pillar(620, 470, 330); pillar(940, 650, 150, true);
    const arch = el("path", { d: "M254 474 A 206 206 0 0 1 666 474 L 574 474 A 114 114 0 0 0 346 474Z", fill: STONE, stroke: NAVY, "stroke-width": 5 }, mid);
    for (let k = 1; k < 7; k++) {
      const a = Math.PI + (k / 7) * Math.PI, c = Math.cos(a), s = Math.sin(a);
      el("line", { x1: f1(460 + c * 114), y1: f1(474 + s * 114), x2: f1(460 + c * 206), y2: f1(474 + s * 206), stroke: NAVY, "stroke-width": 3, opacity: 0.6 }, mid);
    }
    el("path", { d: "M300 300 Q 340 250 400 268 Q 460 240 520 270 Q 570 252 620 290", fill: "none", stroke: MOSS, "stroke-width": 16, "stroke-linecap": "round" }, mid);
    for (const [x, len] of [[360, 120], [420, 70], [540, 150], [600, 90]]) el("path", { d: `M${x} 280 q 10 ${len * 0.5} -4 ${len}`, fill: "none", stroke: "#4f8a5a", "stroke-width": 5, "stroke-linecap": "round" }, mid);
    el("rect", { x: 700, y: 752, width: 170, height: 52, rx: 26, fill: STONE, stroke: NAVY, "stroke-width": 5, transform: "rotate(-6 785 778)" }, mid);
    const front = el("g", {}, mid);
    el("rect", { x: 0, y: 0, width: 1920, height: 1080, fill: "url(#vignette)" }, S.L.ui);

    // Призраки: [x, y, масштаб, слой]. 0 — вожак, 1 — за колонной, 2 — на арке, 3 — малыш.
    const G = [[820, 660, 1.75, front], [318, 600, 1.4, behind], [470, 205, 1.35, front], [700, 712, 1.0, front]].map(([x, y, s, layer], i) => ({ g: makeGhost(layer, i === 0), x, y, s }));
    const narr = B.narration(S.L.ui, ["А далеко, в старых руинах,", "на праздник смотрели призраки.", "Их никогда не звали."], 860, 40);
    const b1 = B.bubble(S.L.ui, ["Опять без нас…"], 400, 92);
    const b2 = B.bubble(S.L.ui, ["Нас все боятся…"], 420, 92, 40);
    const bL = B.bubble(S.L.ui, ["Не зовут — сами придём!", "И заберём праздник себе!"], 640, 140);
    const sUu = B.sfx(S.L.ui, "У-У-У!", 86, "#ffffff", "#5a3a8a");

    const RISE = 8.5, PERK = 10.3, GO = 11.5;
    return function render(t) {
      // Камера: из крупного плана далёкого салюта — отъезд к руинам; затем наезд на вожака; рывок вправо за улетающими.
      const back = E.ioC(seg(t, 0.4, 3.2)), lead = E.io(seg(t, RISE, RISE + 1.2)), go = E.inC(seg(t, GO + 0.3, 13));
      S.cam.x = lerp(1543, 0, back) + lead * 160 + go * 1500;
      S.cam.y = lerp(-20, 30, back) - lead * 120;
      S.cam.z = lerp(2.6, 1.0, back) + lead * 0.32;
      S.apply();
      B.twinkle(stars, t, 0.6);
      for (const f of FW) {
        const u = ((t - f.t0) % 2.4 + 2.4) % 2.4;
        show(f.g, u < 1.1 ? 1 - u / 1.1 : 0);
        f.sp.forEach((c, k) => { const a = k / f.sp.length * 6.283, d = 70 * (1 - Math.exp(-4 * u)); c.setAttribute("cx", f1(f.x + Math.cos(a) * d)); c.setAttribute("cy", f1(f.y + Math.sin(a) * d + 20 * u * u)); });
      }

      // Призраки: грустят → вожак встаёт → остальные оживляются → все улетают к Царству.
      G.forEach(({ g, x, y, s }, i) => {
        const p = { x, y, s, dir: 1, t, ph: i * 1.9, face: "sad", arms: i === 2 || i === 3 ? "hug" : "fly", speed: 0 };
        p.y += Math.sin(t * 1.6 + i) * 6 + (i === 2 ? 0 : 6 * E.io(seg(t, 5.2, 5.8)) * (1 - seg(t, 6.6, 7.2)));
        p.rot = i === 3 ? Math.sin(t * 3) * 6 : Math.sin(t * 1.3 + i) * 3;
        if (i === 0 && t > RISE) {
          const u = E.outBack(seg(t, RISE, RISE + 0.7));
          p.y = lerp(y, 470, u); p.s = lerp(s, 2.2, u); p.face = t > RISE + 0.3 ? (t > 10.6 && t < 11.3 ? "laugh" : "angry") : "sad";
          p.arms = t > RISE + 0.3 ? "point" : "fly"; p.rot = Math.sin(t * 5) * 3;
        }
        if (i > 0 && t > PERK + i * 0.12) {
          const u = E.outBack(seg(t, PERK + i * 0.12, PERK + i * 0.12 + 0.5));
          p.face = i === 3 ? "laugh" : "angry"; p.arms = "up"; p.rot = lerp(p.rot, Math.sin(t * 6 + i) * 6, u); p.y -= 60 * u;
        }
        if (t > GO + i * 0.1) {
          const u = t - GO - i * 0.1;
          p.x += 300 * u * u * 2 + 200 * u; p.y -= 120 * u; p.stretch = 1 + clamp(u, 0, 0.35); p.rot = -10; p.arms = "fly"; p.face = "laugh"; p.speed = 1800 * clamp(u * 2);
          p.trail = [0, 1, 2, 3, 4, 5, 6].map((k) => { const uu = Math.max(0, u - k * 0.04); return [x + 300 * uu * uu * 2 + 200 * uu, p.y + 120 * u - 120 * uu]; });
        }
        poseGhost(g, p);
      });

      B.placeNarration(narr, t, 2.8, 5.5, 960, 130);
      const [ax, ay] = S.toScreen(G[2].x + 40, G[2].y - 50);
      B.placeBubble(b1, t, 5.5, 7.0, ax + 330, ay - 20, ax + 60, ay);
      const [sx, sy] = S.toScreen(G[3].x + 20, G[3].y - 40);
      B.placeBubble(b2, t, 7.0, 8.4, sx + 230, sy - 150, sx + 20, sy - 30);
      const [lx, ly] = S.toScreen(G[0].x + 40, 470 - 90);
      B.placeBubble(bL, t, RISE + 0.45, GO - 0.3, clamp(lx + 360, 400, 1560), clamp(ly - 140, 110, 900), lx + 50, ly);
      B.placeSfx(sUu, t, GO - 0.25, GO + 1.0, 1440, 300, -8 + Math.sin(t * 20) * 2, 0.9);
    };
  },
});
