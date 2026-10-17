// Места действия: небо (день, сумерки, ночь, утро, рассвет), облака, солнце и луна, парящие острова
// с мостами и водопадами, замок на холме, праздничная площадь с помостом, луг. Палитры — в PAL.
(() => {
  const { el, f1, NAVY, vgrad, rng } = B;

  const PAL = {
    day: {
      sky: [[0, "#2f86f0"], [0.6, "#7cc4ff"], [1, "#d6f0ff"]], cloud: "#ffffff", cloudShade: "#d5e6ff", cloudOp: 1,
      hill: "#6cbf5a", hill2: "#58ad4c", castleHill: "#7ccc66", tower: "#f3e4c6", towerStroke: "#5b4a6a",
      domes: ["#e84a3f", "#e84a3f", "#f7c531", "#46b85a", "#3a7fe6"], tree: ["#4fae4a", "#3f9a3e"], haze: "#ffffff", hazeOp: 0.45,
      wall: "#f3e2c4", brick: "#e6cfa6", roofs: [["#e5483e", "#ff9a8e"], ["#3a7fe6", "#9cc6ff"]], door: "#8a5530",
      ground: [[0, "#efd9a8"], [1, "#cfa76c"]], cobble: "#f4e1b6", cobbleStroke: "#c39b62",
      stone: "#c9c0aa", stoneBlock: "#ddd5bf", stoneStroke: "#9a8f78", step: "#e3dccb",
      window: "#7cc4ff", windowGlow: 0, waterfall: "#ffffff", rope: "#6b4a2a",
    },
    night: {
      sky: [[0, "#091338"], [0.55, "#1b2d7a"], [1, "#3a52a8"]], cloud: "#2b3f8f", cloudShade: "#22347c", cloudOp: 0.75,
      hill: "#1d2a6a", hill2: "#1a2660", castleHill: "#22357a", tower: "#3c4a8c", towerStroke: "#1a2458",
      domes: ["#8e2a3e", "#8d2b3c", "#b28d2c", "#2a7a5b", "#2c4fa3"], tree: ["#1a3466", "#183060"], haze: "#6f86d8", hazeOp: 0.35,
      wall: "#5f6596", brick: "#6a71a4", roofs: [["#a3303d", "#ff7d86"], ["#2b56b0", "#7fb0ff"]], door: "#4a2f22",
      ground: [[0, "#3b4a8e"], [1, "#1c2558"]], cobble: "#465597", cobbleStroke: "#26306a",
      stone: "#4c5590", stoneBlock: "#5a64a2", stoneStroke: "#2e3770", step: "#6a73b0",
      window: "#ffcf6b", windowGlow: 0.55, waterfall: "#7fb6ff", rope: "#2a1d14",
    },
  };
  // Утро — дневная площадь в мягком тёплом свете; сумерки и рассвет — свои небеса.
  PAL.morning = { ...PAL.day, sky: [[0, "#6fa8f0"], [0.55, "#ffd2b0"], [1, "#fff1d6"]], haze: "#fff3e0", hazeOp: 0.5 };
  PAL.dusk = { ...PAL.night, sky: [[0, "#2a1f5e"], [0.45, "#7a3f8a"], [0.75, "#ef8a6a"], [1, "#ffd08a"]], cloud: "#9a5a9a", cloudShade: "#6a3f7a", cloudOp: 0.8, hill: "#3a2d6a", hill2: "#30265e", haze: "#ff9a8a", hazeOp: 0.25 };
  PAL.dawn = { ...PAL.day, sky: [[0, "#3f7fe8"], [0.45, "#a9b8f0"], [0.75, "#ffb7a0"], [1, "#ffe2a8"]], cloud: "#fff2e6", cloudShade: "#f0b8b0", haze: "#ffe0c0", hazeOp: 0.45 };

  function sky(layer, pal, id) {
    el("rect", { x: -1400, y: -2400, width: 4720, height: 4000, fill: vgrad("sky-" + id, pal.sky) }, layer);
  }
  function stars(layer, n, seed = 7, area = [-300, -700, 2520, 1250]) {
    const r = rng(seed), list = [];
    for (let i = 0; i < n; i++) {
      const s = el("circle", { cx: f1(area[0] + r() * area[2]), cy: f1(area[1] + r() * area[3]), r: f1(1 + r() * 2.2), fill: "#fffbe6" }, layer);
      list.push([s, r() * 6.28, 0.4 + r() * 0.6]);
    }
    return list;
  }
  const twinkle = (list, t, k = 1) => { for (const [s, ph, b] of list) s.setAttribute("opacity", (k * b * (0.65 + 0.35 * Math.sin(t * 2.3 + ph))).toFixed(3)); };
  function moon(layer, x, y, r = 70) {
    const g = el("g", {}, layer);
    el("circle", { cx: x, cy: y, r: r * 3.7, fill: "url(#moonGlow)" }, g);
    el("circle", { cx: x, cy: y, r, fill: "#f6f2d8" }, g);
    for (const [dx, dy, rr] of [[-22, -15, 13], [22, 21, 9], [14, -25, 6], [-14, 27, 7]]) el("circle", { cx: x + dx * r / 70, cy: y + dy * r / 70, r: rr * r / 70, fill: "#e2dcbb" }, g);
    return g;
  }
  function sun(layer, x, y, r = 80, rays = true) {
    const g = el("g", {}, layer);
    el("circle", { cx: x, cy: y, r: r * 5, fill: "url(#sunGlow)" }, g);
    if (rays) for (let i = 0; i < 12; i++) {
      const a = (i / 12) * Math.PI * 2;
      el("path", { d: `M${x} ${y} L${f1(x + Math.cos(a - 0.08) * r * 9)} ${f1(y + Math.sin(a - 0.08) * r * 9)} L${f1(x + Math.cos(a + 0.08) * r * 9)} ${f1(y + Math.sin(a + 0.08) * r * 9)}Z`, fill: "#fff8d8", opacity: 0.12 }, g);
    }
    el("circle", { cx: x, cy: y, r, fill: "#fff6c8" }, g);
    el("circle", { cx: x, cy: y, r: r * 0.8, fill: "#fffbe6" }, g);
    return g;
  }
  /** Пухлое облако: тень снизу, светлые шапки сверху. */
  function cloud(layer, x, y, s, pal, op = pal.cloudOp ?? 1) {
    const g = el("g", { transform: `translate(${x} ${y}) scale(${s})`, opacity: op }, layer);
    const puffs = [[0, 0, 60], [70, -25, 70], [150, 0, 55], [-60, 12, 42], [210, 18, 38]];
    for (const [cx, cy, r] of puffs) el("circle", { cx, cy: cy + 10, r, fill: pal.cloudShade }, g);
    el("rect", { x: -100, y: 18, width: 350, height: 50, rx: 25, fill: pal.cloudShade }, g);
    for (const [cx, cy, r] of puffs) el("circle", { cx, cy, r: r * 0.94, fill: pal.cloud }, g);
    el("rect", { x: -96, y: 8, width: 342, height: 44, rx: 22, fill: pal.cloud }, g);
    return g;
  }
  /** Парящая скала: каменный клин с травяной шапкой, водопад, мох. */
  function island(layer, x, y, w, h, pal, opts = {}) {
    const g = el("g", { transform: `translate(${x} ${y})` }, layer);
    const rock = opts.rock || "#8b8fa8", rockDark = opts.rockDark || "#6a6e88", grass = opts.grass || "#6cc35a", grassDark = opts.grassDark || "#4fa046";
    el("path", { d: `M${-w / 2} 0 Q ${-w * 0.4} ${h * 0.5} ${-w * 0.12} ${h} Q 0 ${h * 1.12} ${w * 0.1} ${h * 0.95} Q ${w * 0.38} ${h * 0.55} ${w / 2} 0Z`, fill: rock, stroke: opts.stroke || NAVY, "stroke-width": opts.sw ?? 4 }, g);
    el("path", { d: `M${w * 0.05} 8 Q ${w * 0.2} ${h * 0.5} ${w * 0.05} ${h * 0.9}`, fill: "none", stroke: rockDark, "stroke-width": w * 0.08, opacity: 0.6, "stroke-linecap": "round" }, g);
    if (opts.fall) el("rect", { x: w * 0.18, y: 4, width: w * 0.06, height: h * 1.6, fill: pal.waterfall, opacity: 0.55 }, g);
    el("path", { d: `M${-w / 2 - 6} 4 Q ${-w * 0.3} ${-h * 0.18} 0 ${-h * 0.2} Q ${w * 0.3} ${-h * 0.18} ${w / 2 + 6} 4 Q ${w * 0.25} 18 0 14 Q ${-w * 0.25} 18 ${-w / 2 - 6} 4Z`, fill: grass, stroke: opts.stroke || NAVY, "stroke-width": opts.sw ?? 4 }, g);
    for (let k = 0; k < 3; k++) el("circle", { cx: -w * 0.3 + k * w * 0.25, cy: -h * 0.18 - 6, r: w * 0.09, fill: grassDark }, g);
    return g;
  }
  /** Подвесной мост между двумя точками: провисающая верёвка и доски. */
  function bridge(layer, x1, y1, x2, y2, sag, color = "#6b4a2a", plank = "#9a6a3c", sw = 3) {
    const g = el("g", {}, layer);
    const mx = (x1 + x2) / 2, my = (y1 + y2) / 2 + sag;
    el("path", { d: `M${x1} ${y1} Q ${mx} ${my} ${x2} ${y2}`, fill: "none", stroke: color, "stroke-width": sw }, g);
    el("path", { d: `M${x1} ${y1 - 18} Q ${mx} ${my - 18} ${x2} ${y2 - 18}`, fill: "none", stroke: color, "stroke-width": sw * 0.7 }, g);
    const n = Math.max(4, Math.round(Math.abs(x2 - x1) / 14));
    for (let i = 1; i < n; i++) {
      const u = i / n, x = (1 - u) ** 2 * x1 + 2 * u * (1 - u) * mx + u * u * x2, y = (1 - u) ** 2 * y1 + 2 * u * (1 - u) * my + u * u * y2;
      el("rect", { x: f1(x - 4), y: f1(y - 2), width: 8, height: 6, rx: 1.5, fill: plank }, g);
      if (i % 3 === 0) el("line", { x1: f1(x), y1: f1(y), x2: f1(x), y2: f1(y - 18), stroke: color, "stroke-width": sw * 0.5 }, g);
    }
    return g;
  }
  /** Замок с куполами-бобами на холме. x — центр, y — подножие, s — масштаб. Возвращает флаги для анимации. */
  function castle(layer, x, y, s, pal) {
    const g = el("g", { transform: `translate(${x} ${y}) scale(${s})` }, layer);
    const st = NAVY, wall = pal.castleWall || "#f6e6c4", shade = pal.castleShade || "#dcc49a", line = pal.castleLine || "#d4bd92";
    el("path", { d: "M-360 0 Q -190 -250 0 -262 Q 190 -250 360 0Z", fill: pal.castleHill, stroke: st, "stroke-width": 4 }, g);
    el("path", { d: "M-300 -20 Q -160 -200 0 -214 Q 120 -205 200 -150", fill: "none", stroke: "#ffffff", "stroke-width": 10, opacity: 0.25, "stroke-linecap": "round" }, g);
    const flags = [];
    const block = (bx, by, bw, bh) => {
      el("rect", { x: bx, y: by, width: bw, height: bh, fill: wall, stroke: st, "stroke-width": 4 }, g);
      el("rect", { x: bx + bw * 0.68, y: by + 2, width: bw * 0.32 - 2, height: bh - 4, fill: shade, opacity: 0.85 }, g);
      for (let yy = by + 22, r = 0; yy < by + bh - 8; yy += 24, r++)
        for (let xx = bx + 8 + (r % 2) * 14; xx < bx + bw - 22; xx += 30) el("rect", { x: xx, y: yy, width: 18, height: 8, rx: 3, fill: line, opacity: 0.7 }, g);
    };
    const crenel = (bx, by, bw) => { for (let xx = bx; xx < bx + bw - 4; xx += 26) el("rect", { x: xx, y: by - 16, width: 18, height: 18, fill: wall, stroke: st, "stroke-width": 3.5 }, g); };
    function tower(tx, ty, w, h, c) {
      block(tx - w / 2, ty, w, h);
      crenel(tx - w / 2 - 4, ty, w + 8);
      el("path", { d: `M${tx - 8} ${ty + 58} L${tx - 8} ${ty + 40} Q ${tx} ${ty + 28} ${tx + 8} ${ty + 40} L${tx + 8} ${ty + 58}Z`, fill: pal.window, stroke: st, "stroke-width": 3 }, g);
      if (pal.windowGlow) el("circle", { cx: tx, cy: ty + 48, r: 30, fill: "url(#warmSmall)", opacity: pal.windowGlow }, g);
      // Купол-боб: выпуклый, с бликом и тенью.
      const dw = w * 0.62, dh = w * 0.95, top = ty - 16;
      el("path", { d: `M${tx - dw} ${top} C ${tx - dw * 1.15} ${top - dh * 0.7} ${tx - dw * 0.5} ${top - dh * 1.05} ${tx} ${top - dh * 1.05} C ${tx + dw * 0.5} ${top - dh * 1.05} ${tx + dw * 1.15} ${top - dh * 0.7} ${tx + dw} ${top}Z`, fill: c, stroke: st, "stroke-width": 4 }, g);
      el("ellipse", { cx: tx - dw * 0.42, cy: top - dh * 0.62, rx: dw * 0.16, ry: dh * 0.26, fill: "#fff", opacity: 0.6, transform: `rotate(20 ${f1(tx - dw * 0.42)} ${f1(top - dh * 0.62)})` }, g);
      el("path", { d: `M${tx + dw * 0.55} ${top - dh * 0.15} Q ${tx + dw * 0.75} ${top - dh * 0.5} ${tx + dw * 0.45} ${top - dh * 0.85}`, fill: "none", stroke: "#000", "stroke-width": dw * 0.2, opacity: 0.12, "stroke-linecap": "round" }, g);
      const pole = top - dh * 1.05;
      el("line", { x1: tx, y1: pole, x2: tx, y2: pole - 42, stroke: st, "stroke-width": 3.5 }, g);
      flags.push([el("path", { fill: c === pal.domes[2] ? "#3a7fe6" : "#f7c531", stroke: st, "stroke-width": 2.5 }, g), tx, pole - 42]);
    }
    // Башни: [центр, верх, ширина, высота, купол]. Задние, стена с воротами, передние.
    const T = [[-215, -395, 70, 160, pal.domes[4]], [-125, -500, 78, 270, pal.domes[0]], [0, -590, 100, 360, pal.domes[1]], [125, -510, 78, 280, pal.domes[2]], [215, -400, 70, 170, pal.domes[3]]];
    for (const q of [T[1], T[2], T[3]]) tower(...q);
    block(-250, -330, 500, 110); crenel(-250, -330, 500);
    el("path", { d: "M-46 -220 L-46 -282 Q 0 -330 46 -282 L46 -220Z", fill: "#6a4a3a", stroke: st, "stroke-width": 4 }, g);
    el("path", { d: "M-30 -222 L-30 -276 Q 0 -306 30 -276 L30 -222", fill: "none", stroke: "#4a3020", "stroke-width": 3 }, g);
    for (const q of [T[0], T[4]]) tower(...q);
    return { g, flags };
  }
  /** Флажок на ветру (путь, развевающийся вправо). */
  function waveFlag(f, x, y, t, i, wind = 1, len = 34) {
    const a = Math.sin(t * 7 + i) * 5 * wind, b = Math.sin(t * 7 + i + 1.2) * 6 * wind;
    f.setAttribute("d", `M${x} ${y} Q ${f1(x + len * 0.5)} ${f1(y - 3 + a)} ${f1(x + len)} ${f1(y + 4 + b)} L ${f1(x + len - 2)} ${f1(y + 16 + b)} Q ${f1(x + len * 0.5)} ${f1(y + 12 + a)} ${x} ${y + 18}Z`);
  }

  /** Праздничная площадь: дальний холм с замком, дома, брусчатка, помост, верёвка с флажками и фонариками. */
  function square(S, palName, opts = {}) {
    const pal = PAL[palName], r = rng(77), mid = S.L.mid, far = S.L.far;
    const P = { pal };
    sky(S.L.sky, pal, palName);
    // Дальний холм с замком.
    el("path", { d: "M-400 620 Q 100 470 500 520 Q 900 440 1300 520 Q 1700 470 2320 560 L2320 900 L-400 900Z", fill: pal.hill }, far);
    const castleG = el("g", { transform: "translate(690 0)" }, far);
    el("path", { d: "M-260 560 Q -120 380 0 360 Q 140 380 280 560Z", fill: pal.castleHill }, castleG);
    const domes = [[-120, 300, 46, 150, pal.domes[0]], [-40, 250, 54, 210, pal.domes[1]], [50, 290, 44, 160, pal.domes[2]], [130, 315, 40, 140, pal.domes[3]], [-190, 335, 34, 110, pal.domes[4]]];
    for (const [x, y, w, h, c] of domes) {
      el("rect", { x: x - w / 2, y, width: w, height: h + 120, fill: pal.tower, stroke: pal.towerStroke, "stroke-width": 3 }, castleG);
      el("path", { d: `M${x - w / 2 - 4} ${y} Q ${x - w / 2} ${y - w * 1.3} ${x} ${y - w * 1.45} Q ${x + w / 2} ${y - w * 1.3} ${x + w / 2 + 4} ${y}Z`, fill: c, stroke: pal.towerStroke, "stroke-width": 3 }, castleG);
      el("ellipse", { cx: x - w * 0.15, cy: y - w * 0.85, rx: w * 0.1, ry: w * 0.28, fill: "#fff", opacity: 0.3 }, castleG);
      for (let k = 0; k < 2; k++) {
        el("rect", { x: x - 5, y: y + 30 + k * 50, width: 10, height: 16, rx: 5, fill: pal.window }, castleG);
        if (pal.windowGlow) el("circle", { cx: x, cy: y + 38 + k * 50, r: 22, fill: "url(#warmSmall)", opacity: 0.6 }, castleG);
      }
    }
    el("rect", { x: -150, y: 400, width: 300, height: 170, fill: pal.tower, stroke: pal.towerStroke, "stroke-width": 3 }, castleG);
    el("rect", { x: 250, y: 380, width: 14, height: 200, fill: pal.waterfall, opacity: 0.35 }, castleG);
    for (let i = 0; i < 16; i++) {
      const x = -400 + i * 170 + r() * 60, rr = 40 + r() * 30;
      el("circle", { cx: x, cy: 590 - r() * 40, r: rr, fill: pal.tree[i % 2] }, far);
    }
    el("rect", { x: -400, y: 420, width: 2720, height: 260, fill: vgrad("haze-" + palName, [[0, pal.haze, 0], [0.7, pal.haze, pal.hazeOp], [1, pal.haze, pal.hazeOp * 0.3]]) }, far);

    // Дома по краям.
    function house(x, w, [roof, roofLight]) {
      const g = el("g", {}, mid);
      el("rect", { x, y: 470, width: w, height: 320, fill: pal.wall, stroke: NAVY, "stroke-width": 5 }, g);
      for (let rr = 0; rr < 6; rr++) for (let c = 0; c < 4; c++)
        el("rect", { x: x + 8 + c * (w / 4) + (rr % 2) * 20, y: 490 + rr * 48, width: w / 4 - 16, height: 38, rx: 8, fill: pal.brick, opacity: 0.7 }, g);
      el("path", { d: `M${x - 30} 478 Q ${x - 10} 300 ${x + w / 2} 290 Q ${x + w + 10} 300 ${x + w + 30} 478Z`, fill: roof, stroke: NAVY, "stroke-width": 5 }, g);
      el("path", { d: `M${x + w * 0.12} 430 Q ${x + w * 0.2} 340 ${x + w * 0.42} 318`, fill: "none", stroke: roofLight, "stroke-width": 12, "stroke-linecap": "round", opacity: 0.55 }, g);
      el("path", { d: `M${x + w / 2 - 45} 790 L${x + w / 2 - 45} 660 Q ${x + w / 2} 600 ${x + w / 2 + 45} 660 L${x + w / 2 + 45} 790Z`, fill: pal.door, stroke: NAVY, "stroke-width": 5 }, g);
      const wy = 530, wx = x + (x < 900 ? w - 80 : 30);
      if (pal.windowGlow) el("circle", { cx: wx + 25, cy: wy + 30, r: 90, fill: "url(#warm)", opacity: pal.windowGlow }, g);
      el("path", { d: `M${wx} ${wy + 60} L${wx} ${wy + 20} Q ${wx + 25} ${wy - 6} ${wx + 50} ${wy + 20} L${wx + 50} ${wy + 60}Z`, fill: pal.window, stroke: NAVY, "stroke-width": 4 }, g);
    }
    house(-60, 330, pal.roofs[0]);
    house(1650, 330, pal.roofs[1]);

    // Брусчатка с перспективой.
    el("rect", { x: -400, y: 780, width: 2720, height: 600, fill: vgrad("ground-" + palName, pal.ground) }, mid);
    for (let rr = 0, y = 784; rr < 10; rr++) {
      const h = 12 + rr * 6, w = h * 2.3;
      for (let x = -400 + (rr % 2) * w * 0.5; x < 2320; x += w + 6)
        el("rect", { x: f1(x), y: f1(y), width: f1(w), height: f1(h), rx: f1(h * 0.45), fill: pal.cobble, stroke: pal.cobbleStroke, "stroke-width": 2.5, opacity: 0.9 }, mid);
      y += h + 5;
    }
    P.reflections = el("g", {}, mid);

    // Помост.
    const stage = el("g", {}, mid);
    for (let i = 0; i < 10; i++) {
      const x = 770 + i * 80;
      el("rect", { x: x - 7, y: 596, width: 14, height: 70, fill: "#7a4f2e", stroke: NAVY, "stroke-width": 4 }, stage);
      el("circle", { cx: x, cy: 592, r: 12, fill: "#8b5d37", stroke: NAVY, "stroke-width": 4 }, stage);
    }
    el("rect", { x: 760, y: 612, width: 740, height: 12, rx: 6, fill: "#8b5d37", stroke: NAVY, "stroke-width": 4 }, stage);
    el("rect", { x: 740, y: 662, width: 780, height: 34, fill: "url(#wood)", stroke: NAVY, "stroke-width": 5 }, stage);
    for (let x = 790; x < 1500; x += 70) el("line", { x1: x, y1: 664, x2: x - 6, y2: 694, stroke: "#5a3a20", "stroke-width": 3 }, stage);
    el("rect", { x: 740, y: 694, width: 780, height: 30, fill: "#5d3b22", stroke: NAVY, "stroke-width": 5 }, stage);
    el("rect", { x: 750, y: 722, width: 760, height: 72, fill: pal.stone, stroke: NAVY, "stroke-width": 5 }, stage);
    for (let rr = 0; rr < 2; rr++) for (let x = 756 + rr * 40; x < 1500; x += 82)
      el("rect", { x, y: 728 + rr * 34, width: 74, height: 28, rx: 6, fill: pal.stoneBlock, stroke: pal.stoneStroke, "stroke-width": 2 }, stage);
    for (let k = 0; k < 3; k++)
      el("rect", { x: 1060 - k * 14, y: 724 + k * 24, width: 140 + k * 28, height: 26, rx: 4, fill: pal.step, stroke: NAVY, "stroke-width": 4 }, stage);
    P.stageFlags = [];
    for (let i = 0; i < 13; i++) {
      const x = 760 + i * 60, c = ["#e8414a", "#ffcf3f", "#3a8de0", "#46b85a"][i % 4];
      const f = el("path", { d: "M-22 0 L22 0 L0 38Z", fill: c, stroke: NAVY, "stroke-width": 3 }, stage);
      P.stageFlags.push([f, x, 700 + Math.sin(i * 0.9) * 3, i]);
    }
    P.STAGE_Y = 664;

    // Верёвка с флажками и фонариками.
    const ROPE = (x) => 240 - 0.000085 * (x - 960) ** 2;
    P.ROPE = ROPE;
    el("path", { d: `M-200 ${f1(ROPE(-200))} ` + Array.from({ length: 24 }, (_, i) => { const x = -200 + i * 100; return `L${x} ${f1(ROPE(x))}`; }).join(" "), fill: "none", stroke: pal.rope, "stroke-width": 5 }, mid);
    P.ropeFlags = [];
    for (let i = 0; i < 34; i++) {
      const x = -150 + i * 66, c = ["#e8414a", "#ffcf3f", "#3a8de0", "#46b85a", "#f07ad0"][i % 5];
      P.ropeFlags.push([el("path", { d: "M-20 0 L20 0 L0 40Z", fill: c, stroke: NAVY, "stroke-width": 3 }, mid), x, ROPE(x), i]);
    }
    P.lanterns = (opts.lanterns ?? [130, 420, 720, 1010, 1300, 1590, 1840]).map((x, i) => {
      const g = el("g", {}, mid);
      el("line", { x1: 0, y1: 0, x2: 0, y2: 26, stroke: pal.rope, "stroke-width": 3 }, g);
      const body = el("ellipse", { cx: 0, cy: 62, rx: 30, ry: 34, fill: opts.lit === false ? "#e8c9a0" : "#ffb347", stroke: NAVY, "stroke-width": 4 }, g);
      const inner = el("ellipse", { cx: -4, cy: 56, rx: 15, ry: 20, fill: "#fff1b0", opacity: opts.lit === false ? 0 : 0.85 }, g);
      for (const dx of [-14, 0, 14]) el("path", { d: `M${dx} 30 Q ${dx * 1.7} 62 ${dx} 94`, fill: "none", stroke: "#c4562a", "stroke-width": 2.5, opacity: 0.8 }, g);
      el("rect", { x: -16, y: 24, width: 32, height: 9, rx: 3, fill: "#7a4a22", stroke: NAVY, "stroke-width": 3 }, g);
      el("rect", { x: -14, y: 92, width: 28, height: 8, rx: 3, fill: "#7a4a22", stroke: NAVY, "stroke-width": 3 }, g);
      return { g, body, inner, x, y: ROPE(x), out: Infinity, i };
    });
    P.wave = (t, wind) => {
      for (const [f, x, y, i] of P.ropeFlags) B.tr(f, x, y, Math.sin(t * 5 + i * 0.7) * 10 * wind - 18 * Math.max(0, wind - 0.6));
      for (const [f, x, y, i] of P.stageFlags) B.tr(f, x, y, Math.sin(t * 6 + i) * 8 * wind);
    };
    return P;
  }

  /** Луг на переднем плане: полоса травы с цветами (верхний край — мягкие округлые пучки). */
  function meadow(layer, y, w, pal = { grass: "#5cbf4a", grassDark: "#3f9a3a", grassLight: "#86d86a", edge: "#2f7a2a" }, seed = 3, x0 = -400) {
    const r = rng(seed), g = el("g", {}, layer);
    el("rect", { x: x0, y: y + 30, width: w, height: 900, fill: pal.grassDark }, g);
    for (let x = x0; x < x0 + w; x += 34) {
      const h = 34 + r() * 40, lean = (r() - 0.5) * 24, bw = 22 + r() * 10;
      el("path", { d: `M${f1(x - bw / 2)} ${y + 46} C ${f1(x - bw / 2)} ${f1(y + 46 - h * 0.7)} ${f1(x + lean - 4)} ${f1(y + 46 - h)} ${f1(x + lean)} ${f1(y + 46 - h)} C ${f1(x + lean + 4)} ${f1(y + 46 - h)} ${f1(x + bw / 2)} ${f1(y + 46 - h * 0.6)} ${f1(x + bw / 2)} ${y + 46}Z`, fill: r() < 0.5 ? pal.grass : pal.grassLight, stroke: pal.edge, "stroke-width": 2.5 }, g);
    }
    el("rect", { x: x0, y: y + 40, width: w, height: 900, fill: pal.grass }, g);
    for (let i = 0; i < w / 160; i++) el("ellipse", { cx: f1(x0 + r() * w), cy: f1(y + 70 + r() * 80), rx: 60 + r() * 50, ry: 10, fill: pal.grassLight, opacity: 0.45 }, g);
    for (let i = 0; i < w / 90; i++) {
      const fx = x0 + r() * w, fy = y + 34 + r() * 30, c = r() < 0.6 ? "#ffffff" : "#ffd23f";
      const f = el("g", { transform: `translate(${f1(fx)} ${f1(fy)}) scale(${(0.8 + r() * 0.6).toFixed(2)})` }, g);
      for (let k = 0; k < 5; k++) el("ellipse", { cx: 0, cy: -7, rx: 4.5, ry: 7, fill: c, stroke: pal.edge, "stroke-width": 1.4, transform: `rotate(${k * 72})` }, f);
      el("circle", { r: 3.6, fill: c === "#ffffff" ? "#ffd23f" : "#f08a1a", stroke: pal.edge, "stroke-width": 1.4 }, f);
    }
    return g;
  }
  /** Ряд травинок перед ногами (y — линия земли). */
  function tufts(layer, x1, x2, y, seed = 9, pal = { grass: "#5cbf4a", grassLight: "#86d86a", edge: "#2f7a2a" }) {
    const r = rng(seed), g = el("g", {}, layer);
    for (let x = x1; x < x2; x += 26) {
      const h = 22 + r() * 30, lean = (r() - 0.5) * 20, bw = 18 + r() * 8;
      el("path", { d: `M${f1(x - bw / 2)} ${y} C ${f1(x - bw / 2)} ${f1(y - h * 0.7)} ${f1(x + lean - 3)} ${f1(y - h)} ${f1(x + lean)} ${f1(y - h)} C ${f1(x + lean + 3)} ${f1(y - h)} ${f1(x + bw / 2)} ${f1(y - h * 0.6)} ${f1(x + bw / 2)} ${y}Z`, fill: r() < 0.5 ? pal.grass : pal.grassLight, stroke: pal.edge, "stroke-width": 2.5 }, g);
    }
    el("rect", { x: x1 - 14, y: y - 2, width: x2 - x1 + 28, height: 300, fill: pal.grass }, g);
    return g;
  }

  Object.assign(B, { PAL, sky, stars, twinkle, moon, sun, cloud, island, bridge, castle, waveFlag, square, meadow, tufts });
})();
