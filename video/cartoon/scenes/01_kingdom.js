// Сцена 1 «Царство бобов»: камера спускается с неба сквозь облака к замку на холме,
// красный боб впрыгивает в луг, удивляется и машет замку; в конце — наезд на замок (склейка в праздник на ходу).
B.addScene({
  id: "kingdom",
  dur: 7.5,
  init(S) {
    const { el, f1, clamp, seg, E, K, tr, show, NAVY, makeBean, poseBean } = B;
    const pal = B.PAL.day, rnd = B.rng(11);
    B.sky(S.L.sky, pal, "day");
    B.sun(S.L.sky, 330, 40, 90);
    for (const [x, y, s] of [[1250, 120, 1.3], [1700, 300, 1.0], [-100, 330, 1.1]]) B.cloud(S.L.sky, x, y, s, pal);

    // Дальний план: голубые горы, парящие острова с водопадами и мостами.
    const far = S.L.far;
    el("path", { d: "M-500 640 L-200 430 L60 600 L320 380 L600 610 L900 450 L1200 620 L1500 400 L1800 600 L2100 440 L2500 640 L2500 900 L-500 900Z", fill: "#a9c8f0", opacity: 0.9 }, far);
    const isl = [[-120, 470, 210, 160], [260, 400, 150, 120], [1560, 380, 220, 170], [1900, 480, 170, 130], [1260, 470, 120, 90]];
    for (const [x, y, w, h] of isl) B.island(far, x, y, w, h, pal, { fall: w > 160, stroke: "#5b6a9a", sw: 3, rock: "#a6abc8", rockDark: "#8a90b2", grass: "#8ad36f", grassDark: "#6cbb58" });
    B.bridge(far, -20, 470, 190, 400, 40, "#6b5a7a", "#a08a7a", 2.5);
    B.bridge(far, 1670, 380, 1820, 480, 46, "#6b5a7a", "#a08a7a", 2.5);
    el("rect", { x: -500, y: 520, width: 3000, height: 300, fill: B.vgrad("hazeKingdom", [[0, "#ffffff", 0], [0.6, "#ffffff", 0.5], [1, "#ffffff", 0.2]]) }, far);

    // Средний план: холмы, замок, городок с круглыми крышами, дорога.
    const mid = S.L.mid;
    el("path", { d: "M-600 820 Q -100 640 400 700 Q 800 600 1200 690 Q 1700 610 2500 760 L2500 1400 L-600 1400Z", fill: "#7ccc66", stroke: NAVY, "stroke-width": 4 }, mid);
    const C = B.castle(mid, 1000, 772, 0.86, pal);
    el("path", { d: "M1000 760 C 980 820 900 840 880 900 C 860 960 960 1000 940 1100", fill: "none", stroke: "#efd9a8", "stroke-width": 42, "stroke-linecap": "round" }, mid);
    el("path", { d: "M1000 760 C 980 820 900 840 880 900 C 860 960 960 1000 940 1100", fill: "none", stroke: "#d9bd86", "stroke-width": 6, "stroke-dasharray": "2 26", "stroke-linecap": "round" }, mid);
    const roofs = [["#e5483e", "#ff9a8e"], ["#3a7fe6", "#9cc6ff"], ["#f7c531", "#fff09a"], ["#46b85a", "#a2f0a8"], ["#f07ad0", "#ffc0ec"]];
    const houses = [[560, 780, 0.8], [690, 805, 0.95], [1320, 790, 0.9], [1450, 760, 0.75], [1200, 830, 1.05], [420, 820, 1.0], [1610, 800, 0.95]];
    houses.sort((a, b) => a[1] - b[1]).forEach(([x, y, s], i) => {
      const g = el("g", { transform: `translate(${x} ${y}) scale(${s})` }, mid);
      el("rect", { x: -40, y: -70, width: 80, height: 70, fill: "#f3e2c4", stroke: NAVY, "stroke-width": 4 }, g);
      el("path", { d: "M-52 -66 Q -50 -136 0 -140 Q 50 -136 52 -66Z", fill: roofs[i % 5][0], stroke: NAVY, "stroke-width": 4 }, g);
      el("path", { d: "M-34 -84 Q -32 -118 -12 -126", fill: "none", stroke: roofs[i % 5][1], "stroke-width": 7, "stroke-linecap": "round", opacity: 0.7 }, g);
      el("path", { d: "M-12 0 L-12 -30 Q 0 -44 12 -30 L12 0Z", fill: "#8a5530", stroke: NAVY, "stroke-width": 3 }, g);
      el("rect", { x: 18, y: -50, width: 14, height: 16, rx: 6, fill: "#7cc4ff", stroke: NAVY, "stroke-width": 2.5 }, g);
    });
    for (let i = 0; i < 14; i++) {
      const x = -300 + i * 190 + rnd() * 80, y = 760 + rnd() * 60, r = 34 + rnd() * 22;
      if (x > 330 && x < 1700) continue;
      const g = el("g", {}, mid);
      el("rect", { x: x - 6, y, width: 12, height: 40, fill: "#8a5a34", stroke: NAVY, "stroke-width": 3 }, g);
      el("circle", { cx: x, cy: y - r * 0.6, r, fill: "#4fae4a", stroke: NAVY, "stroke-width": 3.5 }, g);
      el("circle", { cx: x - r * 0.3, cy: y - r * 0.9, r: r * 0.4, fill: "#7fd06a" }, g);
    }
    // Облака, сквозь которые опускается камера (средний план, высоко).
    const nearClouds = [];
    for (const [x, y, s] of [[300, -560, 2.4], [1300, -760, 2.8], [-300, -320, 2.2], [1600, -380, 2.3], [700, -980, 2.6]]) nearClouds.push(B.cloud(mid, x, y, s, pal, 0.95));
    const birds = el("g", {}, mid);

    // Передний план: луг, герой, трава перед ногами.
    const fg = S.L.fg;
    B.meadow(fg, 900, 3400, undefined, 5, -900);
    const dust = el("g", {}, fg);
    const puffs = [0, 1, 2, 3, 4, 5].map(() => el("circle", { r: 10, fill: "#fffbe6", opacity: 0 }, dust));
    const hero = makeBean(fg, "red", { shadow: "#2a5a20", rim: "#fff6c8" });
    B.tufts(fg, 250, 720, 988, 21);
    // Ветка в углу (самый ближний план, размыта).
    const branch = el("g", { filter: "url(#blur3)" }, fg);
    el("path", { d: "M-200 -900 Q 200 -820 520 -760", fill: "none", stroke: "#6b4426", "stroke-width": 26, "stroke-linecap": "round" }, branch);
    for (let i = 0; i < 26; i++) {
      const u = i / 25, x = -200 + 720 * u + (rnd() - 0.5) * 80, y = -900 + 140 * u + (rnd() - 0.5) * 90;
      el("ellipse", { cx: f1(x), cy: f1(y), rx: 34, ry: 20, fill: rnd() < 0.5 ? "#5cbf4a" : "#8fe070", stroke: NAVY, "stroke-width": 3, transform: `rotate(${f1(rnd() * 180)} ${f1(x)} ${f1(y)})` }, branch);
    }
    el("rect", { x: 0, y: 0, width: 1920, height: 1080, fill: "url(#vignetteDay)" }, S.L.ui);
    const narr = B.narration(S.L.ui, ["Далеко-далеко, за облачными мостами,", "раскинулось Царство бобов."], 1060);

    const HX = 470, HY = 960, HS = 1.75, JUMP = 2.95, LAND = 3.6;
    return function render(t) {
      // Камера: спуск с неба (облака проносятся мимо), затем наезд на замок с разгоном.
      S.cam.y = K(t, [[0, -1180], [3.4, 0, "io"]]);
      const push = E.inC(seg(t, 5.7, 7.5));
      S.cam.z = 1 + push * 0.9;
      S.cam.x = push * 40; S.cam.y += push * -60;
      S.apply();
      for (const [f, x, y] of C.flags) B.waveFlag(f, x, y, t, x, 1);
      // Птицы: стайка летит вправо, крылья — две фазы, 12 раз в секунду.
      if (!birds.childElementCount) for (let i = 0; i < 4; i++) el("path", { fill: "none", stroke: "#24304f", "stroke-width": 3.2, "stroke-linecap": "round" }, birds);
      [...birds.children].forEach((b, i) => {
        const up = Math.floor(t * 12 + i) % 2 === 0, x = 380 + t * 120 + i * 46 - (i % 2) * 20, y = 300 + i * 18 - t * 8 + (i % 2) * 14;
        b.setAttribute("d", up ? `M${f1(x)} ${f1(y)} q 8 -9 16 1 q 8 -10 16 -1` : `M${f1(x)} ${f1(y)} q 8 9 16 3 q 8 6 16 -3`);
      });
      // Герой: прыжок из-за нижнего края → приземление → моргнул → «О!» → радость и взмах рукой.
      const p = { x: HX, y: HY, s: HS, dir: 1, t, shadowOp: 0.35 };
      if (t < JUMP) { p.y = 1500; }
      else if (t < LAND) {
        const u = seg(t, JUMP, LAND);
        p.x = HX - 260 * (1 - u); p.lift = 330 * Math.sin(Math.PI * u) * 1.1 - 380 * (1 - u) * (1 - u);
        Object.assign(p, { tilt: -10 + 18 * u, armF: 160, armB: -160, legF: -30, legB: 30, eyes: "open", mouth: "grin" });
      } else {
        const u = t - LAND;
        p.sq = 1 - 0.26 * Math.exp(-7 * u) * Math.cos(15 * u);
        Object.assign(p, { armF: 18 + 30 * Math.exp(-6 * u), armB: -18 - 30 * Math.exp(-6 * u), eyes: "open", mouth: "smile" });
        if (t > 4.05 && t < 4.17) p.eyes = "closed";
        if (t >= 4.4 && t < 5.0) Object.assign(p, { eyes: "wide", look: [2, -2], mouth: "o", brows: "up", tilt: -5 * E.outBack(seg(t, 4.4, 4.65)) });
        if (t >= 5.0) {
          const w = Math.sin((t - 5.0) * 2 * Math.PI * 2.6);
          Object.assign(p, { eyes: "happy", mouth: "grin", armB: -125 + w * 22, armBx: 10, armF: 30, tilt: 3 + w * 1.5, lift: Math.max(0, Math.sin((t - 5.0) * 2 * Math.PI * 1.3)) * 22 });
        }
      }
      poseBean(hero, p);
      // Пыль при приземлении.
      puffs.forEach((c, i) => {
        const u = t - LAND, d = [-1, -0.55, -0.2, 0.2, 0.55, 1][i];
        if (u < 0 || u > 0.6) { show(c, 0); return; }
        c.setAttribute("cx", f1(HX + d * (30 + u * 220))); c.setAttribute("cy", f1(HY - 8 - Math.abs(d) * u * 40));
        c.setAttribute("r", f1(8 + u * 30)); show(c, 0.9 * (1 - u / 0.6));
      });
      B.placeNarration(narr, t, 0.8, 5.5, 960, 110);
    };
  },
});
