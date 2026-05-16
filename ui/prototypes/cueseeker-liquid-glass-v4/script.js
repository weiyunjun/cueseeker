/*
  CueSeeker Liquid Glass v4 split-source prototype interactions.
  Legacy visual state classes are mirrored with ui-* state classes so future
  edits can target the component taxonomy while preserving v3 visual parity.
*/

const win = document.getElementById("window");
    const libraryToggle = document.getElementById("libraryToggle");
    const topbarShioriToggle = document.getElementById("topbarShioriToggle");
    const sourceToggle = document.getElementById("sourceToggle");
    const currentZh = document.querySelector("[data-current-zh]");
    const currentJa = document.querySelector("[data-current-ja]");
    const searchInput = document.getElementById("searchInput");
    const clearSearch = document.getElementById("clearSearch");
    const sidebarCount = document.getElementById("sidebarCount");
    const speedButton = document.getElementById("speedButton");
    const speedMenu = document.getElementById("speedMenu");
    const playBtn = document.getElementById("playBtn");
    const playIcon = document.getElementById("playIcon");
    const subtitleToggle = document.getElementById("subtitleToggle");
    const sidePanelToggle = document.getElementById("sidePanelToggle");
    const subtitleOverlay = document.querySelector(".subtitle-overlay");
    const themeToggle = document.getElementById("themeToggle");
    const themeLabel = document.getElementById("themeLabel");
    const themeIcon = document.getElementById("themeIcon");
    const disableAllToggle = document.getElementById("disableAllToggle");
    const collapseAllButtons = Array.from(document.querySelectorAll("[data-action='collapse-all']"));

    let isPlaying = false;
    let committedSearchQuery = searchInput.value.trim();
    let searchModeDraftValue = searchInput.value;

    function setTheme(theme) {
      const dark = theme === "dark";
      document.body.dataset.theme = dark ? "dark" : "light";
      themeLabel.textContent = dark ? "Dark" : "Light";
      themeIcon.setAttribute("href", dark ? "#moon" : "#sun");
      themeToggle.setAttribute("aria-label", dark ? "Current theme: dark mode. Switch to light mode" : "Current theme: light mode. Switch to dark mode");
      themeToggle.setAttribute("aria-pressed", dark ? "true" : "false");
    }

    function setControlsDisabled(disabled) {
      win.classList.toggle("controls-disabled", disabled);
      disableAllToggle.classList.toggle("on", disabled);
      disableAllToggle.classList.toggle("ui-is-on", disabled);
      disableAllToggle.setAttribute("aria-pressed", disabled ? "true" : "false");
      win.querySelectorAll("button").forEach((button) => {
        button.disabled = disabled;
      });
      if (!disabled) {
        updateCollapseAllState();
      }
    }

    themeToggle.addEventListener("click", () => {
      setTheme(document.body.dataset.theme === "dark" ? "light" : "dark");
    });

    disableAllToggle.addEventListener("click", () => {
      setControlsDisabled(!win.classList.contains("controls-disabled"));
    });

    setTheme("light");
    setControlsDisabled(false);

    function setToggleIconButton(button, selected) {
      button.classList.toggle("selected", selected);
      button.classList.toggle("ui-is-selected", selected);
      button.setAttribute("aria-pressed", selected ? "true" : "false");
      const icon = button.querySelector("use");
      if (icon && button.dataset.iconOff && button.dataset.iconOn) {
        icon.setAttribute("href", "#" + (selected ? button.dataset.iconOn : button.dataset.iconOff));
      }
    }

    function toggleIconButton(button) {
      const selected = !button.classList.contains("selected");
      setToggleIconButton(button, selected);
      return selected;
    }

    document.querySelectorAll(".toggle-icon-button").forEach((button) => {
      setToggleIconButton(button, button.classList.contains("selected") || button.getAttribute("aria-pressed") === "true");
    });

    document.querySelectorAll(".toolbar .toggle-icon-button").forEach((button) => {
      button.addEventListener("click", () => toggleIconButton(button));
    });

    function setTopbarModeButton(button, selected) {
      button.classList.toggle("selected", selected);
      button.classList.toggle("ui-is-selected", selected);
      button.setAttribute("aria-pressed", selected ? "true" : "false");
    }

    function setContentMode(mode) {
      const showShiori = mode === "shiori";
      if (showShiori && !win.classList.contains("shiori-mode")) {
        searchModeDraftValue = searchInput.value;
      }
      win.classList.toggle("shiori-mode", showShiori);
      setTopbarModeButton(topbarShioriToggle, showShiori);
      setTopbarModeButton(libraryToggle, false);
      if (showShiori) {
        searchInput.value = "";
      } else {
        searchInput.value = searchModeDraftValue;
      }
      updateClearSearchVisibility();
      updateCollapseAllState();
    }

    libraryToggle.addEventListener("click", () => {
      setContentMode("search");
    });

    topbarShioriToggle.addEventListener("click", () => {
      setContentMode(win.classList.contains("shiori-mode") ? "search" : "shiori");
    });

    function escapeHTML(value) {
      return value
        .replaceAll("&", "&amp;")
        .replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;")
        .replaceAll('"', "&quot;")
        .replaceAll("'", "&#39;");
    }

    function highlight(value, query) {
      if (!query) return escapeHTML(value);
      const index = value.indexOf(query);
      if (index === -1) return escapeHTML(value);
      return [
        escapeHTML(value.slice(0, index)),
        "<mark>",
        escapeHTML(value.slice(index, index + query.length)),
        "</mark>",
        highlight(value.slice(index + query.length), query)
      ].join("");
    }

    function updateSearch(query) {
      document.querySelectorAll(".search-state .result-card, .sidebar-row").forEach((el) => {
        const matches = !query || el.dataset.zh.includes(query) || el.dataset.ja.includes(query);
        el.hidden = !matches;
        const lines = el.querySelectorAll(".line");
        lines[0].innerHTML = highlight(el.dataset.zh, query);
        lines[1].innerHTML = highlight(el.dataset.ja, query);
      });

      let total = 0;
      document.querySelectorAll(".search-state .group").forEach((group) => {
        const visible = Array.from(group.querySelectorAll(".result-card")).filter((c) => !c.hidden);
        group.hidden = visible.length === 0;
        const count = group.querySelector(".group-count");
        count.textContent = `${visible.length} ${visible.length === 1 ? "result" : "results"}`;
        total += visible.length;
      });

      const summary = document.querySelector(".search-state .summary span");
      if (summary) {
        summary.innerHTML = query
          ? `Found <strong>${total}</strong> result${total === 1 ? "" : "s"} for &ldquo;${escapeHTML(query)}&rdquo;`
          : `Found <strong>185</strong> results in <strong>74</strong> files`;
      }
      updateSidebarSummary();
      updateCollapseAllState();
    }

    function updateClearSearchVisibility() {
      const hidden = searchInput.value.trim().length === 0;
      clearSearch.hidden = hidden;
      clearSearch.style.display = hidden ? "none" : "";
      clearSearch.setAttribute("aria-hidden", hidden ? "true" : "false");
      clearSearch.tabIndex = hidden ? -1 : 0;
    }

    function syncSearchDraft() {
      updateClearSearchVisibility();
    }

    function commitSearchFromInput() {
      updateClearSearchVisibility();
      committedSearchQuery = searchInput.value.trim();
      updateSearch(committedSearchQuery);
    }

    function scheduleSearchDraftSync() {
      requestAnimationFrame(syncSearchDraft);
      setTimeout(syncSearchDraft, 0);
    }

    function updateCollapseAllState() {
      if (!collapseAllButtons.length || win.classList.contains("controls-disabled")) return;
      const activeState = win.classList.contains("shiori-mode")
        ? document.querySelector(".shiori-state")
        : document.querySelector(".search-state");
      const visibleGroups = Array.from(activeState.querySelectorAll(".group")).filter((group) => !group.hidden);
      const hasExpandedGroup = visibleGroups.some((group) => !group.classList.contains("collapsed"));
      collapseAllButtons.forEach((button) => {
        const isActiveButton = button.closest(".search-state, .shiori-state") === activeState;
        if (!isActiveButton) return;
        button.disabled = !hasExpandedGroup;
        button.setAttribute("aria-disabled", hasExpandedGroup ? "false" : "true");
      });
    }

    function updateSidebarSummary() {
      const activeTab = document.querySelector(".segmented button.active")?.dataset.tab;
      if (activeTab === "subs") {
        sidebarCount.textContent = "317 cues";
      } else {
        const visible = document.querySelectorAll(".sidebar-row:not([hidden])").length;
        sidebarCount.textContent = `${visible} result${visible === 1 ? "" : "s"} matching`;
      }
    }

    function selectCue(cue) {
      const isShiori = Boolean(cue.closest(".shiori-state"));
      const rank = cue.dataset.rank;
      document.querySelectorAll(".result-card, .sidebar-row").forEach((el) => {
        const selected = isShiori
          ? el === cue
          : !el.closest(".shiori-state") && el.dataset.rank === rank;
        el.classList.toggle("selected", selected);
        el.classList.toggle("ui-is-selected", selected);
      });
      currentZh.textContent = cue.dataset.zh;
      currentJa.textContent = cue.dataset.ja;
      sourceToggle.querySelector(".source-label").textContent = cue.dataset.source || "Ave Mujica · 01";
    }

    function openVideo() {
      win.classList.add("video-expanded");
      sourceToggle.setAttribute("aria-pressed", "true");
    }

    document.querySelectorAll(".result-card").forEach((el) => {
      el.addEventListener("click", () => {
        selectCue(el);
        openVideo();
      });
    });

    document.querySelectorAll(".sidebar-row").forEach((el) => {
      el.addEventListener("click", () => {
        selectCue(el);
      });
      el.addEventListener("dblclick", () => {
        openVideo();
      });
    });

    sourceToggle.addEventListener("click", () => {
      const expanded = win.classList.toggle("video-expanded");
      sourceToggle.setAttribute("aria-pressed", expanded ? "true" : "false");
    });

    document.querySelectorAll(".segmented button").forEach((btn) => {
      btn.addEventListener("click", () => {
        document.querySelectorAll(".segmented button").forEach((b) => {
          const active = b === btn;
          b.classList.toggle("active", active);
          b.classList.toggle("ui-is-active", active);
        });
        updateSidebarSummary();
      });
    });

    subtitleToggle.addEventListener("click", () => {
      const selected = toggleIconButton(subtitleToggle);
      subtitleOverlay.hidden = !selected;
    });

    sidePanelToggle.addEventListener("click", () => {
      const selected = toggleIconButton(sidePanelToggle);
      win.classList.toggle("sidebar-hidden", !selected);
    });

    document.querySelectorAll(".group-header").forEach((header) => {
      header.addEventListener("click", () => {
        header.parentElement.classList.toggle("collapsed");
        updateCollapseAllState();
      });
    });

    collapseAllButtons.forEach((button) => {
      button.addEventListener("click", (e) => {
        e.currentTarget.closest(".search-state, .shiori-state").querySelectorAll(".group").forEach((group) => {
          group.classList.add("collapsed");
        });
        e.currentTarget.textContent = "Collapse All";
        updateCollapseAllState();
      });
    });

    updateClearSearchVisibility();
    updateCollapseAllState();

    ["input", "change", "keyup", "search", "cut", "paste", "compositionend", "focus", "blur"].forEach((eventName) => {
      searchInput.addEventListener(eventName, scheduleSearchDraftSync);
    });
    searchInput.addEventListener("keydown", (event) => {
      if (event.key === "Enter") {
        event.preventDefault();
        commitSearchFromInput();
      }
    });
    clearSearch.addEventListener("click", () => {
      searchInput.value = "";
      syncSearchDraft();
      searchInput.focus();
    });

    // Speed menu
    speedButton.addEventListener("click", (e) => {
      e.stopPropagation();
      closeVolume();
      const open = speedMenu.hasAttribute("hidden") ? false : true;
      if (open) {
        speedMenu.setAttribute("hidden", "");
        speedButton.setAttribute("aria-expanded", "false");
      } else {
        speedMenu.removeAttribute("hidden");
        speedButton.setAttribute("aria-expanded", "true");
      }
    });
    speedMenu.addEventListener("click", (e) => {
      const opt = e.target.closest(".speed-option");
      if (!opt) return;
      document.querySelectorAll(".speed-option").forEach((o) => {
        const selected = o === opt;
        o.classList.toggle("selected", selected);
        o.classList.toggle("ui-is-selected", selected);
        o.setAttribute("aria-checked", selected ? "true" : "false");
      });
      speedButton.textContent = opt.dataset.speed;
      speedMenu.setAttribute("hidden", "");
      speedButton.setAttribute("aria-expanded", "false");
    });

    // Volume control
    const volumeBtn = document.getElementById("volumeBtn");
    const volumeIcon = document.getElementById("volumeIcon");
    const volumeSlider = document.getElementById("volumeSlider");
    const volumePercent = document.getElementById("volumePercent");
    let volume = 36;
    let lastNonzeroVolume = 36;

    function closeVolume() {
      // Hover owns visibility, matching the App. This hook only keeps other menu code simple.
    }

    function setVolume(nextVolume, remember = true) {
      volume = Math.max(0, Math.min(100, nextVolume));
      const rounded = Math.round(volume);
      volumeSlider.style.setProperty("--value", volume + "%");
      volumeSlider.setAttribute("aria-valuenow", String(rounded));
      volumePercent.textContent = rounded + "%";
      volumeIcon.setAttribute("href", volume === 0 ? "#speaker-muted" : "#speaker");
      volumeBtn.setAttribute("aria-pressed", volume === 0 ? "true" : "false");
      volumeBtn.setAttribute("aria-label", volume === 0 ? "Unmute" : "Mute");
      if (remember && volume > 0) {
        lastNonzeroVolume = volume;
      }
    }

    volumeBtn.addEventListener("click", (e) => {
      e.stopPropagation();
      speedMenu.setAttribute("hidden", "");
      speedButton.setAttribute("aria-expanded", "false");
      setVolume(volume > 0 ? 0 : lastNonzeroVolume, volume === 0);
    });

    document.addEventListener("click", (e) => {
      if (!speedMenu.contains(e.target) && e.target !== speedButton) {
        speedMenu.setAttribute("hidden", "");
        speedButton.setAttribute("aria-expanded", "false");
      }
    });

    // Play/pause toggle
    playBtn.addEventListener("click", () => {
      isPlaying = !isPlaying;
      playIcon.innerHTML = `<use href="#${isPlaying ? "pause" : "play"}"></use>`;
    });

    // Sliders draggable for tactile feel
    document.querySelectorAll(".slider").forEach((slider) => {
      let dragging = false;
      const update = (clientX) => {
        const rect = slider.getBoundingClientRect();
        const pct = Math.max(0, Math.min(1, (clientX - rect.left) / rect.width));
        if (slider === volumeSlider) {
          setVolume(pct * 100, pct > 0);
        } else {
          slider.style.setProperty("--value", (pct * 100) + "%");
        }
      };
      slider.addEventListener("pointerdown", (e) => {
        dragging = true;
        slider.classList.add("is-dragging");
        slider.setPointerCapture(e.pointerId);
        update(e.clientX);
      });
      slider.addEventListener("pointermove", (e) => { if (dragging) update(e.clientX); });
      const stopDragging = () => {
        dragging = false;
        slider.classList.remove("is-dragging");
      };
      slider.addEventListener("pointerup", stopDragging);
      slider.addEventListener("pointercancel", stopDragging);
    });
  
