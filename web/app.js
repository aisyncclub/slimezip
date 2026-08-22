/* ZipBar landing page behaviour.
   Two jobs: run the one-shot entrance, then reveal sections on scroll.
   Both are no-ops when the visitor asked for reduced motion. */

(function () {
  'use strict';

  var reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  /* ── Entrance ────────────────────────────────────────────────
     The boot script in <head> already added `motion-pending`, which
     hides the animated elements before first paint so nothing flashes
     in at its final position and then jumps.

     Waiting on fonts matters here: text animated with clip-path
     re-lays-out when a webfont swaps in, and a headline that reflows
     mid-unmask reads as a glitch. The wait is raced against a deadline
     so a slow font CDN can never hold the page hostage. */
  function runEntrance() {
    var root = document.documentElement;

    if (reduced || window.__entrancePlayed) {
      clearTimeout(window.__entranceFailsafe);
      root.classList.remove('motion-pending', 'entrance-run');
      return;
    }
    window.__entrancePlayed = true;

    var started = false;
    function start() {
      if (started) return;
      started = true;
      clearTimeout(window.__entranceFailsafe);
      root.classList.remove('motion-pending');
      root.classList.add('entrance-run');

      // Longest delay plus its duration, plus a little slack. After
      // this the class comes off entirely: leaving it would keep
      // `will-change` hints and their compositor layers alive for the
      // rest of the session, for an animation that already finished.
      setTimeout(function () {
        root.classList.remove('entrance-run');
      }, 1750);
    }

    var deadline = setTimeout(start, 700);
    if (document.fonts && document.fonts.ready) {
      document.fonts.ready.then(function () {
        clearTimeout(deadline);
        start();
      }).catch(start);
    }
  }

  /* ── Scroll reveal ───────────────────────────────────────────
     IntersectionObserver rather than scroll maths: it fires once per
     element, costs nothing while idle, and cannot drift out of sync
     with layout the way a cached offset can.

     Elements unobserve themselves after revealing — a section that
     has already appeared has no reason to keep being watched. */
  function setupReveal() {
    var targets = document.querySelectorAll('.reveal');

    if (reduced || !('IntersectionObserver' in window)) {
      for (var i = 0; i < targets.length; i++) targets[i].classList.add('in');
      return;
    }

    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        var el = entry.target;

        // Stagger children off the parent's single trigger, so a grid
        // resolves across rather than all at once.
        if (el.hasAttribute('data-stagger')) {
          var step = parseInt(el.getAttribute('data-stagger'), 10) || 70;
          var kids = el.children;
          for (var k = 0; k < kids.length; k++) {
            kids[k].style.transitionDelay = (k * step) + 'ms';
          }
        }
        el.classList.add('in');
        io.unobserve(el);
      });
    }, { rootMargin: '0px 0px -12% 0px', threshold: 0.08 });

    for (var j = 0; j < targets.length; j++) io.observe(targets[j]);
  }

  /* ── Marquee ─────────────────────────────────────────────────
     The track scrolls to -50%, so the content must be exactly two
     identical halves for the loop to be seamless. Duplicating in
     script keeps the markup to one copy and makes the invariant hard
     to break by editing HTML. */
  function setupMarquee() {
    var track = document.querySelector('.marquee-track');
    if (!track) return;
    track.setAttribute('aria-hidden', 'true');
    track.innerHTML += track.innerHTML;
  }

  /* ── Hero mascot ─────────────────────────────────────────────
     The same five drawings the menu bar uses, cycled so a visitor sees
     the product's core behaviour before reading about it: the slime
     takes icons one at a time until it is packed, holds, then lets
     them all go.

     Blinking runs on its own clock, because eyes and body are
     independent — a blink that had to wait for a swallow to finish
     would read as a stutter.

     It stops when nobody can see it. A landing page that animates
     forever in a background tab is exactly the CPU waste the app
     itself refuses to commit. */
  function setupMascot() {
    var img = document.getElementById('mascot-img');
    var count = document.getElementById('mascot-count');
    if (!img || !count) return;

    var STAGES = 5;
    var stage = 1;
    var blinking = false;
    var timers = [];
    var running = false;
    var onScreen = true;

    function frame() {
      img.src = 'img/slime-' + (blinking ? 'blink-' : '') + stage + '.png';
    }
    function label() {
      count.textContent = (stage === 1 ? 0 : stage) + '개';
    }

    // Preloaded so the first swap does not flash an empty box while the
    // browser fetches a frame it has never seen.
    for (var i = 1; i <= STAGES; i++) {
      new Image().src = 'img/slime-' + i + '.png';
      new Image().src = 'img/slime-blink-' + i + '.png';
    }

    function after(ms, fn) {
      var t = setTimeout(function () {
        timers = timers.filter(function (x) { return x !== t; });
        if (running) fn();
      }, ms);
      timers.push(t);
      return t;
    }

    function squash(cls, ms) {
      img.classList.remove('gulp', 'release');
      // Reading offsetWidth forces the removal to take effect before the
      // class goes back on; without it the animation never restarts.
      void img.offsetWidth;
      img.classList.add(cls);
      after(ms, function () { img.classList.remove(cls); });
    }

    function blink() {
      if (!running) return;
      blinking = true; frame();
      after(140, function () {
        blinking = false; frame();
        after(2500 + Math.random() * 4000, blink);
      });
    }

    function eat() {
      if (!running) return;
      if (stage < STAGES) {
        stage++; frame(); label(); squash('gulp', 420);
        after(900, eat);
      } else {
        // Hold at full so the "packed" state is readable, then release.
        after(2200, function () {
          stage = 1; frame(); label(); squash('release', 600);
          after(2600, eat);
        });
      }
    }

    function start() {
      if (running) return;
      running = true;
      after(1400, eat);
      after(1800, blink);
    }
    function stop() {
      running = false;
      timers.forEach(clearTimeout);
      timers = [];
    }

    if (reduced) {
      // Show a filled slime and say so: the still frame still carries the
      // message, it just does not move.
      stage = 4; frame(); label();
      return;
    }

    if ('IntersectionObserver' in window) {
      new IntersectionObserver(function (entries) {
        onScreen = entries[0].isIntersecting;
        if (onScreen && !document.hidden) start(); else stop();
      }, { threshold: 0.15 }).observe(img);
    } else {
      start();
    }

    document.addEventListener('visibilitychange', function () {
      if (document.hidden) stop();
      else if (onScreen) start();
    });
  }

  function init() {
    setupMarquee();
    setupReveal();
    setupMascot();
    runEntrance();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
