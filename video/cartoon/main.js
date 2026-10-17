// Склейка сцен и время. Сцены идут подряд (или с перекрытием, если у сцены задан at);
// кадр рисует функция render(T): у активной сцены вызывается её draw(t) с местным временем.
// Время ведёт один твин GSAP через функцию-сеттер — перемотка и рендер детерминированы.
(() => {
  let t0 = 0;
  for (const sc of B.scenes) {
    sc.start = sc.at ?? t0;
    sc.S = B.makeScene(sc.id, sc.opts);
    sc.draw = sc.init(sc.S);
    t0 = Math.max(t0, sc.start + sc.dur);
  }
  const TOTAL = t0;
  const root = document.getElementById("main");
  const declared = Number(root.dataset.duration);
  if (Math.abs(declared - TOTAL) > 0.01) console.warn(`data-duration ${declared} ≠ сумма сцен ${TOTAL.toFixed(2)}`);

  function render(T) {
    const last = B.scenes[B.scenes.length - 1];
    for (const sc of B.scenes) {
      const on = (T >= sc.start && T < sc.start + sc.dur) || (sc === last && T >= sc.start);
      sc.S.root.setAttribute("display", on ? "inline" : "none");
      if (on) sc.draw(T - sc.start);
    }
  }
  const clock = { _t: -1, time(v) { if (arguments.length) { if (v !== this._t) { this._t = v; render(v); } } return Math.max(0, this._t); } };
  render(0);
  const tl = gsap.timeline({ paused: true });
  tl.fromTo(clock, { time: 0 }, { time: TOTAL, duration: TOTAL, ease: "none" }, 0);
  window.__cartoon = { render, TOTAL, tl }; // регистрацию таймлайна делает index.html
})();
