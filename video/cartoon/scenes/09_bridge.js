// Сцена 9 «Мост»: подвесной мост над морем облаков; четверо идут по нему цепочкой, держась за руки;
// «Чтобы пройти этот путь, им придётся держаться вместе.» — и падают буквы названия «Держись!».
B.addScene({
  id: "bridge",
  dur: 7.5,
  init(S) {
    const { el, f1, clamp, seg, lerp, E, K, tr, show, NAVY, makeBean, poseBean, crownShape } = B;
    const pal = B.PAL.dawn, rnd = B.rng(99);
    B.sky(S.L.sky, pal, "dawnBridge");
    B.sun(S.L.sky, 1600, 330, 100);
    for (const [x, y, s] of [[100, 120, 1.1], [800, 40, 0.9], [1900, 160, 1.0]]) B.cloud(S.L.sky, x, y, s, pal, 0.9);
    // Море облаков: дальние и ближние гряды.
    const cloudPal = { cloud: "#fff4ec", cloudShade: "#f2c2c0" };
    for (let i = 0; i < 9; i++) B.cloud(S.L.far, -500 + i * 360, 760 + (i % 2) * 40, 1.6, cloudPal, 1);
    for (const [x, y, w, h] of [[200, 520, 160, 120], [1720, 480, 150, 110]]) B.island(S.L.far, x, y, w, h, pal, { fall: true, stroke: "#8a6a8a", sw: 3, rock: "#c4a8c0", rockDark: "#a68aa6", grass: "#9ad07a", grassDark: "#7ab862" });
    const mid = S.L.mid;
    // Две скалы и мост между ними.
    B.island(mid, 120, 640, 640, 560, pal, { fall: true });
    B.island(mid, 1800, 640, 640, 560, pal, { fall: true });
    const ropeB = el("path", { fill: "none", stroke: "#6b4426", "stroke-width": 6 }, mid);
    const planks = Array.from({ length: 44 }, () => el("rect", { x: -9, y: -4, width: 18, height: 12, rx: 3, fill: "#a87444", stroke: NAVY, "stroke-width": 2.5 }, mid));
    const cast = el("g", {}, mid);
    const ropeT = el("path", { fill: "none", stroke: "#6b4426", "stroke-width": 5 }, mid);
    const posts = Array.from({ length: 12 }, () => el("line", { stroke: "#6b4426", "stroke-width": 3 }, mid));
    for (const x of [440, 1480]) { el("rect", { x: x - 9, y: 540, width: 18, height: 90, rx: 4, fill: "#8a5a34", stroke: NAVY, "stroke-width": 3.5 }, mid); }
    const H = [{ c: "red" }, { c: "blue" }, { c: "green" }, { c: "yellow", acc: "bow" }];
    for (const h of H) { h.b = makeBean(cast, h.c, { acc: h.acc, shadow: "#6a4a3a", rim: "#ffe6b0" }); h.s = h.c === "yellow" ? 1.35 : 1.65; }
    crownShape(el("g", { transform: "translate(-30 -30) rotate(-34) scale(0.95)" }, H[0].b.hold));
    for (let i = 0; i < 5; i++) B.cloud(S.L.fg, -600 + i * 640, 1060 + (i % 2) * 30, 1.8, cloudPal, 0.95);
    el("rect", { x: 0, y: 0, width: 1920, height: 1080, fill: "url(#vignetteDay)" }, S.L.ui);
    const narr = B.narration(S.L.ui, ["Чтобы пройти этот путь,", "им придётся держаться вместе."], 820);
    // Название: буквы в цветах героев.
    B.gradient("titleShadow", `<filter id="$ID" x="-20%" y="-20%" width="140%" height="160%"><feDropShadow dx="0" dy="14" stdDeviation="0" flood-color="${NAVY}" flood-opacity="1"/></filter>`);
    const TITLE = "Держись!", TC = ["#ec4640", "#3b7ff0", "#3ec75a", "#f9cf2c"];
    const title = el("g", {}, S.L.ui);
    const letters = [...TITLE].map((ch, i) => {
      const g = el("g", {}, title);
      const tx = el("text", { class: "t", x: 0, y: 0, "text-anchor": "middle", "font-size": 230, fill: TC[i % 4], stroke: NAVY, "stroke-width": 18, "paint-order": "stroke", "stroke-linejoin": "round", filter: "url(#titleShadow)" }, g);
      tx.textContent = ch;
      return { g, w: { "Д": 168, "е": 140, "р": 146, "ж": 196, "и": 148, "с": 132, "ь": 138, "!": 82 }[ch] };
    });
    const totalW = letters.reduce((a, l) => a + l.w, 0);
    let acc = -totalW / 2;
    for (const l of letters) { l.x = 960 + acc + l.w / 2; acc += l.w; }

    const A = 470, Bx = 1450, Y0 = 600;
    const sag = (t) => 120 + 14 * Math.sin(t * 2.2);
    const bridgeAt = (u, t) => { const x = lerp(A, Bx, u); return [x, Y0 + sag(t) * 4 * u * (1 - u) + Math.sin(t * 2.2 + u * 3) * 6 * Math.sin(Math.PI * u)]; };
    const TITLE_AT = 3.3;
    return function render(t) {
      S.cam.x = 20; S.cam.y = lerp(60, 30, E.io(seg(t, 0, 7.5))); S.cam.z = lerp(1.12, 1.22, E.io(seg(t, 0, 7.5)));
      S.apply();
      // Мост: канаты и доски по провисающей кривой, покачивается.
      const pts = [];
      for (let k = 0; k <= 24; k++) pts.push(bridgeAt(k / 24, t));
      ropeB.setAttribute("d", "M" + pts.map(([x, y]) => `${f1(x)} ${f1(y + 6)}`).join(" L"));
      ropeT.setAttribute("d", "M" + pts.map(([x, y]) => `${f1(x)} ${f1(y - 70)}`).join(" L"));
      planks.forEach((pl, k) => { const [x, y] = bridgeAt((k + 0.5) / planks.length, t); const [x2, y2] = bridgeAt((k + 1) / planks.length, t); tr(pl, x, y, Math.atan2(y2 - y, x2 - x) * 57.3); });
      posts.forEach((ps, k) => { const [x, y] = bridgeAt((k + 1) / 13, t); ps.setAttribute("x1", f1(x)); ps.setAttribute("y1", f1(y)); ps.setAttribute("x2", f1(x)); ps.setAttribute("y2", f1(y - 70)); });
      // Герои цепочкой, держатся за руки.
      H.forEach((h, i) => {
        const u = clamp(0.5 + 0.03 * t - i * 0.15, 0.03, 0.97);
        const [x, y] = bridgeAt(u, t), [x2, y2] = bridgeAt(u + 0.01, t);
        const ph = t * 2 * Math.PI * 1.6 + i;
        const p = { x, y, s: h.s, dir: 1, t, shadowOp: 0.25, eyes: t > 3.2 ? "happy" : "open", mouth: "grin", look: [3, 0] };
        p.tilt = Math.atan2(y2 - y, x2 - x) * 57.3 * 0.6 + Math.sin(ph) * 2;
        p.lift = Math.abs(Math.sin(ph)) * 7; p.legF = Math.sin(ph) * 22; p.legB = -Math.sin(ph) * 22;
        p.armF = i > 0 ? 96 : 30; p.armB = i < H.length - 1 ? -98 : -150;
        if (i === H.length - 1) p.armB = -98;
        if (i === 0) { p.armB = -40; p.armF = 98; }
        if (i === H.length - 1) p.armF = 20 + Math.sin(t * 6) * 10;
        poseBean(h.b, p);
      });
      B.placeNarration(narr, t, 0.4, 3.0, 960, 120);
      // Буквы названия падают по очереди, сплющиваются при посадке.
      letters.forEach((l, i) => {
        const a = TITLE_AT + i * 0.09, u = seg(t, a, a + 0.45);
        const y = 330 - 520 * (1 - E.outBack(u));
        const land = t - a - 0.45, sq = land > 0 ? 1 - 0.18 * Math.exp(-9 * land) * Math.cos(16 * land) : 1;
        show(l.g, t >= a ? 1 : 0);
        l.g.setAttribute("transform", `translate(${f1(l.x)} ${f1(y)}) scale(${(1 / Math.sqrt(sq)).toFixed(3)} ${sq.toFixed(3)}) rotate(${f1((1 - u) * (i % 2 ? 14 : -14))})`);
      });
    };
  },
});
