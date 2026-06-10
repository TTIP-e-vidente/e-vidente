(function () {
  'use strict';

  var WIKI = 'https://github.com/TTIP-e-vidente/e-vidente/wiki';
  var GITHACK = 'https://raw.githack.com/TTIP-e-vidente/e-vidente.wiki/master';

  var VIEWER_PAGES = {
    'entrega-3-presentacion.html': 'Entrega-3-Presentacion',
    'mer.html': 'Mer-Hub',
    'mer-flujo.html': 'Mer-Flujo',
    'mer-persistencia-e3.html': 'Mer-Persistencia-E3',
    'mer-dominio.html': 'Mer-Dominio'
  };

  var host = location.hostname;
  var onViewer = host === 'raw.githack.com' || host === 'htmlpreview.github.io';

  function wikiUrl(slug) {
    var parts = slug.split('#');
    var page = parts[0].replace(/\.md$/i, '');
    var hash = parts[1] ? '#' + parts[1] : '';
    return WIKI + '/' + page + hash;
  }

  function isWikiPageLink(href) {
    if (!href || /^(https?:|mailto:|tel:|#)/.test(href)) return false;
    if (href.indexOf('..') >= 0 || href.indexOf('/') >= 0) return false;
    if (/\.(html|css|js|png|jpe?g|gif|svg|webp|json|gd|tres|woff2?)$/i.test(href.split('#')[0])) return false;
    return /^[A-Za-z][\w\-]*(\#[\w\-]+)?$/.test(href.split('?')[0]);
  }

  function rewriteWikiLinks() {
    document.querySelectorAll('a[href]').forEach(function (a) {
      var href = a.getAttribute('href');
      if (!href || !onViewer) return;
      if (isWikiPageLink(href)) {
        a.setAttribute('href', wikiUrl(href));
        if (!a.hasAttribute('target')) {
          a.setAttribute('target', '_blank');
          a.setAttribute('rel', 'noopener');
        }
      }
    });
  }

  function addWikiBanner() {
    if (!onViewer || document.querySelector('.wiki-viewer-bar')) return;

    var file = (location.pathname.split('/').pop() || '').toLowerCase();
    var wikiPage = VIEWER_PAGES[file] || 'Vistas-Interactivas';

    var bar = document.createElement('div');
    bar.className = 'wiki-viewer-bar';
    bar.innerHTML =
      '<a href="' + wikiUrl(wikiPage) + '" target="_blank" rel="noopener">← Volver a la wiki</a>' +
      '<span>Vista interactiva · E-VIDENTE</span>' +
      '<a href="' + wikiUrl('Vistas-Interactivas') + '" target="_blank" rel="noopener">Índice de vistas</a>';
    document.body.prepend(bar);
    document.documentElement.classList.add('has-wiki-bar');
  }

  rewriteWikiLinks();
  addWikiBanner();
})();
