// Сцена 2 «Праздник»: площадь днём, король объявляет праздник, толпа пляшет, хлопушки и «УРА-А!»,
// из-за замка взлетают ракеты салюта; камера уходит вверх за последней — её вспышка переносит в руины.
B.addScene({
  id: "festival",
  dur: 7,
  init(S) {
    const { el, f1, clamp, seg, E, K, tr, show, NAVY, makeBean, poseBean } = B;
    const P = B.square(S, "day");
    B.sun(S.L.sky, 1560, 60, 80);
    for (const [x, y, s] of [[160, 200, 1.3], [1150, 90, 1.0], [1750, 300, 1.1]]) B.cloud(S.L.sky, x, y, s, P.pal);
    const rnd = B.rng(22), mid = S.L.mid;

    // Салют — на среднем плане, позади толпы (камера поднимется за последней ракетой).
    const sky = el("g", {}, mid);
    // Король и толпа (горожане и герои).
    const cast = el("g", {}, mid);
    const king = makeBean(cast, "plum", { king: true, shadow: "#3a2a10", rim: "#fff6c8" });
    const CROWD = [
      { c: "pink", acc: "hat", x: 300, y: 962, s: 1.5, dir: 1 },
      { c: "red", x: 720, y: 968, s: 1.55, dir: 1 },
      { c: "yellow", acc: "bow", x: 1080, y: 972, s: 1.27, dir: 1 },
      { c: "teal", acc: "flower", x: 1250, y: 960, s: 1.48, dir: -1 },
      { c: "brown", acc: "cap", x: 1740, y: 958, s: 1.5, dir: -1 },
      { c: "orange", acc: "scarf", x: 500, y: 1018, s: 1.68, dir: 1 },
      { c: "blue", x: 880, y: 1030, s: 1.62, dir: 1 },
      { c: "green", x: 1380, y: 1034, s: 1.62, dir: -1 },
      { c: "purple", acc: "glasses", x: 1600, y: 1012, s: 1.62, dir: -1 },
    ];
    for (const f of CROWD) f.b = makeBean(cast, f.c, { acc: f.acc, shadow: "#6a4a20", rim: "#fff6c8" });

    // Конфетти из хлопушек по краям помоста и салют.
    const fx = el("g", {}, mid);
    const COLORS = ["#e8414a", "#ffcf3f", "#3a8de0", "#46b85a", "#f07ad0", "#ffffff"];
    const BOOM = 4.0;
    const conf = [];
    for (const [cx, dirx] of [[760, -1], [1500, 1]]) for (let k = 0; k < 40; k++) {
      const e = el("rect", { x: -6, y: -9, width: 12, height: 18, rx: 2, fill: COLORS[k % 6], stroke: NAVY, "stroke-width": 1.5, opacity: 0 }, fx);
      const ang = -Math.PI / 2 + dirx * (0.15 + rnd() * 0.9), v = 700 + rnd() * 700;
      conf.push({ e, x0: cx, y0: 640, vx: Math.cos(ang) * v, vy: Math.sin(ang) * v, spin: 400 + rnd() * 700, ph: rnd() * 6 });
    }
    for (const [cx, dirx] of [[760, -1], [1500, 1]]) {
      const g = el("g", { transform: `translate(${cx} 664) rotate(${dirx * 30})` }, mid);
      el("rect", { x: -16, y: -60, width: 32, height: 64, rx: 6, fill: dirx < 0 ? "#3a8de0" : "#e8414a", stroke: NAVY, "stroke-width": 4 }, g);
      for (let k = 0; k < 3; k++) el("rect", { x: -16, y: -52 + k * 20, width: 32, height: 7, fill: "#ffcf3f" }, g);
    }
    // Ракеты: [старт x, высота взрыва, время старта, время взрыва, цвет].
    const ROCKETS = [[620, 150, 3.95, 4.55, "#ffd23f"], [1000, 40, 4.1, 4.85, "#ff6a8a"], [1380, 120, 4.3, 5.0, "#7fd6ff"], [820, -120, 4.8, 5.6, "#a2f07a"], [960, -360, 5.6, 6.7, "#ffe6a0"]];
    const rockets = ROCKETS.map(([x, y, t0, t1, c]) => {
      const trail = el("line", { stroke: c, "stroke-width": 5, "stroke-linecap": "round", "stroke-dasharray": "2 12", opacity: 0 }, sky);
      const head = el("circle", { r: 8, fill: c, stroke: NAVY, "stroke-width": 2.5, opacity: 0 }, sky);
      const sparks = [];
      for (let k = 0; k < 28; k++) sparks.push(el("path", { d: "M0 -9 L2.6 -2.6 L9 0 L2.6 2.6 L0 9 L-2.6 2.6 L-9 0 L-2.6 -2.6Z", fill: c, stroke: NAVY, "stroke-width": 1.6, opacity: 0 }, sky));
      const flash = el("circle", { r: 120, fill: c, opacity: 0 }, sky);
      return { x, y, t0, t1, c, trail, head, sparks, flash };
    });

    el("rect", { x: 0, y: 0, width: 1920, height: 1080, fill: "url(#vignetteDay)" }, S.L.ui);
    const narr = B.narration(S.L.ui, ["Каждый год бобы праздновали", "весёлый Праздник бобов."], 820);
    const bKing = B.bubble(S.L.ui, ["Да начнётся праздник!"], 560, 92);
    const sUra = B.sfx(S.L.ui, "УРА-А!", 96, "#ffd23f", "#e8414a");

    return function render(t) {
      // Камера: вход — продолжение наезда из кадра 1 (растёт и тормозит); в конце — вверх за ракетой.
      const up = E.inC(seg(t, 5.2, 7.0));
      S.cam.z = 1.0 + 0.08 * E.outC(seg(t, 0, 1.2)) - 0.1 * up;
      S.cam.x = 40; S.cam.y = 30 - 900 * up;
      const shake = 7 * Math.sin(Math.PI * seg(t, BOOM, BOOM + 0.35));
      S.cam.sx = Math.sin(t * 61) * shake; S.cam.sy = Math.cos(t * 47) * shake;
      S.apply();
      P.wave(t, 0.5);

      // Король: машет → поднимает обе руки, объявляет → празднует.
      const kp = { x: 1130, y: 694, s: 2.35, dir: 1, t, shadowOp: 0.3 };
      if (t < 2.3) {
        const w = Math.sin(t * 2 * Math.PI * 1.6);
        Object.assign(kp, { eyes: "open", mouth: "smile", armB: -125 + w * 22, armF: 24, tilt: w * 2, lift: Math.max(0, Math.sin(t * 2 * Math.PI * 0.8)) * 6 });
      } else if (t < BOOM) {
        const u = E.outBack(seg(t, 2.3, 2.6));
        Object.assign(kp, { eyes: "happy", mouth: "grin", armF: 18 + 140 * u, armB: -18 - 140 * u, lift: 14 * u, sq: 1 + 0.04 * u });
      } else {
        const hop = Math.max(0, Math.sin((t - BOOM) * 2 * Math.PI * 1.8));
        Object.assign(kp, { eyes: "happy", mouth: "grin", armF: 155 + Math.sin(t * 12) * 10, armB: -155 - Math.sin(t * 12) * 10, lift: hop * 24 });
      }
      poseBean(king, kp);

      // Толпа пляшет; в момент хлопушек все разом подпрыгивают.
      CROWD.forEach((f, i) => {
        const ph = t * 2 * Math.PI * 2.0 + i * 1.1, hop = Math.max(0, Math.sin(ph));
        const p = { x: f.x, y: f.y, s: f.s, dir: f.dir, t, shadowOp: 0.3, eyes: "happy", mouth: "smile", wind: 0.5 };
        p.lift = hop * 16; p.sq = 1 + (hop < 0.06 ? 0.06 : -0.02);
        p.armF = 140 + Math.sin(ph) * 25; p.armB = -140 - Math.sin(ph) * 25; p.tilt = Math.sin(ph * 0.5) * 4;
        if (t < 2.4 && i % 3 === 1) Object.assign(p, { armF: 20 + hop * 10, armB: -30, eyes: "open", look: [2, -2] });
        const b = t - BOOM - i * 0.04;
        if (b > 0 && b < 0.8) { p.lift = 70 * Math.sin(Math.PI * b / 0.8); p.mouth = "grin"; p.armF = 165; p.armB = -165; p.legF = -20; p.legB = 20; }
        poseBean(f.b, p);
      });

      // Конфетти.
      for (const c of conf) {
        const u = t - BOOM;
        if (u < 0) { show(c.e, 0); continue; }
        const drag = 1 - Math.exp(-2.2 * u);
        const x = c.x0 + c.vx * drag / 2.2, y = c.y0 + c.vy * drag / 2.2 + 380 * u * u * 0.5;
        show(c.e, u < 2.6 ? 1 : 0);
        tr(c.e, x, y, c.spin * u, 1, Math.cos(u * 10 + c.ph));
      }
      // Ракеты и взрывы салюта.
      for (const r of rockets) {
        const u = seg(t, r.t0, r.t1), alive = t >= r.t0 && t < r.t1;
        const hy = 640 - (640 - r.y) * E.outQ(u), hx = r.x + Math.sin(u * 9) * 6;
        show(r.head, alive ? 1 : 0); r.head.setAttribute("cx", f1(hx)); r.head.setAttribute("cy", f1(hy));
        show(r.trail, alive ? 0.7 : 0);
        r.trail.setAttribute("x1", f1(hx)); r.trail.setAttribute("y1", f1(hy)); r.trail.setAttribute("x2", f1(r.x)); r.trail.setAttribute("y2", f1(Math.min(640, hy + 140)));
        const b = t - r.t1;
        show(r.flash, b > 0 && b < 0.35 ? 0.35 * (1 - b / 0.35) : 0); r.flash.setAttribute("cx", r.x); r.flash.setAttribute("cy", r.y);
        r.sparks.forEach((s, k) => {
          if (b < 0 || b > 1.6) { show(s, 0); return; }
          const a = (k / r.sparks.length) * Math.PI * 2, d = (k % 2 ? 210 : 300) * (1 - Math.exp(-3.2 * b));
          tr(s, r.x + Math.cos(a) * d, r.y + Math.sin(a) * d + 90 * b * b, b * 200, 2.4 * (1 - b / 1.6) + 0.5); show(s, 1 - E.inQ(b / 1.6));
        });
      }

      B.placeNarration(narr, t, 0.3, 2.4, 960, 110);
      const [kx, ky] = S.toScreen(1130 + 30, 694 - 2.35 * 112);
      B.placeBubble(bKing, t, 2.45, 4.0, kx + 330, ky - 90, kx + 40, ky);
      B.placeSfx(sUra, t, BOOM + 0.05, 5.3, 470, 330, -6 + Math.sin(t * 22) * 2, 1);
    };
  },
});
