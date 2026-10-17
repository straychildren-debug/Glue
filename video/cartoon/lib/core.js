// Основа мультика: SVG-помощники, числа, ключи анимации, сплайны, общие градиенты, сцена с камерой.
// Всё — глобальный объект B; сцены и куклы берут отсюда. Никаких часов и случайности: только функции времени.
(() => {
  const NS = "http://www.w3.org/2000/svg";
  const NAVY = "#1a1d33";
  const svg = document.getElementById("stage");

  function el(tag, attrs, parent) {
    const e = document.createElementNS(NS, tag);
    for (const k in attrs || {}) e.setAttribute(k, attrs[k]);
    if (parent) parent.appendChild(e);
    return e;
  }
  const f1 = (v) => Math.round(v * 10) / 10;
  const clamp = (v, a = 0, b = 1) => Math.min(b, Math.max(a, v));
  const seg = (t, a, b) => clamp((t - a) / (b - a));
  const lerp = (a, b, p) => a + (b - a) * p;
  const E = {
    lin: (x) => x,
    inQ: (x) => x * x,
    outQ: (x) => 1 - (1 - x) * (1 - x),
    inC: (x) => x * x * x,
    outC: (x) => 1 - Math.pow(1 - x, 3),
    io: (x) => (x < 0.5 ? 2 * x * x : 1 - Math.pow(-2 * x + 2, 2) / 2),
    ioC: (x) => (x < 0.5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2),
    outBack: (x) => 1 + 2.70158 * Math.pow(x - 1, 3) + 1.70158 * Math.pow(x - 1, 2),
  };
  /** Ключи: [[время, значение, кривая сегмента], ...]; значение — число или массив. */
  function K(t, keys) {
    if (t <= keys[0][0]) return keys[0][1];
    for (let i = 1; i < keys.length; i++) {
      const [t1, v1, e] = keys[i], [t0, v0] = keys[i - 1];
      if (t <= t1) {
        const p = E[e || "io"]((t - t0) / (t1 - t0));
        return Array.isArray(v0) ? v0.map((a, j) => a + (v1[j] - a) * p) : v0 + (v1 - v0) * p;
      }
    }
    return keys[keys.length - 1][1];
  }
  /** Появление и уход: 0 → 1 (outBack) с tin, 1 → 0 с tout. */
  const pop = (t, tin, tout, d = 0.28) => E.outBack(seg(t, tin, tin + d)) * (1 - E.inC(seg(t, tout, tout + 0.2)));
  function rng(seed) {
    return () => {
      seed |= 0; seed = (seed + 0x6d2b79f5) | 0;
      let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }
  /** Замкнутый сплайн Катмулла — Рома через точки → путь SVG. */
  function smooth(p) {
    const n = p.length;
    let d = `M${f1(p[0][0])} ${f1(p[0][1])}`;
    for (let i = 0; i < n; i++) {
      const a = p[(i - 1 + n) % n], b = p[i], c = p[(i + 1) % n], q = p[(i + 2) % n];
      d += `C${f1(b[0] + (c[0] - a[0]) / 6)} ${f1(b[1] + (c[1] - a[1]) / 6)} ${f1(c[0] - (q[0] - b[0]) / 6)} ${f1(c[1] - (q[1] - b[1]) / 6)} ${f1(c[0])} ${f1(c[1])}`;
    }
    return d + "Z";
  }
  const tr = (e, x, y, r = 0, sx = 1, sy = sx) =>
    e.setAttribute("transform", `translate(${f1(x)} ${f1(y)}) rotate(${f1(r)}) scale(${sx.toFixed(3)} ${sy.toFixed(3)})`);
  const show = (e, on) => e.setAttribute("opacity", typeof on === "number" ? clamp(on).toFixed(3) : on ? 1 : 0);

  // ── Общие градиенты и фильтры.
  const defs = el("defs", {}, svg);
  defs.innerHTML = `
    <radialGradient id="warm"><stop offset="0" stop-color="#ffd27a" stop-opacity=".95"/><stop offset=".35" stop-color="#ff9a3a" stop-opacity=".35"/><stop offset="1" stop-color="#ff8a2a" stop-opacity="0"/></radialGradient>
    <radialGradient id="warmSmall"><stop offset="0" stop-color="#ffe0a0" stop-opacity=".9"/><stop offset="1" stop-color="#ffb050" stop-opacity="0"/></radialGradient>
    <radialGradient id="sunGlow"><stop offset="0" stop-color="#fffbe0" stop-opacity=".95"/><stop offset=".3" stop-color="#fff0b0" stop-opacity=".45"/><stop offset="1" stop-color="#fff0b0" stop-opacity="0"/></radialGradient>
    <radialGradient id="moonGlow"><stop offset="0" stop-color="#fff6d0" stop-opacity=".55"/><stop offset=".35" stop-color="#cfd8ff" stop-opacity=".18"/><stop offset="1" stop-color="#cfd8ff" stop-opacity="0"/></radialGradient>
    <linearGradient id="gold" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffe676"/><stop offset=".55" stop-color="#ffc21f"/><stop offset="1" stop-color="#d98a0c"/></linearGradient>
    <linearGradient id="ghostFill" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffffff"/><stop offset=".7" stop-color="#eef2ff"/><stop offset="1" stop-color="#c9d4ff"/></linearGradient>
    <linearGradient id="cape" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#e8414a"/><stop offset="1" stop-color="#a51d2a"/></linearGradient>
    <linearGradient id="wood" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#9a6a42"/><stop offset="1" stop-color="#6e4628"/></linearGradient>
    <linearGradient id="beamG" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#dfe8ff" stop-opacity="0"/><stop offset=".6" stop-color="#dfe8ff" stop-opacity=".16"/><stop offset="1" stop-color="#fff6d8" stop-opacity=".38"/></linearGradient>
    <linearGradient id="paper" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f7e7bf"/><stop offset="1" stop-color="#e2c48a"/></linearGradient>
    <radialGradient id="vignette" cx=".5" cy=".46" r=".75"><stop offset=".55" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#050a26" stop-opacity=".55"/></radialGradient>
    <radialGradient id="vignetteDay" cx=".5" cy=".46" r=".75"><stop offset=".6" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#1a2050" stop-opacity=".28"/></radialGradient>
    <filter id="blur3" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="3"/></filter>
    <filter id="blur6" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="6"/></filter>
    <filter id="blur14" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="14"/></filter>`;
  /** Добавить градиент (один раз по id). */
  function gradient(id, html) {
    if (!document.getElementById(id)) defs.insertAdjacentHTML("beforeend", html.replace("$ID", id));
    return `url(#${id})`;
  }
  /** Вертикальный градиент по списку [смещение, цвет, прозрачность]. */
  const vgrad = (id, stops) => gradient(id, `<linearGradient id="$ID" x1="0" y1="0" x2="0" y2="1">${stops
    .map(([o, c, a = 1]) => `<stop offset="${o}" stop-color="${c}" stop-opacity="${a}"/>`).join("")}</linearGradient>`);

  // Цвета бобов: основной, свет, тень.
  const COLORS = {
    red: ["#ec4640", "#ff9a8c", "#a8231f"], blue: ["#3b7ff0", "#9cc3ff", "#1f4bb0"],
    green: ["#3ec75a", "#a2f0a8", "#1f8a36"], yellow: ["#f9cf2c", "#fff09a", "#c08d07"],
    pink: ["#f56a9a", "#ffb3cd", "#b2366a"], orange: ["#f78c22", "#ffc477", "#b45a08"],
    teal: ["#2ec4b6", "#93f0e5", "#13867b"], purple: ["#a463ea", "#d9acff", "#6a2fb0"],
    brown: ["#b86c36", "#eaa877", "#7a3f17"], plum: ["#c42fa6", "#ee7cd8", "#7d1668"],
    grandpa: ["#e8d6b0", "#fff6e0", "#b49a6a"],
  };
  for (const [n, [base, light, dark]] of Object.entries(COLORS))
    gradient(`g-${n}`, `<radialGradient id="$ID" cx=".34" cy=".26" r=".85"><stop offset="0" stop-color="${light}"/><stop offset=".42" stop-color="${base}"/><stop offset="1" stop-color="${dark}"/></radialGradient>`);

  // ── Сцена: корень, слои с параллаксом, камера (x, y — центр кадра в мире минус 960/540; z — масштаб; sx, sy — тряска).
  const scenes = [];
  function makeScene(id, opts = {}) {
    const S = { id, cam: { x: 0, y: 0, z: 1, sx: 0, sy: 0 }, L: {}, parallax: opts.parallax || { sky: 0.08, far: 0.35, mid: 1, fg: 1.35 } };
    S.root = el("g", { id: "scene-" + id, display: "none" }, svg);
    for (const n of ["sky", "far", "mid", "fg", "ui"]) S.L[n] = el("g", {}, S.root);
    S.apply = () => {
      const c = S.cam;
      for (const [n, f] of Object.entries(S.parallax)) {
        const z = 1 + (c.z - 1) * Math.min(1, f + 0.2);
        S.L[n].setAttribute("transform", `translate(${f1(960 + c.sx)} ${f1(540 + c.sy)}) scale(${z.toFixed(4)}) translate(${f1(-960 - c.x * f)} ${f1(-540 - c.y * f)})`);
      }
    };
    S.toScreen = (x, y) => [960 + S.cam.sx + S.cam.z * (x - 960 - S.cam.x), 540 + S.cam.sy + S.cam.z * (y - 540 - S.cam.y)];
    return S;
  }
  /** Регистрация сцены: {id, dur, build(S), render(S, t)}; порядок — порядок вызова. */
  function addScene(def) { scenes.push(def); }

  window.B = { NS, NAVY, svg, defs, el, f1, clamp, seg, lerp, E, K, pop, rng, smooth, tr, show, gradient, vgrad, COLORS, makeScene, addScene, scenes };
})();
