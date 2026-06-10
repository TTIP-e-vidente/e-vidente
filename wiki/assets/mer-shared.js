(function () {
  'use strict';

  /* Progress bar animate on load */
  document.querySelectorAll('.progress-fill[data-pct]').forEach(function (el) {
    var pct = el.getAttribute('data-pct');
    el.style.setProperty('--pct', pct + '%');
    requestAnimationFrame(function () {
      requestAnimationFrame(function () { el.classList.add('animated'); });
    });
  });

  /* Tab panels */
  document.querySelectorAll('.tabs').forEach(function (tabs) {
    var btns = tabs.querySelectorAll('.tab-btn');
    btns.forEach(function (btn) {
      btn.addEventListener('click', function () {
        var id = btn.getAttribute('data-tab');
        if (!id) return;
        btns.forEach(function (b) { b.classList.remove('on'); });
        btn.classList.add('on');
        var wrap = tabs.parentElement;
        wrap.querySelectorAll('.tab-panel').forEach(function (p) {
          p.classList.toggle('on', p.id === id);
        });
      });
    });
  });

  /* Subnav scroll spy */
  var subnav = document.querySelector('.subnav[data-spy]');
  if (subnav) {
    var links = subnav.querySelectorAll('a[href^="#"]');
    var sections = [];
    links.forEach(function (a) {
      var id = a.getAttribute('href').slice(1);
      var sec = document.getElementById(id);
      if (sec) sections.push({ link: a, el: sec });
    });
    if (sections.length) {
      var observer = new IntersectionObserver(function (entries) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting) {
            sections.forEach(function (s) {
              s.link.classList.toggle('on', s.el === entry.target);
            });
          }
        });
      }, { rootMargin: '-40% 0px -50% 0px', threshold: 0 });
      sections.forEach(function (s) { observer.observe(s.el); });
    }
  }

  /* Hub strip active page */
  var path = (location.pathname.split('/').pop() || '').toLowerCase();
  document.querySelectorAll('.hub-pill[data-page]').forEach(function (pill) {
    if (pill.getAttribute('data-page').toLowerCase() === path) {
      pill.classList.add('on');
    }
  });
})();
