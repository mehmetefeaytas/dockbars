(function () {
  "use strict";
  var DICT = window.DOCKBARS_I18N || {};
  var SUPPORTED = ["en", "tr", "de", "es"];

  // Signal that JS is active so reveal-animations can hide-before-reveal safely.
  document.documentElement.classList.add("js");

  // ---------- i18n ----------
  function pickInitialLang() {
    var saved = localStorage.getItem("dockbars-lang");
    if (saved && SUPPORTED.indexOf(saved) !== -1) return saved;
    var nav = (navigator.language || "en").slice(0, 2).toLowerCase();
    return SUPPORTED.indexOf(nav) !== -1 ? nav : "en";
  }

  function applyLang(lang) {
    var strings = DICT[lang] || DICT.en;
    document.documentElement.lang = lang;
    document.querySelectorAll("[data-i18n]").forEach(function (el) {
      var key = el.getAttribute("data-i18n");
      if (strings[key] != null) el.textContent = strings[key];
    });
    document.querySelectorAll(".lang button").forEach(function (btn) {
      btn.setAttribute("aria-pressed", String(btn.getAttribute("data-lang") === lang));
    });
    localStorage.setItem("dockbars-lang", lang);
  }

  document.querySelectorAll(".lang button").forEach(function (btn) {
    btn.addEventListener("click", function () {
      applyLang(btn.getAttribute("data-lang"));
    });
  });

  applyLang(pickInitialLang());

  // ---------- Live clock in the mock menu bar ----------
  var clock = document.getElementById("mbClock");
  function tickClock() {
    if (!clock) return;
    var d = new Date();
    var h = d.getHours(), m = d.getMinutes();
    clock.textContent = h + ":" + (m < 10 ? "0" + m : m);
  }
  tickClock();
  setInterval(tickClock, 15000);

  // ---------- Pocket demo ----------
  var pocket = document.getElementById("pocket");
  var trigger = document.getElementById("trigger");
  var replay = document.getElementById("replayBtn");
  var autoTimer = null;

  function openPocket() { if (pocket) pocket.classList.add("open"); }
  function closePocket() { if (pocket) pocket.classList.remove("open"); }

  function playIntro() {
    clearTimeout(autoTimer);
    closePocket();
    autoTimer = setTimeout(openPocket, 700);
  }

  if (trigger) {
    trigger.addEventListener("mouseenter", function () { clearTimeout(autoTimer); openPocket(); });
  }
  var stage = document.querySelector(".stage");
  if (stage) {
    stage.addEventListener("mouseleave", function () {
      clearTimeout(autoTimer);
      autoTimer = setTimeout(closePocket, 400);
    });
    stage.addEventListener("mouseenter", function () { clearTimeout(autoTimer); openPocket(); });
  }
  if (replay) replay.addEventListener("click", playIntro);

  // Autoplay the intro once the hero is visible.
  var reduce = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  if (reduce) { openPocket(); } else { playIntro(); }

  // ---------- Nav shadow on scroll ----------
  var nav = document.querySelector(".nav");
  if (nav) {
    var onScroll = function () { nav.classList.toggle("scrolled", window.scrollY > 8); };
    window.addEventListener("scroll", onScroll, { passive: true });
    onScroll();
  }

  // ---------- Scroll reveal ----------
  var revealables = document.querySelectorAll(".card, .step");
  if ("IntersectionObserver" in window && !reduce) {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (e.isIntersecting) { e.target.classList.add("in"); io.unobserve(e.target); }
      });
    }, { threshold: 0.12, rootMargin: "0px 0px -8% 0px" });
    revealables.forEach(function (el, i) {
      el.style.transitionDelay = (i % 3) * 60 + "ms";
      io.observe(el);
    });
    // Safety net: if anything is still hidden after 3s (e.g. never scrolled into
    // view on a very tall viewport), reveal it so content is never lost.
    setTimeout(function () {
      revealables.forEach(function (el) {
        var r = el.getBoundingClientRect();
        if (r.top < window.innerHeight) el.classList.add("in");
      });
    }, 3000);
  } else {
    revealables.forEach(function (el) { el.classList.add("in"); });
  }
})();
