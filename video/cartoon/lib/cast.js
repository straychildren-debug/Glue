// Куклы и надписи: бобы (герои, горожане, король, старый боб), призраки, корона,
// пузыри реплик, звуковые надписи, плашки рассказчика. Позы задаются функциями pose*(кукла, параметры).
(() => {
  const { el, f1, clamp, seg, E, smooth, tr, show, NAVY, COLORS, pop } = B;

  /** Фигура с обводкой: снизу — тёмный контур (толстая обводка), сверху — заливка; так контур только снаружи. */
  function outlined(parent, shapes, fill, sw = 3.4) {
    const g = el("g", {}, parent);
    for (const [tag, a] of shapes) el(tag, { ...a, fill: NAVY, stroke: NAVY, "stroke-width": sw * 2, "stroke-linejoin": "round" }, g);
    for (const [tag, a] of shapes) el(tag, { ...a, fill }, g);
    return g;
  }
  const BODY = "M2 -100 C 24 -100 35 -82 35 -58 C 35 -32 26 -14 0 -14 C -24 -14 -35 -30 -35 -55 C -35 -82 -20 -100 2 -100 Z";
  const LEG = [["rect", { x: -7.5, y: -4, width: 15, height: 22, rx: 7.5 }], ["ellipse", { cx: 4, cy: 18, rx: 11, ry: 7.5 }]];
  const ARM = [["rect", { x: -6.5, y: -4, width: 13, height: 32, rx: 6.5 }]];
  const EYES = [[6, -68], [20, -68]];

  function crownShape(g) {
    el("path", { d: "M-28 0 L-31 -27 L-15 -13 L-4 -33 L6 -13 L19 -29 L28 -12 L27 0Z", fill: NAVY, stroke: NAVY, "stroke-width": 7, "stroke-linejoin": "round" }, g);
    el("path", { d: "M-28 0 L-31 -27 L-15 -13 L-4 -33 L6 -13 L19 -29 L28 -12 L27 0Z", fill: "url(#gold)" }, g);
    for (const [x, y] of [[-31, -29], [-4, -36], [19, -32]]) el("circle", { cx: x, cy: y, r: 4.5, fill: "url(#gold)", stroke: NAVY, "stroke-width": 2.5 }, g);
    el("rect", { x: -29, y: -9, width: 57, height: 10, rx: 3, fill: "#f0a814", stroke: NAVY, "stroke-width": 2.5 }, g);
    el("ellipse", { cx: -1, cy: -17, rx: 4.5, ry: 6, fill: "#e8313a", stroke: NAVY, "stroke-width": 2 }, g);
    el("ellipse", { cx: -17, cy: -14, rx: 3.5, ry: 4.6, fill: "#2f6fe0", stroke: NAVY, "stroke-width": 2 }, g);
    el("ellipse", { cx: 15, cy: -14, rx: 3.5, ry: 4.6, fill: "#3cc45a", stroke: NAVY, "stroke-width": 2 }, g);
    el("path", { d: "M-24 -6 L-20 -20", stroke: "#fff8c0", "stroke-width": 2.5, opacity: 0.8, "stroke-linecap": "round" }, g);
    return g;
  }

  /** Боб. opts: king, acc (hat/scarf/flower/glasses/cap/bow/grandpa), rim (цвет контрового света). */
  function makeBean(parent, color, opts = {}) {
    const b = { color, opts };
    b.root = el("g", {}, parent);
    b.shadow = el("ellipse", { cx: 0, cy: 0, rx: 46, ry: 10, fill: opts.shadow || "#070b28", opacity: 0.5, filter: "url(#blur3)" }, b.root);
    b.flip = el("g", {}, b.root);
    b.body = el("g", {}, b.flip);
    const fill = `url(#g-${color})`, [, , dark] = COLORS[color];
    if (opts.king) {
      b.cape = el("path", { fill: "url(#cape)", stroke: NAVY, "stroke-width": 3.4 }, b.body);
      b.capeTrim = el("path", { fill: "none", stroke: "#fffaf0", "stroke-width": 9, "stroke-linecap": "round" }, b.body);
      b.capeDots = el("g", {}, b.body);
      // Горностаевый воротник — сплошная полоса за плечами (виден по бокам тела).
      el("path", { d: "M-44 -58 Q -30 -86 2 -88 Q 34 -86 46 -56", fill: "none", stroke: NAVY, "stroke-width": 21, "stroke-linecap": "round" }, b.body);
      el("path", { d: "M-44 -58 Q -30 -86 2 -88 Q 34 -86 46 -56", fill: "none", stroke: "#fffaf0", "stroke-width": 14, "stroke-linecap": "round" }, b.body);
      for (const [x, y] of [[-40, -66], [-33, -77], [38, -66], [31, -77]]) el("path", { d: `M${x} ${y} l -1.5 4 l 3 0Z`, fill: NAVY }, b.body);
    }
    b.armB = el("g", {}, b.body); outlined(b.armB, ARM, dark);
    b.legB = el("g", {}, b.body); outlined(b.legB, LEG, dark);
    b.legF = el("g", {}, b.body); outlined(b.legF, LEG, fill);
    outlined(b.body, [["path", { d: BODY }]], fill);
    el("ellipse", { cx: -16, cy: -82, rx: 5, ry: 11, fill: "#fff", opacity: 0.75, transform: "rotate(28 -16 -82)" }, b.body);
    el("ellipse", { cx: -25, cy: -64, rx: 2.4, ry: 4.4, fill: "#fff", opacity: 0.5 }, b.body);
    b.rim = el("path", { d: "M31 -70 Q 36 -50 26 -26", fill: "none", stroke: opts.rim || "#9fb4ff", "stroke-width": 3, opacity: 0.45, "stroke-linecap": "round" }, b.body);
    // Лицо.
    const face = el("g", {}, b.body);
    b.face = face;
    b.eyes = {};
    b.eyes.open = el("g", {}, face);
    for (const [x, y] of EYES) {
      el("ellipse", { cx: x, cy: y, rx: 4.3, ry: 7.4, fill: NAVY }, b.eyes.open);
      el("circle", { cx: x + 1.4, cy: y - 3, r: 1.5, fill: "#fff" }, b.eyes.open);
    }
    b.eyes.happy = el("g", {}, face);
    for (const [x, y] of EYES) el("path", { d: `M${x - 4.5} ${y + 2} Q ${x} ${y - 6} ${x + 4.5} ${y + 2}`, fill: "none", stroke: NAVY, "stroke-width": 2.8, "stroke-linecap": "round" }, b.eyes.happy);
    b.eyes.closed = el("g", {}, face);
    for (const [x, y] of EYES) el("path", { d: `M${x - 4.5} ${y} Q ${x} ${y + 4} ${x + 4.5} ${y}`, fill: "none", stroke: NAVY, "stroke-width": 2.6, "stroke-linecap": "round" }, b.eyes.closed);
    b.eyes.wide = el("g", {}, face);
    b.pupils = [];
    for (const [x, y] of EYES) {
      el("ellipse", { cx: x, cy: y - 1, rx: 6, ry: 9, fill: "#fff", stroke: NAVY, "stroke-width": 2.2 }, b.eyes.wide);
      b.pupils.push(el("circle", { cx: x, cy: y, r: 2.4, fill: NAVY }, b.eyes.wide));
    }
    b.brows = {
      worried: el("path", { d: "M0 -79 L9 -82 M16 -82 L25 -79", stroke: NAVY, "stroke-width": 2.6, "stroke-linecap": "round", fill: "none" }, face),
      angry: el("path", { d: "M0 -82 L10 -78 M16 -78 L26 -82", stroke: NAVY, "stroke-width": 3, "stroke-linecap": "round", fill: "none" }, face),
      up: el("path", { d: "M1 -82 Q 6 -85 10 -82 M16 -82 Q 21 -85 25 -82", stroke: NAVY, "stroke-width": 2.6, "stroke-linecap": "round", fill: "none" }, face),
    };
    b.mouth = {
      smile: el("path", { d: "M9 -53 Q 14 -47 19 -53", fill: "none", stroke: NAVY, "stroke-width": 2.6, "stroke-linecap": "round" }, face),
      flat: el("path", { d: "M10 -51 L18 -51", fill: "none", stroke: NAVY, "stroke-width": 2.6, "stroke-linecap": "round" }, face),
      frown: el("path", { d: "M9 -49 Q 14 -54 19 -49", fill: "none", stroke: NAVY, "stroke-width": 2.6, "stroke-linecap": "round" }, face),
      o: el("ellipse", { cx: 14, cy: -50, rx: 3.6, ry: 4.6, fill: "#6e1626", stroke: NAVY, "stroke-width": 2 }, face),
      scream: el("g", {}, face),
      grin: el("g", {}, face),
    };
    el("path", { d: "M6 -56 Q 14 -58 22 -56 Q 23 -42 14 -40 Q 5 -42 6 -56Z", fill: "#6e1626", stroke: NAVY, "stroke-width": 2.2 }, b.mouth.scream);
    el("ellipse", { cx: 14, cy: -44, rx: 4.5, ry: 2.6, fill: "#ff7a8e" }, b.mouth.scream);
    el("path", { d: "M5 -55 Q 14 -53 23 -55 Q 21 -43 14 -43 Q 7 -43 5 -55Z", fill: "#6e1626", stroke: NAVY, "stroke-width": 2.2 }, b.mouth.grin);
    el("ellipse", { cx: 14, cy: -46.5, rx: 4.5, ry: 2.3, fill: "#ff7a8e" }, b.mouth.grin);
    if (opts.king) {
      el("path", { d: "M14 -57 C 6 -63 -5 -61 -8 -52 C -3 -56 4 -54 8 -51 C 10 -50 12 -50 14 -52 C 16 -50 18 -50 20 -51 C 24 -54 31 -56 36 -52 C 33 -61 22 -63 14 -57Z", fill: "#6b3a1e", stroke: NAVY, "stroke-width": 2 }, face);
      b.crown = crownShape(el("g", {}, b.body));
    }
    b.drops = el("g", { opacity: 0 }, b.body);
    for (const [x, y, s] of [[-30, -92, 1], [38, -88, 0.8]]) el("path", { d: `M${x} ${y} q ${-5 * s} ${9 * s} 0 ${12 * s} q ${5 * s} ${-3 * s} 0 ${-12 * s}Z`, fill: "#8fd8ff", stroke: NAVY, "stroke-width": 1.6 }, b.drops);
    // Аксессуары.
    const acc = opts.acc;
    if (acc === "hat") {
      const g = el("g", {}, b.body);
      el("path", { d: "M-20 -96 Q -18 -122 2 -122 Q 22 -122 23 -96Z", fill: "#f0cd78", stroke: NAVY, "stroke-width": 3 }, g);
      el("rect", { x: -20, y: -104, width: 43, height: 7, fill: "#d8423a" }, g);
      el("ellipse", { cx: 2, cy: -96, rx: 38, ry: 8, fill: "#e8bf62", stroke: NAVY, "stroke-width": 3 }, g);
    } else if (acc === "scarf") {
      b.scarfTail = el("path", { fill: "#e63c2e", stroke: NAVY, "stroke-width": 3, "stroke-linejoin": "round" }, b.body);
      el("ellipse", { cx: 0, cy: -36, rx: 33, ry: 7.5, fill: "#e63c2e", stroke: NAVY, "stroke-width": 3 }, b.body);
    } else if (acc === "flower") {
      const g = el("g", { transform: "translate(-12 -98)" }, b.body);
      for (let k = 0; k < 5; k++) el("ellipse", { cx: 0, cy: -8, rx: 5, ry: 8, fill: "#fff", stroke: NAVY, "stroke-width": 2, transform: `rotate(${k * 72})` }, g);
      el("circle", { r: 4.5, fill: "#ffd23f", stroke: NAVY, "stroke-width": 2 }, g);
    } else if (acc === "glasses") {
      for (const [x, y] of EYES) el("circle", { cx: x, cy: y, r: 8.5, fill: "none", stroke: NAVY, "stroke-width": 2.4 }, b.body);
      el("path", { d: "M10.5 -70 Q 13 -73 15.5 -70", fill: "none", stroke: NAVY, "stroke-width": 2.4 }, b.body);
    } else if (acc === "cap") {
      el("path", { d: "M-27 -88 Q -24 -118 2 -118 Q 28 -118 30 -90Z", fill: "#2b4fb8", stroke: NAVY, "stroke-width": 3 }, b.body);
      el("path", { d: "M-2 -116 Q 18 -114 26 -96 L 8 -98Z", fill: "#fff", opacity: 0.9 }, b.body);
      el("ellipse", { cx: 32, cy: -89, rx: 17, ry: 4.5, fill: "#23409a", stroke: NAVY, "stroke-width": 3 }, b.body);
    } else if (acc === "bow") {
      const g = el("g", { transform: "translate(14 -100) rotate(14)" }, b.body);
      el("path", { d: "M0 0 L-17 -10 Q -21 0 -17 10Z M0 0 L17 -10 Q 21 0 17 10Z", fill: "#ff7eb6", stroke: NAVY, "stroke-width": 2.6, "stroke-linejoin": "round" }, g);
      el("circle", { r: 5, fill: "#ff5fa2", stroke: NAVY, "stroke-width": 2.6 }, g);
      el("path", { d: "M-12 -4 Q -9 -6 -6 -3", fill: "none", stroke: "#fff", "stroke-width": 1.6, opacity: 0.8 }, g);
    } else if (acc === "grandpa") {
      // Борода, пушистые брови, круглые очки.
      el("path", { d: "M-6 -58 C -14 -48 -14 -28 -2 -14 C 2 -8 8 -6 10 -12 C 14 -4 22 -6 24 -14 C 34 -26 36 -46 30 -58 C 22 -50 4 -50 -6 -58Z", fill: "#fbfbf6", stroke: NAVY, "stroke-width": 2.8, "stroke-linejoin": "round" }, b.body);
      el("path", { d: "M2 -44 Q 8 -36 12 -46 M16 -40 Q 22 -30 26 -42", fill: "none", stroke: "#d6d6e6", "stroke-width": 2 }, b.body);
      el("path", { d: "M-2 -80 Q 6 -88 12 -80 M14 -80 Q 22 -88 28 -80", fill: "none", stroke: "#fbfbf6", "stroke-width": 5, "stroke-linecap": "round" }, b.body);
      for (const [x, y] of EYES) el("circle", { cx: x, cy: y, r: 8.2, fill: "#ffffff", "fill-opacity": 0.25, stroke: "#6b4a2a", "stroke-width": 2.2 }, b.body);
      el("path", { d: "M10.5 -70 Q 13 -73 15.5 -70", fill: "none", stroke: "#6b4a2a", "stroke-width": 2.2 }, b.body);
    }
    b.hold = el("g", {}, b.body); // предмет в поднятых руках (корона над головой)
    b.armF = el("g", {}, b.body); outlined(b.armF, ARM, fill);
    if (acc === "grandpa") {
      b.stick = el("g", {}, b.armF);
      el("rect", { x: -4, y: 6, width: 8, height: 98, rx: 4, fill: "#8b5a2b", stroke: NAVY, "stroke-width": 2.6 }, b.stick);
      el("path", { d: "M0 8 Q -2 -8 12 -6", fill: "none", stroke: NAVY, "stroke-width": 9, "stroke-linecap": "round" }, b.stick);
      el("path", { d: "M0 8 Q -2 -8 12 -6", fill: "none", stroke: "#8b5a2b", "stroke-width": 5, "stroke-linecap": "round" }, b.stick);
    }
    return b;
  }

  /** Поза боба. p: x, y (ступни, px), s, dir (1 вправо / -1), lift (px), sq (сплющивание), tilt (°),
      legF/legB/armF/armB (°), eyes (open/happy/closed/wide), mouth (smile/flat/frown/o/scream/grin),
      brows (worried/angry/up/null), look [dx,dy], drops (0–1), wind, capeFlap, noCrown, t. */
  function poseBean(b, p) {
    const s = p.s, lift = p.lift || 0;
    tr(b.root, p.x, p.y);
    const k = clamp(1 - lift / 260, 0.35, 1);
    b.shadow.setAttribute("rx", f1(46 * s * k)); b.shadow.setAttribute("ry", f1(10 * s * k));
    b.shadow.setAttribute("opacity", ((p.shadowOp ?? 0.5) * clamp(1 - lift / 300, 0.15, 1)).toFixed(3));
    b.flip.setAttribute("transform", `scale(${(p.dir * s).toFixed(3)} ${s.toFixed(3)})`);
    const sq = p.sq || 1;
    b.body.setAttribute("transform", `translate(0 ${f1(-lift / s)}) rotate(${f1(p.tilt || 0)}) scale(${(1 / Math.sqrt(sq)).toFixed(3)} ${sq.toFixed(3)})`);
    tr(b.legF, -12, -24, p.legF || 0); tr(b.legB, 12, -24, p.legB || 0);
    tr(b.armF, -31 + (p.armFx || 0), -56 + (p.armFy || 0), p.armF ?? 18);
    tr(b.armB, 30 + (p.armBx || 0), -58 + (p.armBy || 0), p.armB ?? -18);
    const eyes = p.eyes || "open";
    for (const n in b.eyes) show(b.eyes[n], n === eyes);
    for (const n in b.mouth) show(b.mouth[n], n === (p.mouth || "smile"));
    for (const n in b.brows) show(b.brows[n], n === p.brows);
    const [lx, ly] = p.look || [0, 0];
    b.pupils.forEach((e, i) => { e.setAttribute("cx", f1(EYES[i][0] + lx)); e.setAttribute("cy", f1(EYES[i][1] + ly)); });
    tr(b.eyes.open, lx * 0.6, ly * 0.6);
    show(b.drops, p.drops || 0);
    if (b.scarfTail) {
      const w = p.wind || 0, ph = p.t * 14;
      b.scarfTail.setAttribute("d", `M-26 -40 C ${f1(-44 - w * 10)} ${f1(-44 + Math.sin(ph) * 5 * w)} ${f1(-58 - w * 20)} ${f1(-30 + Math.sin(ph + 1) * 8 * w)} ${f1(-70 - w * 24)} ${f1(-34 + Math.sin(ph + 2) * 10 * w)} L ${f1(-66 - w * 22)} ${f1(-22 + Math.sin(ph + 2) * 10 * w)} C ${f1(-52 - w * 16)} ${f1(-20 + Math.sin(ph + 1) * 6 * w)} -40 -26 -22 -30Z`);
    }
    if (b.cape) {
      const fl = p.capeFlap || 0, ph = p.t * 11;
      const y1 = -26 + Math.sin(ph) * 8 * fl, y2 = -22 + Math.sin(ph + 1.7) * 10 * fl, xl = -46 - fl * 22, xr = 42 + fl * 8, ym = -14 + fl * 10;
      b.cape.setAttribute("d", `M-27 -68 Q ${f1(-44 - fl * 12)} -46 ${f1(xl)} ${f1(y1)} Q -4 ${f1(ym)} ${f1(xr)} ${f1(y2)} Q 42 -46 29 -68Z`);
      b.capeTrim.setAttribute("d", `M${f1(xl)} ${f1(y1)} Q -4 ${f1(ym)} ${f1(xr)} ${f1(y2)}`);
      b.capeDots.innerHTML = "";
      for (let n = 1; n < 7; n++) {
        const u = n / 7, x = (1 - u) ** 2 * xl + 2 * u * (1 - u) * -4 + u * u * xr, y = (1 - u) ** 2 * y1 + 2 * u * (1 - u) * ym + u * u * y2;
        el("circle", { cx: f1(x), cy: f1(y), r: 1.8, fill: NAVY }, b.capeDots);
      }
    }
    if (b.crown) { tr(b.crown, 4, -100, -8); show(b.crown, !p.noCrown); }
  }

  // ── Призраки.
  function makeGhost(parent, leader) {
    const g = { leader };
    g.root = el("g", {}, parent);
    g.trail = el("path", { fill: "none", stroke: "#dfe7ff", "stroke-width": 26, "stroke-linecap": "round", opacity: 0, filter: "url(#blur6)" }, parent);
    parent.insertBefore(g.trail, g.root);
    g.flip = el("g", {}, g.root);
    g.glow = el("path", { fill: "#ffffff", opacity: 0.45, filter: "url(#blur14)" }, g.flip);
    g.armB = el("ellipse", { rx: 10, ry: 13, fill: "#e6ecff", stroke: NAVY, "stroke-width": 3.2 }, g.flip);
    g.body = el("path", { fill: "url(#ghostFill)", stroke: NAVY, "stroke-width": 3.4, "stroke-linejoin": "round" }, g.flip);
    g.shade = el("path", { fill: "none", stroke: "#b8c6ff", "stroke-width": 4, opacity: 0.6, "stroke-linecap": "round" }, g.flip);
    const face = el("g", {}, g.flip);
    g.eyesAngry = el("g", {}, face);
    for (const x of [14, 31]) el("ellipse", { cx: x, cy: -6, rx: 4.6, ry: 7.2, fill: NAVY }, g.eyesAngry);
    el("path", { d: leader ? "M5 -19 L19 -12 M26 -12 L40 -19" : "M7 -17 L19 -12 M26 -12 L38 -17", stroke: NAVY, "stroke-width": 3.4, "stroke-linecap": "round" }, g.eyesAngry);
    g.eyesSad = el("g", {}, face);
    for (const x of [14, 31]) {
      el("ellipse", { cx: x, cy: -5, rx: 4.6, ry: 6.6, fill: NAVY }, g.eyesSad);
      el("circle", { cx: x + 1.4, cy: -8, r: 1.6, fill: "#fff" }, g.eyesSad);
    }
    el("path", { d: "M6 -14 L17 -18 M28 -18 L39 -14", stroke: NAVY, "stroke-width": 3, "stroke-linecap": "round" }, g.eyesSad);
    g.eyesLaugh = el("path", { d: "M9 -10 L17 -5 L9 0 M37 -10 L29 -5 L37 0", fill: "none", stroke: NAVY, "stroke-width": 3.2, "stroke-linecap": "round", "stroke-linejoin": "round" }, face);
    g.mouth = el("g", {}, face);
    el("path", { d: leader ? "M10 6 Q 24 24 38 4 Q 24 10 10 6Z" : "M13 7 Q 23 20 33 6 Q 23 10 13 7Z", fill: "#7a1a2a", stroke: NAVY, "stroke-width": 2.4, "stroke-linejoin": "round" }, g.mouth);
    el("ellipse", { cx: 24, cy: leader ? 15 : 13, rx: 5, ry: 2.6, fill: "#ff8a9a" }, g.mouth);
    g.mouthSad = el("path", { d: "M16 12 Q 23 6 30 12", fill: "none", stroke: NAVY, "stroke-width": 3, "stroke-linecap": "round" }, face);
    g.blush = el("g", {}, face);
    for (const x of [4, 42]) el("ellipse", { cx: x, cy: 6, rx: 5, ry: 2.6, fill: "#ff9ab0", opacity: 0.55 }, g.blush);
    g.armF = el("ellipse", { rx: 10, ry: 13, fill: "#f4f7ff", stroke: NAVY, "stroke-width": 3.2 }, g.flip);
    return g;
  }
  function ghostOutline(t, ph, stretch) {
    const pts = [[2, -46], [30, -38], [46, -12], [44, 14], [30, 36], [8, 46]];
    const N = 6, L0 = 64 * stretch;
    const wave = (u) => Math.sin(u * 4.5 - t * 8 + ph) * 8 * u;
    const bottom = [], top = [];
    for (let k = 0; k <= N; k++) {
      const u = k / N;
      bottom.push([-14 - L0 * u, 46 - 26 * u + wave(u) + Math.sin(u * 16 - t * 11 + ph) * 4 * u]);
      top.push([-26 - L0 * 0.92 * u, -38 + 46 * u + wave(u)]);
    }
    return smooth([...pts, ...bottom, ...top.reverse(), [-16, -45]]);
  }
  /** Поза призрака. p: x, y, s, dir, rot, t, ph, stretch, arms (fly/grab/up/point/hug), face (angry/laugh/sad), trail, speed. */
  function poseGhost(g, p) {
    tr(g.root, p.x, p.y, p.rot || 0, p.s);
    g.flip.setAttribute("transform", `scale(${p.dir} 1)`);
    const st = p.stretch || 1, d = ghostOutline(p.t, p.ph, st);
    g.body.setAttribute("d", d); g.glow.setAttribute("d", d);
    g.shade.setAttribute("d", `M-30 30 Q ${f1(-60 - 10 * st)} ${f1(26 + Math.sin(p.t * 9 + p.ph) * 5)} ${f1(-90 * st)} 18`);
    const a = p.arms || "fly", w = Math.sin(p.t * 10 + p.ph);
    if (a === "grab") { tr(g.armF, 34, 18, -40 + w * 10); tr(g.armB, 4, 22, -60 + w * 10); }
    else if (a === "up") { tr(g.armF, 30, -26, -20 + w * 8); tr(g.armB, -2, -30, 20 + w * 8); }
    else if (a === "point") { tr(g.armF, 44, 4, -70); tr(g.armB, -6, 24, 20); }
    else if (a === "hug") { tr(g.armF, 24, 22, 60); tr(g.armB, 4, 26, 50); }
    else { tr(g.armF, 26, 26, 30 + w * 6); tr(g.armB, -6, 28, 20 + w * 6); }
    const face = p.face || "angry";
    show(g.eyesAngry, face === "angry"); show(g.eyesLaugh, face === "laugh"); show(g.eyesSad, face === "sad" || face === "smile");
    show(g.mouth, face !== "sad" && face !== "smile"); show(g.mouthSad, face === "sad");
    if (face === "smile") { show(g.mouthSad, 1); g.mouthSad.setAttribute("d", "M16 8 Q 23 14 30 8"); }
    else g.mouthSad.setAttribute("d", "M16 12 Q 23 6 30 12");
    tr(g.mouth, 0, 0, 0, 1, face === "laugh" ? 1.35 : 1);
    const tp = p.trail || [];
    if (tp.length > 1) g.trail.setAttribute("d", "M" + tp.map(([x, y]) => `${f1(x)} ${f1(y)}`).join(" L"));
    g.trail.setAttribute("opacity", (0.25 * clamp((p.speed || 0) / 900)).toFixed(3));
  }

  // ── Текст: пузыри реплик, звуковые надписи, плашки рассказчика.
  function bubble(parent, lines, w, h, size = 44) {
    const g = el("g", { opacity: 0 }, parent);
    const tail = el("path", { fill: "#fff", stroke: NAVY, "stroke-width": 6, "stroke-linejoin": "round" }, g);
    el("rect", { x: -w / 2, y: -h / 2, width: w, height: h, rx: Math.min(h * 0.42, 60), fill: "#fff", stroke: NAVY, "stroke-width": 6 }, g);
    const tailCover = el("path", { fill: "#fff" }, g);
    lines.forEach((s, i) => {
      const t = el("text", { class: "t", x: 0, y: (i - (lines.length - 1) / 2) * size * 1.14 + size * 0.36, "text-anchor": "middle", "font-size": size, fill: NAVY }, g);
      t.textContent = s;
    });
    return { g, tail, tailCover, w, h };
  }
  /** Пузырь в экранных координатах: центр (cx, cy), хвостик к (ax, ay). */
  function placeBubble(b, t, tin, tout, cx, cy, ax, ay) {
    const k = pop(t, tin, tout);
    show(b.g, k > 0.01 ? 1 : 0);
    tr(b.g, cx, cy, 0, Math.max(0.001, k));
    const dx = ax - cx, dy = ay - cy, bx = clamp(dx * 0.25, -b.w * 0.3, b.w * 0.3), by = dy > 0 ? b.h / 2 - 4 : -b.h / 2 + 4;
    b.tail.setAttribute("d", `M${f1(bx - 22)} ${f1(by)} L${f1(dx * 0.75)} ${f1(dy * 0.75)} L${f1(bx + 22)} ${f1(by)}Z`);
    b.tailCover.setAttribute("d", `M${f1(bx - 19)} ${f1(by - Math.sign(dy) * 6)} L${f1(bx + 19)} ${f1(by - Math.sign(dy) * 6)} L${f1(bx)} ${f1(by + Math.sign(dy) * 10)}Z`);
  }
  function sfx(parent, text, size, fill, burstFill) {
    const g = el("g", { opacity: 0 }, parent);
    const burst = [];
    for (let i = 0; i < 18; i++) { const a = (i / 18) * Math.PI * 2, r = i % 2 ? size * 1.25 : size * 2.1; burst.push([Math.cos(a) * r * 1.6, Math.sin(a) * r]); }
    el("path", { d: "M" + burst.map((q) => q.map(f1).join(" ")).join(" L") + "Z", fill: burstFill, stroke: "#fff6c8", "stroke-width": 6, "stroke-linejoin": "round" }, g);
    const tx = el("text", { class: "t", x: 0, y: size * 0.36, "text-anchor": "middle", "font-size": size, fill, stroke: NAVY, "stroke-width": size * 0.12, "paint-order": "stroke", "letter-spacing": 2 }, g);
    tx.textContent = text;
    return g;
  }
  function placeSfx(g, t, tin, tout, x, y, rot = 0, scale = 1) {
    const k = pop(t, tin, tout, 0.22);
    show(g, k > 0.01 ? 1 : 0);
    tr(g, x, y, rot, Math.max(0.001, k * scale));
  }
  /** Плашка рассказчика: жёлтый прямоугольник с наклоном, как в комиксах. */
  function narration(parent, lines, w, size = 42) {
    const g = el("g", { opacity: 0 }, parent);
    const h = lines.length * size * 1.32 + 40;
    const bg = el("g", {}, g);
    el("rect", { x: -w / 2 + 8, y: -h / 2 + 8, width: w, height: h, fill: NAVY, opacity: 0.35 }, bg);
    el("rect", { x: -w / 2, y: -h / 2, width: w, height: h, fill: "#ffe36e", stroke: NAVY, "stroke-width": 5 }, bg);
    lines.forEach((s, i) => {
      const t = el("text", { class: "t", x: 0, y: (i - (lines.length - 1) / 2) * size * 1.32 + size * 0.36, "text-anchor": "middle", "font-size": size, fill: NAVY }, g);
      t.textContent = s;
    });
    return { g, bg, w, h };
  }
  function placeNarration(n, t, tin, tout, x, y, rot = -1.5) {
    const k = E.outC(seg(t, tin, tin + 0.35)) * (1 - E.inC(seg(t, tout, tout + 0.25)));
    show(n.g, k);
    tr(n.g, x, y - (1 - k) * 30);
    tr(n.bg, 0, 0, rot); // наклонён только фон, текст прямой
  }

  Object.assign(B, { outlined, BODY, EYES, crownShape, makeBean, poseBean, makeGhost, poseGhost, bubble, placeBubble, sfx, placeSfx, narration, placeNarration });
})();
