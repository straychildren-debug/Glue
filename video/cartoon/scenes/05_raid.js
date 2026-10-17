// Сцена 5 «Налёт»: ночной праздник, порыв ветра, призраки гасят фонари, горожане разбегаются,
// короля хватают и уносят, корона падает на помост, камера опускается к ней в лунном луче.
B.addScene({
  id: "raid",
  dur: 11,
  init(S) {
    const { el, f1, clamp, seg, lerp, E, K, smooth, tr, show, NAVY, makeBean, poseBean, makeGhost, poseGhost, crownShape, placeBubble } = B;
    const rnd = B.rng(77);
    const DURATION = 11;
    // ═══════════════════════ Площадь ночью (lib/places.js) ═══════════════════════
    const P = B.square(S, "night");
    const stars = B.stars(S.L.sky, 90);
    B.moon(S.L.sky, 1560, 165);
    for (const [x, y, s] of [[180, 260, 1.4], [1100, 120, 1.1], [1750, 330, 1.2]]) B.cloud(S.L.sky, x, y, s, P.pal);
    const mid = S.L.mid, lanterns = P.lanterns, reflections = P.reflections;
    const ROPE = P.ROPE;

    // ═══════════════════════ Состав ═══════════════════════
    const shadowsLayer = el("g", {}, mid);
    const cast = el("g", {}, mid);
    const king = makeBean(cast, "plum", { king: true });
    const FOLKS = [
      { c: "brown", acc: "cap", x: 1720, y: 950, s: 1.5, dir: -1, react: 2.3, run: 2.55 },
      { c: "teal", acc: "flower", x: 800, y: 958, s: 1.48, dir: 1, react: 2.45, run: 2.78 },
      { c: "pink", acc: "hat", x: 330, y: 968, s: 1.55, dir: 1, react: 2.5, run: 2.86, shout: true },
      { c: "purple", acc: "glasses", x: 1470, y: 1002, s: 1.62, dir: -1, react: 2.35, run: 2.62 },
      { c: "orange", acc: "scarf", x: 575, y: 1012, s: 1.68, dir: 1, react: 2.42, run: 2.72 },
    ];
    for (const f of FOLKS) f.b = makeBean(cast, f.c, { acc: f.acc });
    const dustLayer = el("g", {}, mid);
    const puffs = [];
    for (let i = 0; i < 60; i++) puffs.push(el("circle", { r: 10, fill: "#9aa6dd", opacity: 0 }, dustLayer));
    const particles = el("g", {}, mid);
    const leaves = [];
    for (let i = 0; i < 46; i++) {
      const kind = i % 3;
      const e = kind === 0
        ? el("path", { d: "M0 -7 Q 6 0 0 7 Q -6 0 0 -7Z", fill: "#3f9a4a", stroke: NAVY, "stroke-width": 1.5 }, particles)
        : el("rect", { x: -5, y: -7, width: 10, height: 14, rx: 2, fill: ["#e8414a", "#ffcf3f", "#3a8de0", "#f07ad0"][i % 4] }, particles);
      leaves.push({ e, x0: 1900 + rnd() * 700, y0: 80 + rnd() * 820, v: 900 + rnd() * 700, t0: 2.15 + rnd() * 1.6, ph: rnd() * 6.28, spin: 300 + rnd() * 600 });
    }
    const smokes = lanterns.map((ln) => {
      const g = el("g", { opacity: 0 }, mid);
      const cs = [0, 1, 2].map((k) => el("circle", { r: 12, fill: "#c9d0f0", opacity: 0.7 }, g));
      return { g, cs };
    });
    const tint = el("rect", { x: -600, y: -1200, width: 3200, height: 2700, fill: "#232c6e", style: "mix-blend-mode:multiply" }, mid);
    const glows = el("g", { style: "mix-blend-mode:screen" }, mid);
    const lanternGlows = lanterns.map((ln) => el("circle", { r: 170, fill: "url(#warm)" }, glows));
    const floorGlows = lanterns.map((ln) => el("ellipse", { cx: ln.x, cy: 820, rx: 170, ry: 36, fill: "url(#warm)", opacity: 0.6 }, reflections));
    const ghostLayer = el("g", {}, mid);
    const G = [0, 1, 2, 3].map((i) => makeGhost(ghostLayer, i === 0));
    // Лунный луч на корону в финале.
    const beam = el("g", { opacity: 0, style: "mix-blend-mode:screen" }, mid);
    el("path", { d: "M-60 -700 L60 -700 L170 0 L-170 0Z", fill: "url(#beamG)" }, beam);
    el("ellipse", { cx: 0, cy: 0, rx: 190, ry: 34, fill: "url(#warmSmall)", opacity: 0.35 }, beam);
    const crownFree = el("g", { opacity: 0 }, mid);
    crownShape(crownFree);
    const glint = el("path", { d: "M0 -26 L5 -5 L26 0 L5 5 L0 26 L-5 5 L-26 0 L-5 -5Z", fill: "#fffbe0", opacity: 0 }, mid);

    // Передний план (размыт): флажки в углу и столбик.
    const fg = S.L.fg;
    const fgRope = el("path", { d: "M-100 40 Q 300 160 700 -40", fill: "none", stroke: "#120a1e", "stroke-width": 10, filter: "url(#blur6)" }, fg);
    const fgFlags = [];
    for (let i = 0; i < 7; i++) {
      const u = i / 6, x = -100 + 800 * u, y = (1 - u) * (1 - u) * 40 + 2 * u * (1 - u) * 160 + u * u * -40;
      fgFlags.push([el("path", { d: "M-34 0 L34 0 L0 66Z", fill: ["#6a1622", "#6b5512", "#16376e"][i % 3], filter: "url(#blur6)" }, fg), x, y, i]);
    }
    el("rect", { x: 0, y: 0, width: 1920, height: 1080, fill: "url(#vignette)" }, S.L.ui);

    const bPink = B.bubble(S.L.ui, ["Призраки!!"], 300, 92);
    const bKing = B.bubble(S.L.ui, ["Отпустите!", "Я король!"], 330, 140);
    const bLead = B.bubble(S.L.ui, ["Вот и устроишь праздник —", "только для нас!"], 680, 140);
    const sWhoosh = B.sfx(S.L.ui, "ФЬЮ-У-У!", 86, "#9fe0ff", "#1d2f7a");
    const sDing = B.sfx(S.L.ui, "ДЗЫНЬ!", 74, "#ffd23f", "#2b3f9a");
    const sHaha = B.sfx(S.L.ui, "ХА-ХА-ХА!", 60, "#ffffff", "#6a1660");

    // ═══════════════════════ Траектории ═══════════════════════
    const KING_X = 1130, KING_Y = 694, KING_S = 2.35;
    const GRAB = 4.05, AWAY = 6.4, POP = 7.0;
    function kingPos(t) {
      if (t < AWAY) return [KING_X, KING_Y];
      return K(t, [[AWAY, [KING_X, KING_Y]], [8.6, [1260, -620], "inQ"]]);
    }
    const kingLift = (t) => (t < GRAB ? 0 : 60 * E.outBack(seg(t, GRAB, GRAB + 0.35)) + 8 * Math.sin(t * 7));
    const ghostPath = [
      (t) => t < 4.0 ? K(t, [[2.05, [2250, -260]], [2.8, [1560, 330], "outC"], [3.4, [1460, 300], "io"], [4.0, [1440, 360], "io"]])
        : t < AWAY ? [1440 + Math.sin(t * 2.2) * 14, 360 + Math.sin(t * 3.1) * 12]
        : (() => { const [kx, ky] = kingPos(t); return [lerp(1440, kx + 240, seg(t, AWAY, AWAY + 0.5)), lerp(360, ky - kingLift(t) - 200, seg(t, AWAY, AWAY + 0.5))]; })(),
      (t) => [K(t, [[2.15, 2350], [3.75, -380, "lin"]]), 248 + Math.sin(seg(t, 2.15, 3.75) * Math.PI * 3) * 46 - 30 * seg(t, 2.15, 3.75)],
      (t) => { const [kx, ky] = kingPos(t), lift = kingLift(t); return t < GRAB ? K(t, [[3.15, [-300, 60]], [GRAB, [kx - 178, ky - 100], "outC"]]) : [kx - 178 + Math.sin(t * 5) * 6, ky - lift - 100 + Math.sin(t * 6) * 8]; },
      (t) => { const [kx, ky] = kingPos(t), lift = kingLift(t); return t < GRAB ? K(t, [[3.3, [2300, 40]], [GRAB + 0.05, [kx + 172, ky - 96], "outC"]]) : [kx + 172 + Math.sin(t * 5 + 1) * 6, ky - lift - 96 + Math.sin(t * 6 + 1) * 8]; },
    ];
    const GHOST_FROM = [2.05, 2.15, 3.15, 3.3];
    const GHOST_S = [2.05, 1.55, 1.5, 1.5];
    // Когда гаснет фонарь: первый момент, когда призрак проходит ближе 120 px.
    for (const ln of lanterns) {
      for (let t = 2; t < 5 && ln.out === Infinity; t += 1 / 120)
        for (let g = 0; g < 4; g++) {
          if (t < GHOST_FROM[g]) continue;
          const [x, y] = ghostPath[g](t);
          if (Math.hypot(x - ln.x, y - (ln.y + 60)) < 130) { ln.out = t; break; }
        }
    }
    // Корона: слетает с головы короля в момент рывка вверх, падает на помост, подпрыгивает и ложится.
    const CROWN_FLOOR = 664;
    const crown0 = (() => { const [kx, ky] = kingPos(POP); return [kx + 12 * KING_S, ky - kingLift(POP) - 100 * KING_S]; })();
    const CV = [170, -560], GRAV = 2000;
    const tFall = (-CV[1] + Math.sqrt(CV[1] ** 2 + 2 * GRAV * (CROWN_FLOOR - crown0[1]))) / GRAV;
    const LANDT = POP + tFall;
    function crownAt(t) {
      if (t < LANDT) { const u = t - POP; return [crown0[0] + CV[0] * u, crown0[1] + CV[1] * u + 0.5 * GRAV * u * u, u * 720]; }
      const u = t - LANDT;
      const x = crown0[0] + CV[0] * tFall + 110 * (1 - Math.exp(-3 * u));
      const hop = u < 0.3 ? -(260 * u - 0.5 * 1730 * u * u) : 0;
      const rot = 16 + 34 * Math.exp(-4 * u) * Math.cos(15 * u);
      return [x, CROWN_FLOOR + hop, rot];
    }

    // Где легла корона и как стоит камера в последнем кадре — с этого начинается утро (сцена morning).
    { const [x, y, r] = crownAt(LANDT + 5); B.shared = { ...(B.shared || {}), crownRest: [x, y, r], crownScale: KING_S, endCam: { x: x - 960, y: 70, z: 1.7 } }; }
    // ═══════════════════════ Кадр ═══════════════════════
    return function render(t) {
      // Камера: лёгкий наезд, тряска при налёте, подъём за похитителями, наезд на корону.
      const shake = 10 * Math.sin(Math.PI * seg(t, 2.2, 3.1)) + 6 * Math.sin(Math.PI * seg(t, GRAB, GRAB + 0.4));
      S.cam.sx = Math.sin(t * 61) * shake; S.cam.sy = Math.cos(t * 47) * shake * 0.7;
      const [cx] = crownAt(Math.max(t, LANDT + 1));
      // После «ДЗЫНЬ!» (корона упала внизу кадра) камера опускается к короне — звук её позвал.
      const CALL = LANDT + 0.15;
      S.cam.x = K(t, [[0, 40], [GRAB, 40], [GRAB + 0.7, 190, "io"], [AWAY, 190], [CALL, 190], [CALL + 1.0, cx - 960, "io"]]);
      S.cam.y = K(t, [[0, 70], [2.1, 30, "io"], [GRAB, 30], [GRAB + 0.7, 20, "io"], [AWAY, 20], [7.5, -280, "io"], [CALL, -280], [CALL + 1.0, 70, "io"]]);
      S.cam.z = K(t, [[0, 1.24], [1.7, 1.26, "lin"], [2.5, 1.1, "io"], [GRAB, 1.1], [GRAB + 0.7, 1.3, "io"], [AWAY, 1.32, "lin"], [7.5, 1.0, "io"], [CALL, 1.0], [CALL + 1.0, 1.55, "io"], [DURATION, 1.7, "lin"]]);
      S.apply();

      B.twinkle(stars, t);
      // Ветер: до налёта слабый, порыв 1.4–2.1, буря во время налёта.
      const wind = 0.25 + 0.5 * Math.sin(Math.PI * seg(t, 1.3, 2.2)) + 1.1 * Math.sin(Math.PI * seg(t, 2.1, 4.6));
      P.wave(t, wind);
      for (const [f, x, y, i] of fgFlags) tr(f, x, y, Math.sin(t * 4 + i) * 9 * wind);

      // Фонари: качаются от ветра; гаснут, когда над ними пролетает призрак (рывок, дымок).
      let lit = 0;
      lanterns.forEach((ln, i) => {
        const on = t < ln.out;
        const kick = on ? 0 : 38 * Math.exp(-3 * (t - ln.out)) * Math.sin(10 * (t - ln.out));
        tr(ln.g, ln.x, ln.y, Math.sin(t * 3 + i) * 6 * wind + kick);
        ln.body.setAttribute("fill", on ? "#ffb347" : "#8a7a8f");
        show(ln.inner, on ? 0.85 : 0);
        const flick = on ? 0.9 + 0.1 * Math.sin(t * 17 + i * 3) : 0;
        lanternGlows[i].setAttribute("cx", f1(ln.x + Math.sin((Math.sin(t * 3 + i) * 6 * wind + kick) * Math.PI / 180) * -62));
        lanternGlows[i].setAttribute("cy", f1(ln.y + 62));
        show(lanternGlows[i], flick);
        show(floorGlows[i], on ? 0.55 * flick : 0);
        if (on) lit++;
        const u = t - ln.out, sm = smokes[i];
        show(sm.g, u > 0 && u < 1.6 ? 1 - u / 1.6 : 0);
        if (u > 0 && u < 1.6) sm.cs.forEach((c, k) => { c.setAttribute("cx", f1(ln.x - 10 + k * 10 - u * 40)); c.setAttribute("cy", f1(ln.y + 40 - u * (70 + k * 25))); c.setAttribute("r", f1(10 + u * (18 + k * 6))); });
      });
      show(tint, 0.18 + 0.4 * (1 - lit / lanterns.length));

      // Горожане: празднуют → порыв ветра, смотрят вверх → крик → разбегаются влево.
      let puffN = 0;
      for (const f of FOLKS) {
        const p = { x: f.x, y: f.y, s: f.s, dir: f.dir, t, wind };
        const i = FOLKS.indexOf(f);
        if (t < 1.75) {
          const hop = Math.max(0, Math.sin(t * 2 * Math.PI * 2.1 + i * 1.3));
          Object.assign(p, { lift: hop * 16, sq: 1 + (hop < 0.08 ? 0.06 : -0.03), armF: 150 + Math.sin(t * 9 + i) * 18, armB: -150 - Math.sin(t * 9 + i) * 18, eyes: "happy", mouth: "smile" });
        } else if (t < f.react) {
          Object.assign(p, { eyes: "wide", look: [1, -3], mouth: "o", armF: 20, armB: -20 });
        } else {
          const u = t - f.react;
          const jolt = u < 0.3 ? Math.sin(Math.PI * u / 0.3) * 26 : 0;
          Object.assign(p, { eyes: "wide", look: [-2, -1], mouth: "scream", brows: "worried", drops: clamp(u * 4), lift: jolt, armF: 150 + Math.sin(t * 22) * 14, armB: -150 - Math.sin(t * 22) * 14 });
          if (t > f.react + 0.12) p.dir = -1;
          if (t > f.run) {
            const r = t - f.run, ph = r * 2 * Math.PI * 3.3;
            p.x = f.x - (420 * r * r + 240 * r);
            p.lift = Math.abs(Math.sin(ph)) * 14;
            p.legF = Math.sin(ph) * 40; p.legB = -Math.sin(ph) * 40;
            p.armF = 140 + Math.sin(ph) * 30; p.armB = -140 + Math.sin(ph) * 30;
            p.tilt = 13; p.sq = 1 + Math.cos(ph * 2) * 0.03; p.look = [3, -1];
            p.wind = 1.4;
            // Пыль из-под ног на каждом шаге.
            for (let k = 0; k < 14 && puffN < puffs.length; k++) {
              const ts = f.run + k / 6.6, a = t - ts;
              if (a < 0 || a > 0.5) continue;
              const xs = f.x - (420 * (ts - f.run) ** 2 + 240 * (ts - f.run)) + 24 * f.s;
              const c = puffs[puffN++];
              c.setAttribute("cx", f1(xs + a * 60)); c.setAttribute("cy", f1(f.y - 6 - a * 30));
              c.setAttribute("r", f1((8 + a * 40) * f.s * 0.7)); c.setAttribute("opacity", (0.55 * (1 - a / 0.5)).toFixed(3));
            }
          }
        }
        poseBean(f.b, p);
      }
      for (let k = puffN; k < puffs.length; k++) puffs[k].setAttribute("opacity", 0);

      // Король: машет → смотрит вверх → испуг → его хватают, дрыгает ногами → уносят.
      const [kx, ky] = kingPos(t), lift = kingLift(t);
      const kp = { x: kx, y: ky, s: KING_S, dir: 1, t, lift, noCrown: t >= POP };
      if (t < 1.8) {
        const w = Math.sin(t * 2 * Math.PI * 1.6);
        Object.assign(kp, { eyes: t % 1.7 > 1.55 ? "happy" : "open", mouth: "smile", armB: -125 + w * 22, armF: 24, tilt: w * 2, lift: Math.max(0, Math.sin(t * 2 * Math.PI * 0.8)) * 6 });
      } else if (t < 2.3) {
        Object.assign(kp, { eyes: "wide", look: [2, -3], mouth: "o", armB: -30, armF: 20 });
      } else if (t < GRAB) {
        const jolt = t < 2.6 ? Math.sin(Math.PI * seg(t, 2.3, 2.6)) * 24 : 0;
        Object.assign(kp, { eyes: "wide", look: [3, -1], mouth: "scream", brows: "worried", drops: 1, lift: jolt, armF: 150 + Math.sin(t * 30) * 8, armB: -150 - Math.sin(t * 30) * 8, tilt: -4 + Math.sin(t * 40) * 1.5 });
      } else {
        const k = t * 2 * Math.PI * 4.4;
        Object.assign(kp, { eyes: "wide", look: [3, 0], mouth: "scream", brows: "worried", drops: 1, legF: 36 * Math.sin(k), legB: -36 * Math.sin(k), armF: 125 + 28 * Math.sin(t * 19), armB: -125 - 28 * Math.sin(t * 19 + 1), tilt: Math.sin(t * 6) * 6, capeFlap: t > AWAY ? 1 : 0.5 });
      }
      poseBean(king, kp);

      // Призраки.
      G.forEach((g, i) => {
        const t0 = GHOST_FROM[i];
        if (t < t0) { show(g.root, 0); g.trail.setAttribute("opacity", 0); return; }
        show(g.root, 1);
        const [x, y] = ghostPath[i](t), [x2, y2] = ghostPath[i](t - 1 / 60);
        const vx = (x - x2) * 60, vy = (y - y2) * 60, speed = Math.hypot(vx, vy);
        const trail = [];
        for (let k = 0; k < 9; k++) { const tk = t - k * 0.03; if (tk >= t0) trail.push(ghostPath[i](tk)); }
        let dir = vx < -40 ? -1 : vx > 40 ? 1 : i === 0 ? -1 : i === 2 ? 1 : -1;
        if (t >= GRAB && (i === 2 || i === 3)) dir = i === 2 ? 1 : -1;
        if (t >= AWAY) dir = i === 0 ? -1 : dir;
        const rot = speed > 200 ? clamp(Math.atan2(vy, Math.abs(vx)) * 180 / Math.PI * 0.5, -30, 30) * (dir === -1 ? -1 : 1) : Math.sin(t * 3 + i) * 4;
        const laugh = i === 0 && t > 7.25 && t < 8.4 || (i !== 0 && t > AWAY + 0.4 && Math.sin(t * 3 + i) > 0.6);
        poseGhost(g, { x, y, s: GHOST_S[i], dir, rot, t, ph: i * 1.7, stretch: 1 + clamp(speed / 3000, 0, 0.3), speed,
          arms: t >= GRAB - 0.25 && (i === 2 || i === 3) ? "grab" : i === 0 && t > 4.6 && t < AWAY ? "point" : "fly",
          face: laugh ? "laugh" : "angry", trail });
      });

      // Корона.
      if (t >= POP) {
        const [x, y, r] = crownAt(t);
        show(crownFree, 1); tr(crownFree, x, y, r, KING_S);
      } else show(crownFree, 0);
      const gu = seg(t, CALL + 1.35, CALL + 1.8);
      { const [bx] = crownAt(Math.max(t, LANDT + 1)); tr(beam, bx, CROWN_FLOOR + 4); show(beam, E.io(seg(t, CALL + 0.6, CALL + 1.4))); }
      const [gx, gy] = crownAt(Math.max(t, LANDT));
      show(glint, Math.sin(Math.PI * gu)); tr(glint, gx + 30, gy - 70, gu * 90, 0.4 + Math.sin(Math.PI * gu) * 1.6);

      // Листья и конфетти в порыве.
      for (const lf of leaves) {
        const u = t - lf.t0;
        if (u < 0 || u > 2.6) { show(lf.e, 0); continue; }
        show(lf.e, 1);
        tr(lf.e, lf.x0 - lf.v * u, lf.y0 + Math.sin(u * 5 + lf.ph) * 50 + u * 60, lf.spin * u, 1.6, 1.6 * Math.cos(u * 9 + lf.ph));
      }


      // Пузыри и звуковые надписи (экранные координаты, привязаны к говорящим).
      const pink = FOLKS.find((f) => f.shout);
      const [px, py] = S.toScreen(pink.b.root.transform.baseVal.consolidate().matrix.e, pink.y - pink.s * 120);
      placeBubble(bPink, t, 2.55, 3.8, px + 120, py - 70, px + 10, py + 10);
      const [hx, hy] = S.toScreen(kx + 20, ky - lift - KING_S * 112);
      placeBubble(bKing, t, 4.25, 5.55, clamp(hx - 330, 240, 1680), clamp(hy - 60, 130, 900), hx - 60, hy + 10);
      const [lx, ly] = ghostPath[0](t), [lsx, lsy] = S.toScreen(lx, ly - 80);
      placeBubble(bLead, t, 5.65, 7.25, clamp(lsx + 160, 370, 1550), clamp(lsy - 150, 110, 900), lsx + 20, lsy + 10);
      const wk = E.outBack(seg(t, 2.2, 2.45)) * (1 - E.inC(seg(t, 3.0, 3.25)));
      show(sWhoosh, wk > 0.01 ? 1 : 0); tr(sWhoosh, 1640, 330, -9 + Math.sin(t * 20) * 2, Math.max(0.001, wk));
      const [dsx, dsy] = S.toScreen(gx + 60, gy - 120);
      const dk = E.outBack(seg(t, LANDT, LANDT + 0.22)) * (1 - E.inC(seg(t, LANDT + 1.0, LANDT + 1.25)));
      show(sDing, dk > 0.01 ? 1 : 0); tr(sDing, dsx + 120, dsy - 40, 8, Math.max(0.001, dk * 0.85));
      const [hhx, hhy] = S.toScreen(lx + 40, ly - 160);
      const hk = E.outBack(seg(t, 7.3, 7.5)) * (1 - E.inC(seg(t, 8.1, 8.3)));
      show(sHaha, hk > 0.01 ? 1 : 0); tr(sHaha, clamp(hhx - 300, 300, 1620), clamp(hhy, 120, 960), -6 + Math.sin(t * 25) * 3, Math.max(0.001, hk * 0.7));
    }
  },
});
