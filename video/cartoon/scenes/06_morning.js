// Сцена 6 «Утро»: тот же кадр, что в конце налёта (корона на помосте), — светает; герои находят корону,
// красный поднимает её над головой: «Мы найдём короля!» — зелёный сомневается, сестрёнка: «Вместе — справимся!»
B.addScene({
  id: "morning",
  dur: 15,
  init(S) {
    const { el, f1, clamp, seg, lerp, E, K, tr, show, NAVY, makeBean, poseBean, crownShape } = B;
    const P = B.square(S, "morning", { lit: false });
    const sunG = B.sun(S.L.sky, 1500, 0, 85);
    for (const [x, y, s] of [[200, 160, 1.2], [1100, 70, 0.9], [1750, 280, 1.1]]) B.cloud(S.L.sky, x, y, s, P.pal);
    const stars = B.stars(S.L.sky, 70, 9);
    const mid = S.L.mid;
    const [CX, CY, CR] = B.shared.crownRest, CS = B.shared.crownScale, endCam = B.shared.endCam;

    // Опрокинутые флажки и конфетти на помосте — следы ночи.
    const r = B.rng(66);
    for (let i = 0; i < 26; i++) el("rect", { x: f1(760 + r() * 740), y: f1(652 + r() * 10), width: 10, height: 6, rx: 1.5, fill: ["#e8414a", "#ffcf3f", "#3a8de0", "#46b85a"][i % 4], transform: `rotate(${f1(r() * 180)} ${f1(800 + r() * 700)} 660)` }, mid);

    const cast = el("g", {}, mid);
    // Герои: [цвет, аксессуар, откуда прыгает x, где стоит x, время прыжка].
    const H = [
      { c: "green", x0: 520, x: 860, at: 4.75 },
      { c: "blue", x0: 520, x: 990, at: 4.5 },
      { c: "red", x0: 540, x: 1110, at: 4.25 },
      { c: "yellow", acc: "bow", x0: 560, x: 1230, at: 3.6 },
    ];
    for (const h of H) { h.b = makeBean(cast, h.c, { acc: h.acc, shadow: "#5a3a20", rim: "#ffe6c0" }); h.s = h.c === "yellow" ? 1.3 : 1.6; }
    const red = H[2];
    crownShape(el("g", { transform: "translate(0 0) scale(1.45)" }, red.b.hold));
    const crown = crownShape(el("g", {}, mid));

    // Лучи солнца за героями в момент решения.
    const rays = el("g", { opacity: 0, style: "mix-blend-mode:screen" }, S.L.far);
    for (let i = 0; i < 14; i++) {
      const a = (i / 14) * Math.PI * 2;
      el("path", { d: `M1180 330 L${f1(1180 + Math.cos(a - 0.09) * 1400)} ${f1(330 + Math.sin(a - 0.09) * 1400)} L${f1(1180 + Math.cos(a + 0.09) * 1400)} ${f1(330 + Math.sin(a + 0.09) * 1400)}Z`, fill: "#fff3c0", opacity: 0.35 }, rays);
    }
    // Ночь уходит: тёмно-синий слой поверх всего кадра тает, лунный луч гаснет.
    const night = el("rect", { x: 0, y: 0, width: 1920, height: 1080, fill: "#1c2a6e", style: "mix-blend-mode:multiply" }, S.L.ui);
    el("rect", { x: 0, y: 0, width: 1920, height: 1080, fill: "url(#vignetteDay)" }, S.L.ui);
    const narr = B.narration(S.L.ui, ["Наутро на опустевшей площади", "осталась только корона."], 820);
    const bSis = B.bubble(S.L.ui, ["Это же корона короля!"], 560, 92);
    const bBlue = B.bubble(S.L.ui, ["Его унесли призраки…"], 520, 92);
    const bRed = B.bubble(S.L.ui, ["Мы найдём короля", "и вернём его домой!"], 500, 140);
    const bGreen = B.bubble(S.L.ui, ["Но путь далёкий…"], 420, 92);
    const bSis2 = B.bubble(S.L.ui, ["Вместе — справимся!"], 500, 92);

    const PICK = 8.3, RAISE = 8.8, CHEER = 13.8;
    return function render(t) {
      // Камера: с кадра налёта — отъезд на помост; к решению — ниже и ближе (героический ракурс).
      const back = E.ioC(seg(t, 3.0, 4.3)), hero = E.io(seg(t, 8.4, 9.4));
      S.cam.x = lerp(endCam.x, 140, back) - hero * 40;
      S.cam.y = lerp(endCam.y, 20, back) + hero * 50;
      S.cam.z = lerp(endCam.z, 1.12, back) + hero * 0.3;
      S.apply();
      const dawn = E.io(seg(t, 0.3, 3.4));
      show(night, 0.82 * (1 - dawn));
      B.twinkle(stars, t, 1 - dawn);
      tr(sunG, 0, 620 * (1 - E.outQ(seg(t, 0.4, 4.0))));
      show(rays, E.io(seg(t, RAISE, RAISE + 0.8)) * (1 - seg(t, 14.4, 15)) * (0.75 + 0.25 * Math.sin(t * 2)));
      P.wave(t, 0.4);

      // Корона на помосте → в руках красного.
      show(crown, t < PICK ? 1 : 0);
      tr(crown, CX, CY, CR, CS);
      show(red.b.hold, t >= PICK ? 1 : 0);

      H.forEach((h, i) => {
        const p = { x: h.x, y: 664, s: h.s, dir: 1, t, shadowOp: 0.35, eyes: "open", mouth: "smile" };
        if (t < h.at) { p.y = 2000; poseBean(h.b, p); return; }
        // Прыжок на помост снизу слева.
        const u = seg(t, h.at, h.at + 0.55);
        if (u < 1) {
          p.x = lerp(h.x0, h.x, u); p.y = lerp(1000, 664, u); p.lift = 260 * Math.sin(Math.PI * u);
          Object.assign(p, { armF: 150, armB: -150, legF: -25, legB: 25, mouth: "grin", tilt: 8 });
        } else {
          const l = t - h.at - 0.55;
          p.sq = 1 - 0.22 * Math.exp(-7 * l) * Math.cos(14 * l);
          p.look = [3, 1];
        }
        // Реакции.
        if (h.c === "yellow") {
          if (t > 4.2 && t < 6.0) Object.assign(p, { eyes: "wide", mouth: "o", brows: "up", armB: -95, armBx: 8, look: [4, 2], lift: t < 4.5 ? 18 * Math.sin(Math.PI * seg(t, 4.2, 4.5)) : 0 });
          if (t > 12.2 && t < CHEER) {
            const k = t - 12.2;
            Object.assign(p, { eyes: "happy", mouth: "grin", armF: 160, armB: -160, lift: Math.max(0, Math.sin(k * 2 * Math.PI * 1.4)) * 40 });
          }
        }
        if (h.c === "blue" && t > 5.8 && t < 8.0) Object.assign(p, { eyes: "open", mouth: "frown", brows: "worried", look: [3, 3], tilt: 4 });
        if (h.c === "green") {
          if (t > 5.8 && t < 8.0) Object.assign(p, { brows: "worried", mouth: "flat", look: [4, 2] });
          if (t > 10.8 && t < 12.4) Object.assign(p, { brows: "worried", mouth: "frown", look: [3, 0], armF: 40, tilt: -3 });
        }
        if (h === red) {
          // Подходит к короне, приседает, поднимает её — и над головой.
          if (t > 7.4 && t < PICK) {
            const w = seg(t, 7.4, 8.0);
            p.x = lerp(h.x, CX - 70, E.io(w)); p.lift = Math.abs(Math.sin(w * Math.PI * 3)) * 12;
            if (t > 8.0) { p.sq = 0.82; p.armF = 70; p.armB = -70; p.tilt = 10; }
          }
          if (t >= PICK) {
            p.x = CX - 70;
            const up = E.outBack(seg(t, RAISE, RAISE + 0.45));
            p.armF = lerp(70, 160, up); p.armB = lerp(-70, -160, up);
            p.armFx = 16 * up; p.armBx = -14 * up; p.armFy = -8 * up; p.armBy = -6 * up;
            tr(h.b.hold, lerp(22, 2, up), lerp(-40, -112, up), lerp(10, 0, up));
            Object.assign(p, { eyes: up > 0.5 ? "open" : "wide", brows: up > 0.5 ? "angry" : null, mouth: up > 0.5 ? "grin" : "o", look: [1, -3], lift: up * 10 });
          }
        }
        // Решимость: после слов красного — нахмуренные брови и сжатые кулаки.
        if (t > 9.6 && h !== red && !(h.c === "green" && t > 10.8 && t < 12.4) && !(h.c === "yellow" && t > 12.2)) Object.assign(p, { brows: "angry", mouth: "smile", armF: 158 + Math.sin(t * 9 + i) * 6, armB: -24, look: [3, -1] });
        // Все вместе прыгают.
        if (t > CHEER + i * 0.05) {
          const k = t - CHEER - i * 0.05;
          Object.assign(p, { eyes: "happy", mouth: "grin", brows: null, armF: 165, armB: -165, lift: Math.max(0, Math.sin(k * 2 * Math.PI * 1.5)) * 50 });
          if (h === red) { p.armF = 168; p.armB = -168; }
        }
        poseBean(h.b, p);
      });

      B.placeNarration(narr, t, 0.6, 3.1, 960, 110);
      const at = (h, dy = 1.0) => S.toScreen(h.x + (h === red && t > 7.4 ? CX - 70 - h.x : 0) + 20, 664 - h.s * 105 * dy);
      { const [x, y] = at(H[3]); B.placeBubble(bSis, t, 4.3, 5.8, clamp(x + 160, 330, 1590), y - 160, x + 10, y - 20); }
      { const [x, y] = at(H[1]); B.placeBubble(bBlue, t, 5.9, 7.4, clamp(x - 120, 330, 1590), y - 170, x, y - 20); }
      { const [x, y] = at(red, 1.5); B.placeBubble(bRed, t, 9.0, 10.8, clamp(x + 330, 330, 1590), y - 40, x + 60, y); }
      { const [x, y] = at(H[0]); B.placeBubble(bGreen, t, 10.9, 12.3, clamp(x - 60, 330, 1590), y - 180, x, y - 20); }
      { const [x, y] = at(H[3]); B.placeBubble(bSis2, t, 12.4, 13.9, clamp(x + 190, 330, 1590), y - 190, x + 10, y - 30); }
    };
  },
});
