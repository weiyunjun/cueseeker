/*
  CueSeeker — Info-page card STATE demo (P5.0 C2).
  State switching for Search / Library / Shiori. Mirrors the real App
  conditions in SearchView.swift. Mock card data is prototype-only.
*/
(function () {
  "use strict";

  // Indicative glyphs only — the App uses SF Symbols (see demo note).
  var ICON = {
    search: '<svg class="state-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7"><circle cx="10.5" cy="10.5" r="6.5"/><line x1="15.5" y1="15.5" x2="21" y2="21"/></svg>',
    tray: '<svg class="state-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7"><path d="M3 14l3-9h12l3 9v4a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1z"/><path d="M3 14h5l1.5 2.5h5L16 14h5"/></svg>',
    warn: '<svg class="state-icon is-warning" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7"><path d="M12 3l9.5 17H2.5z"/><line x1="12" y1="9.5" x2="12" y2="14"/><circle cx="12" cy="17" r="0.6" fill="currentColor"/></svg>',
    folder: '<svg class="state-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7"><path d="M3 7a2 2 0 0 1 2-2h4l2 2.5h8a2 2 0 0 1 2 2V18a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/></svg>',
    video: '<svg class="state-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7"><rect x="3" y="5" width="18" height="14" rx="2.5"/><path d="M10 9l5 3-5 3z" fill="currentColor" stroke="none"/></svg>',
    bookmark: '<svg class="state-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7"><path d="M6 4h12v17l-6-4-6 4z"/></svg>'
  };

  // title/message copy is verbatim from SearchView.swift.
  function stateView(icon, title, message, spinner) {
    return (
      '<div class="state-view">' +
      icon +
      '<div class="state-title">' + title + '</div>' +
      '<div class="state-message">' + message + '</div>' +
      (spinner ? '<div class="state-spinner" role="status" aria-label="Loading"></div>' : '') +
      '</div>'
    );
  }

  function chevron() {
    return '<span class="chevron"><svg width="9" height="9" viewBox="0 0 9 9" fill="none" stroke="currentColor" stroke-width="1.6"><path d="M2 1.5L6.5 5 2 8.5"/></svg></span>';
  }

  function card(rank, time, zh, ja) {
    return (
      '<button class="result-card" type="button">' +
      '<span class="meta"><span class="rank">#' + rank + '</span><span>' + time + '</span></span>' +
      '<span class="line">' + zh + '</span>' +
      '<span class="line">' + ja + '</span>' +
      '</button>'
    );
  }

  function searchResultsBody(withLoadMore) {
    var html =
      '<div class="results-header">' +
      '<div class="summary"><span>Found <strong>185</strong> results in <strong>74</strong> files</span></div>' +
      '<button class="small-button" type="button">Collapse All</button>' +
      '</div>' +
      '<div class="scroll">' +
      '<section class="group">' +
      '<button class="group-header" type="button">' + chevron() +
      '<span class="group-title">AVE MUJICA — 01</span><span class="group-count">4 results</span></button>' +
      '<div class="cards">' +
      card(1, "00:30", "毋庸担心 月霞自会为我们将她唤醒", "<mark>大丈夫</mark> 月の光が起こしてくれますわ") +
      card(2, "09:41", "没问题的 诚实就是你的美德哦", "<mark>大丈夫</mark> あなたの誠実さは美徳よ") +
      card(3, "18:37", "祥 武道馆 没问题吧", "祥　武道館　<mark>大丈夫</mark>") +
      card(4, "18:43", "当然没问题", "<mark>大丈夫</mark>に決まっているでしょう") +
      '</div></section>' +
      '<section class="group">' +
      '<button class="group-header" type="button">' + chevron() +
      '<span class="group-title">AVE MUJICA — 02</span><span class="group-count">2 results</span></button>' +
      '<div class="cards">' +
      card(5, "14:26", "小初 你没事吧", "ういちゃん <mark>大丈夫</mark>") +
      card(6, "14:29", "我没事", "私は<mark>大丈夫</mark>だよ") +
      '</div></section>';
    if (withLoadMore) {
      html +=
        '<div class="load-more"><div class="state-spinner" role="status" aria-label="Loading more"></div>' +
        '<span>Loading more results…</span></div>';
    }
    html += '</div>';
    return html;
  }

  function libraryFolder(title, count, eps) {
    var grid = "";
    for (var i = 1; i <= eps; i++) {
      var n = i < 10 ? "0" + i : "" + i;
      grid += '<button class="library-episode-card" type="button">EP' + n + "</button>";
    }
    return (
      '<section class="library-group">' +
      '<button class="group-header library-group-header" type="button">' + chevron() +
      '<span class="library-heading"><span class="library-title">' + title + '</span>' +
      '<span class="library-count">' + count + '</span></span></button>' +
      '<div class="library-episode-grid">' + grid + '</div>' +
      '</section>'
    );
  }

  function libraryBody() {
    return (
      '<div class="scroll" style="padding-top:18px">' +
      libraryFolder("Ave Mujica", "13 episodes", 13) +
      libraryFolder("It's MyGO!!!!!", "13 episodes", 13) +
      '</div>'
    );
  }

  function shioriBody() {
    return (
      '<div class="results-header">' +
      '<div class="summary"><span><strong>3</strong> shioris in <strong>2</strong> files</span></div>' +
      '<button class="small-button" type="button">Collapse All</button>' +
      '</div>' +
      '<div class="scroll">' +
      '<section class="group">' +
      '<button class="group-header" type="button">' + chevron() +
      '<span class="group-title">IT\'S MYGO!!!!! - 02</span><span class="group-count">1 shiori</span></button>' +
      '<div class="cards">' +
      card(1, "00:26", "没事吧?", "大丈夫?") +
      '</div></section>' +
      '<section class="group">' +
      '<button class="group-header" type="button">' + chevron() +
      '<span class="group-title">葬送的芙莉莲 - 09</span><span class="group-count">2 shioris</span></button>' +
      '<div class="cards">' +
      card(1, "17:24", "她到底给这小姑娘做了什么修行", "この小娘に　どんな修行を叩き込んだ") +
      card(2, "22:53", "你听得见我吗", "Can you hear me") +
      '</div></section>' +
      '</div>'
    );
  }

  // condition → state markup. Copy verbatim from SearchView.swift.
  var STATES = {
    "search/query-empty": function () {
      return stateView(ICON.search, "No Search Query",
        "Type a query in the topbar Search field and press Return.");
    },
    "search/searching": function () {
      return stateView(ICON.search, "Searching",
        "Looking through indexed subtitle text.", true);
    },
    "search/failed": function () {
      // App shows the dynamic error string; representative example.
      return stateView(ICON.warn, "Search Failed", "Database is not initialized");
    },
    "search/no-results": function () {
      return stateView(ICON.tray, "No Results",
        "No indexed subtitle entries matched this query.");
    },
    "search/results": function () { return searchResultsBody(false); },
    "search/results-loading-more": function () { return searchResultsBody(true); },

    "library/no-library": function () {
      return stateView(ICON.folder, "No Library",
        "Add subtitle folders in CueSeeker &gt; Settings..., then reindex.");
    },
    "library/loading": function () {
      return stateView(ICON.folder, "Loading Library",
        "Reading indexed videos.", true);
    },
    "library/failed": function () {
      return stateView(ICON.warn, "Library Failed", "Indexed database unavailable");
    },
    "library/no-videos": function () {
      return stateView(ICON.video, "No Videos",
        "Reindex subtitle folders to populate Library videos.");
    },
    "library/videos": function () { return libraryBody(); },

    "shiori/empty": function () {
      return stateView(ICON.bookmark, "No Shiori",
        "Save subtitles from playback to collect Shiori.");
    },
    "shiori/list": function () { return shioriBody(); }
  };

  var panel = document.getElementById("panel");
  var buttons = Array.prototype.slice.call(
    document.querySelectorAll(".demo-btn[data-surface]")
  );

  function render(key) {
    var fn = STATES[key];
    if (!fn) return;
    panel.innerHTML = fn();
    buttons.forEach(function (b) {
      var k = b.getAttribute("data-surface") + "/" + b.getAttribute("data-state");
      b.classList.toggle("is-active", k === key);
    });
  }

  buttons.forEach(function (b) {
    b.addEventListener("click", function () {
      render(b.getAttribute("data-surface") + "/" + b.getAttribute("data-state"));
    });
  });

  var themeToggle = document.getElementById("themeToggle");
  themeToggle.addEventListener("click", function () {
    var dark = document.body.getAttribute("data-theme") === "dark";
    document.body.setAttribute("data-theme", dark ? "light" : "dark");
    themeToggle.textContent = dark ? "Toggle Dark" : "Toggle Light";
  });

  // Default: first Search condition.
  render("search/query-empty");
})();
