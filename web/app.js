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

  function init() {
    setupMarquee();
    setupReveal();
    runEntrance();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
