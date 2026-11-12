/*
  Touch controls for the GitHub Pages JSSpeccy 3.2 player.

  On a desktop mouse this file does nothing: it does not wrap Worker,
  does not change the layout, and does not intercept keys. Controls
  appear only when the primary pointer is coarse, or when the page
  has no hover and reports touch — typical phones and tablets.

  JSSpeccy 3 has no public key-injection or Kempston API, and no
  on-screen keyboard. On a phone, keys are sent to its worker as
  {message:"keyDown"|"keyUp", row, mask}, which is what its own
  keyboard handler does. The worker is captured at construction so
  button presses do not depend on focus (on-screen buttons would
  otherwise steal it) and do not rely on synthetic KeyboardEvents.

  Spectrum rows/masks are from JSSpeccy 3.2's Br map. The games also
  accept Q/A/O/P and Space, or 5/6/7/8 and 0.
*/
(function () {
  "use strict";

  function isPhonePlay() {
    try {
      if (window.matchMedia("(pointer: coarse)").matches) return true;
      if ("ontouchstart" in window && window.matchMedia("(hover: none)").matches) {
        return true;
      }
    } catch (e) {}
    return false;
  }

  if (!isPhonePlay()) return;

  var workers = [];
  var NativeWorker = window.Worker;
  window.Worker = class extends NativeWorker {
    constructor() {
      super(...arguments);
      workers.push(this);
    }
  };

  // Full letter matrix (row/mask) for menu code entry. Matches JSSpeccy Br.
  var KEYS = {
    "1": { row: 3, mask: 1 },
    "2": { row: 3, mask: 2 },
    "3": { row: 3, mask: 4 },
    "0": { row: 4, mask: 1 },
    A: { row: 1, mask: 1 }, B: { row: 7, mask: 16 }, C: { row: 0, mask: 8 },
    D: { row: 1, mask: 4 }, E: { row: 2, mask: 4 }, F: { row: 1, mask: 8 },
    G: { row: 1, mask: 16 }, H: { row: 6, mask: 16 }, I: { row: 5, mask: 4 },
    J: { row: 6, mask: 8 }, K: { row: 6, mask: 4 }, L: { row: 6, mask: 2 },
    M: { row: 7, mask: 4 }, N: { row: 7, mask: 8 }, O: { row: 5, mask: 2 },
    P: { row: 5, mask: 1 }, Q: { row: 2, mask: 1 }, R: { row: 2, mask: 8 },
    S: { row: 1, mask: 2 }, T: { row: 2, mask: 16 }, U: { row: 5, mask: 8 },
    V: { row: 0, mask: 16 }, W: { row: 2, mask: 2 }, X: { row: 0, mask: 4 },
    Y: { row: 5, mask: 16 }, Z: { row: 0, mask: 2 },
    SPACE: { row: 7, mask: 1 },
    SYM: { row: 7, mask: 2 }
  };

  var held = Object.create(null);
  var running = false;

  function worker() {
    return workers[0] || null;
  }

  function send(spec, down) {
    if (!spec) return;
    var w = worker();
    if (!w) return;
    w.postMessage({ message: down ? "keyDown" : "keyUp", row: spec.row, mask: spec.mask });
  }

  function press(name) {
    if (held[name]) return;
    held[name] = true;
    send(KEYS[name], true);
  }

  function release(name) {
    if (!held[name]) return;
    held[name] = false;
    send(KEYS[name], false);
  }

  function pulse(name, ms) {
    press(name);
    setTimeout(function () { release(name); }, ms || 120);
  }

  function releaseAll() {
    Object.keys(held).forEach(function (name) {
      if (held[name]) release(name);
    });
  }

  /* ---- direction pad: 8-way, holdable, Q/A/O/P ---- */
  var dirNames = { up: "Q", down: "A", left: "O", right: "P" };
  var dirState = { up: false, down: false, left: false, right: false };

  function setDirs(next) {
    Object.keys(dirNames).forEach(function (d) {
      if (next[d] && !dirState[d]) press(dirNames[d]);
      if (!next[d] && dirState[d]) release(dirNames[d]);
      dirState[d] = !!next[d];
    });
    var pad = document.getElementById("dpad");
    if (pad) pad.classList.toggle("on", next.up || next.down || next.left || next.right);
  }

  function dirsFromPad(ev, el) {
    var r = el.getBoundingClientRect();
    var x = ev.clientX - r.left - r.width / 2;
    var y = ev.clientY - r.top - r.height / 2;
    var dead = Math.min(r.width, r.height) * 0.16;
    var next = { up: false, down: false, left: false, right: false };
    if (x * x + y * y >= dead * dead) {
      var ax = Math.abs(x), ay = Math.abs(y);
      // 8-way: a diagonal if the smaller axis is at least ~1/3 of the larger.
      if (ay >= ax * 0.35) { if (y < 0) next.up = true; else next.down = true; }
      if (ax >= ay * 0.35) { if (x < 0) next.left = true; else next.right = true; }
    }
    var stick = document.getElementById("stick");
    if (stick) {
      var dist = Math.sqrt(x * x + y * y) || 1;
      var k = Math.min(1, (Math.min(r.width, r.height) * 0.32) / dist);
      stick.style.left = 50 + ((x * k) / r.width) * 100 + "%";
      stick.style.top = 50 + ((y * k) / r.height) * 100 + "%";
    }
    return next;
  }

  function resetStick() {
    var stick = document.getElementById("stick");
    if (stick) {
      stick.style.left = "50%";
      stick.style.top = "50%";
    }
    setDirs({ up: false, down: false, left: false, right: false });
  }

  function bindHold(el, onDown, onMove, onUp) {
    var pid = null;
    el.addEventListener("pointerdown", function (ev) {
      if (pid !== null) return;
      pid = ev.pointerId;
      try { el.setPointerCapture(pid); } catch (e) {}
      ev.preventDefault();
      onDown(ev);
    });
    el.addEventListener("pointermove", function (ev) {
      if (ev.pointerId !== pid) return;
      ev.preventDefault();
      if (onMove) onMove(ev);
    });
    function end(ev) {
      if (ev.pointerId !== pid) return;
      pid = null;
      ev.preventDefault();
      onUp(ev);
    }
    el.addEventListener("pointerup", end);
    el.addEventListener("pointercancel", end);
    el.addEventListener("lostpointercapture", function (ev) {
      if (ev.pointerId === pid) { pid = null; onUp(ev); }
    });
  }

  function bindTap(el, fn) {
    if (!el) return;
    el.addEventListener("click", function (ev) {
      ev.preventDefault();
      fn();
    });
  }

  /* ---- scale the 320x240 Spectrum picture into #frame ---- */
  function fitStage() {
    var stage = document.getElementById("stage");
    var frame = document.getElementById("frame");
    if (!stage || !frame) return;
    var canvas = stage.querySelector("canvas");
    var sw = (canvas && (canvas.width || canvas.clientWidth)) || 320;
    var sh = (canvas && (canvas.height || canvas.clientHeight)) || 240;
    var fw = frame.clientWidth;
    var fh = frame.clientHeight;
    if (!fw || !fh) return;
    var scale = Math.min(fw / sw, fh / sh);
    stage.style.width = sw + "px";
    stage.style.height = sh + "px";
    stage.style.minHeight = "";
    stage.style.transform = "scale(" + scale + ")";
  }

  function guessGame() {
    var attr = document.body.getAttribute("data-game");
    if (attr) return attr;
    var path = (window.location.pathname || "").replace(/\/+$/, "");
    if (/\/trigon$/i.test(path) || /\/trigon\/index\.html$/i.test(path)) return "trigon";
    return "atlantis";
  }

  function injectChrome() {
    var game = guessGame();
    document.documentElement.classList.add("phone-touch");
    document.body.classList.add("phone-touch");
    document.body.setAttribute("data-game", game);

    var viewport = document.querySelector('meta[name="viewport"]');
    if (viewport) {
      viewport.setAttribute(
        "content",
        "width=device-width, initial-scale=1, viewport-fit=cover, user-scalable=no"
      );
    }

    var stage = document.getElementById("stage");
    if (!stage || document.getElementById("phone-app")) return game;

    var title = game === "trigon" ? "TRIGON" : "ATLANTIS";
    var otherHref = game === "trigon" ? "../" : "trigon/";
    var otherName = game === "trigon" ? "Atlantis" : "Trigon";

    var app = document.createElement("div");
    app.id = "phone-app";
    app.innerHTML =
      '<header id="phone-bar">' +
        "<h1>" + title + "</h1>" +
        '<div class="actions">' +
          '<button id="btn-start" type="button">Start (1)</button>' +
          '<button id="btn-skip" type="button">Skip</button>' +
          '<button id="btn-speed" type="button">50/25</button>' +
          '<button id="btn-menu" type="button">Menu</button>' +
          '<button id="btn-keys" type="button">Letters</button>' +
          '<button id="btn-full" type="button">Full</button>' +
          '<a id="btn-other" href="' + otherHref + '">' + otherName + "</a>" +
        "</div>" +
      "</header>" +
      '<div id="playfield">' +
        '<div id="frame"></div>' +
        '<div id="controls">' +
          '<div class="pad-wrap">' +
            '<div id="dpad" aria-label="Direction pad"><div id="stick"></div></div>' +
          "</div>" +
          '<div class="fire-wrap">' +
            '<button id="fire" type="button">FIRE</button>' +
          "</div>" +
        "</div>" +
      "</div>" +
      '<p class="phone-hint">Turn the phone sideways for a bigger picture. Drag on the screen or use the pad to swim; hold Fire to shoot.</p>' +
      '<div id="keys-panel"><div id="keys-grid"></div></div>';

    document.body.insertBefore(app, document.body.firstChild);
    document.getElementById("frame").appendChild(stage);
    var play = document.getElementById("play");
    if (play) {
      var label = play.querySelector("span") || play;
      if (label.textContent === "Click to play") label.textContent = "Tap to play";
    }
    return game;
  }

  function chord(symName, keyName) {
    press(symName);
    press(keyName);
    setTimeout(function () {
      release(keyName);
      release(symName);
    }, 140);
  }

  function buildKeypad() {
    var grid = document.getElementById("keys-grid");
    if (!grid) return;
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ".split("").forEach(function (ch) {
      var b = document.createElement("button");
      b.type = "button";
      b.textContent = ch;
      bindTap(b, function () { pulse(ch); });
      grid.appendChild(b);
    });
    var zero = document.createElement("button");
    zero.type = "button";
    zero.className = "wide";
    zero.textContent = "0 (rub out)";
    bindTap(zero, function () { pulse("0"); });
    grid.appendChild(zero);
    var sp = document.createElement("button");
    sp.type = "button";
    sp.className = "wide";
    sp.textContent = "Space";
    bindTap(sp, function () { pulse("SPACE"); });
    grid.appendChild(sp);
  }

  function wrapEmulator() {
    var orig = window.JSSpeccy;
    if (!orig || orig.__phoneWrapped) return;
    var wrapped = function (stage, opts) {
      opts = opts || {};
      opts.zoom = 1;
      opts.uiEnabled = false;
      var emu = orig(stage, opts);
      running = true;
      var tries = 0;
      var ready = setInterval(function () {
        fitStage();
        tries += 1;
        if ((stage.querySelector("canvas") && tries > 5) || tries >= 40) {
          clearInterval(ready);
          fitStage();
        }
      }, 100);
      return emu;
    };
    wrapped.__phoneWrapped = true;
    window.JSSpeccy = wrapped;
  }

  function preventZoomAndScroll() {
    document.addEventListener("gesturestart", function (ev) { ev.preventDefault(); });
    document.addEventListener("gesturechange", function (ev) { ev.preventDefault(); });
    document.addEventListener("touchmove", function (ev) {
      if (ev.touches && ev.touches.length > 1) ev.preventDefault();
    }, { passive: false });
  }

  function setup() {
    injectChrome();
    wrapEmulator();
    preventZoomAndScroll();
    fitStage();
    window.addEventListener("resize", fitStage);
    window.addEventListener("orientationchange", function () { setTimeout(fitStage, 250); });

    var dpad = document.getElementById("dpad");
    bindHold(dpad,
      function (ev) { setDirs(dirsFromPad(ev, dpad)); },
      function (ev) { setDirs(dirsFromPad(ev, dpad)); },
      function () { resetStick(); }
    );

    var fire = document.getElementById("fire");
    bindHold(fire,
      function () { fire.classList.add("on"); press("SPACE"); },
      null,
      function () { fire.classList.remove("on"); release("SPACE"); }
    );

    bindTap(document.getElementById("btn-start"), function () { pulse("1"); });
    bindTap(document.getElementById("btn-skip"), function () { pulse("SPACE"); });
    bindTap(document.getElementById("btn-speed"), function () {
      // Menu option 2, or Symbol Shift + F in play (both are useful).
      pulse("2");
      setTimeout(function () { chord("SYM", "F"); }, 160);
    });
    bindTap(document.getElementById("btn-menu"), function () { chord("SYM", "P"); });

    var keysBtn = document.getElementById("btn-keys");
    var panel = document.getElementById("keys-panel");
    bindTap(keysBtn, function () {
      panel.classList.toggle("open");
      keysBtn.classList.toggle("on", panel.classList.contains("open"));
      setTimeout(fitStage, 50);
    });
    buildKeypad();

    // Drag on the game picture to swim. Fire stays on its own button
    // so direction and fire can be held at once (each pointer is tracked
    // separately on the pad, the picture, and Fire).
    var frame = document.getElementById("frame");
    var gestureId = null;
    var gestureOrigin = null;
    function dirsFromOrigin(ev, origin, el) {
      var r = el.getBoundingClientRect();
      var x = ev.clientX - origin.x;
      var y = ev.clientY - origin.y;
      var thresh = Math.min(r.width, r.height) * 0.06;
      var next = { up: false, down: false, left: false, right: false };
      if (x * x + y * y >= thresh * thresh) {
        var ax = Math.abs(x), ay = Math.abs(y);
        if (ay >= ax * 0.35) { if (y < 0) next.up = true; else next.down = true; }
        if (ax >= ay * 0.35) { if (x < 0) next.left = true; else next.right = true; }
      }
      return next;
    }
    frame.addEventListener("pointerdown", function (ev) {
      if (!running) return;
      if (ev.target.closest && ev.target.closest("#play")) return;
      if (gestureId !== null) return;
      gestureId = ev.pointerId;
      gestureOrigin = { x: ev.clientX, y: ev.clientY };
      try { frame.setPointerCapture(gestureId); } catch (e) {}
      ev.preventDefault();
    });
    frame.addEventListener("pointermove", function (ev) {
      if (ev.pointerId !== gestureId || !gestureOrigin) return;
      setDirs(dirsFromOrigin(ev, gestureOrigin, frame));
      ev.preventDefault();
    });
    function endGesture(ev) {
      if (ev.pointerId !== gestureId) return;
      gestureId = null;
      gestureOrigin = null;
      resetStick();
    }
    frame.addEventListener("pointerup", endGesture);
    frame.addEventListener("pointercancel", endGesture);

    document.addEventListener("visibilitychange", function () {
      if (document.hidden) releaseAll();
    });

    bindTap(document.getElementById("btn-full"), function () {
      var root = document.documentElement;
      if (!document.fullscreenElement && root.requestFullscreen) {
        root.requestFullscreen().then(function () {
          if (screen.orientation && screen.orientation.lock) {
            return screen.orientation.lock("landscape").catch(function () {});
          }
        }).catch(function () {});
      } else if (document.exitFullscreen && document.fullscreenElement) {
        document.exitFullscreen();
      }
      setTimeout(fitStage, 300);
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", setup);
  } else {
    setup();
  }
})();
