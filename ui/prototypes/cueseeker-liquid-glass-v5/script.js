/*
  CueSeeker Liquid Glass v5 split-source prototype interactions.
  Legacy visual state classes are mirrored with ui-* state classes so future
  edits can target the component taxonomy while preserving v3 visual parity.
*/

const win = document.getElementById("window");
    const libraryToggle = document.getElementById("libraryToggle");
    const topbarShioriToggle = document.getElementById("topbarShioriToggle");
    const mainSurface = document.querySelector(".main");
    const videoStage = document.querySelector(".video-stage");
    const videoFrame = document.querySelector(".video-frame");
    const playerDock = document.getElementById("playerDock");
    const closePlaybackButton = document.getElementById("closePlaybackButton");
    const currentZh = document.querySelector("[data-current-zh]");
    const currentJa = document.querySelector("[data-current-ja]");
    const searchInput = document.getElementById("searchInput");
    const clearSearch = document.getElementById("clearSearch");
    const sidebarCount = document.getElementById("sidebarCount");
    const speedButton = document.getElementById("speedButton");
    const speedMenu = document.getElementById("speedMenu");
    const playBtn = document.getElementById("playBtn");
    const playIcon = document.getElementById("playIcon");
    const previousResultButton = document.getElementById("previousResultButton");
    const nextResultButton = document.getElementById("nextResultButton");
    const subtitleToggle = document.getElementById("subtitleToggle");
    const sidePanelToggle = document.getElementById("sidePanelToggle");
    const subtitleOverlay = document.querySelector(".subtitle-overlay");
    const shioriButton = document.getElementById("shioriButton");
    const copySubtitleButton = document.getElementById("copySubtitleButton");
    const fullscreenButton = document.getElementById("fullscreenButton");
    const fullscreenIcon = fullscreenButton?.querySelector("use");
    const progressSlider = document.getElementById("progress");
    const curTime = document.getElementById("curTime");
    const feedbackLayer = document.querySelector(".ui-feedback-overlay");
    const feedbackHud = document.getElementById("playbackFeedback");
    const feedbackIcon = document.querySelector(".ui-feedback-icon");
    const feedbackIconUse = document.getElementById("feedbackIcon");
    const feedbackLabel = document.getElementById("feedbackLabel");
    const themeToggle = document.getElementById("themeToggle");
    const themeLabel = document.getElementById("themeLabel");
    const themeIcon = document.getElementById("themeIcon");
    const disableAllToggle = document.getElementById("disableAllToggle");
    const collapseAllButtons = Array.from(document.querySelectorAll("[data-action='collapse-all']"));

    let isPlaying = false;
    let isShioriSaved = false;
    let playbackSeconds = 30;
    let playbackRate = 1;
    let accumulatedForwardSeconds = 0;
    let accumulatedRewindSeconds = 0;
    let committedSearchQuery = searchInput.value.trim();
    let searchModeDraftValue = searchInput.value;
    let videoLayoutFrame = 0;
    let playerChromeHideTimer = 0;
    let feedbackHideTimer = 0;
    let lastPointerPosition = null;
    const playerDockMargin = 20;
    const playerChromeIdleDelay = 3000;
    const durationSeconds = 23 * 60 + 41;

    function parseAspectRatio(value) {
      if (!value) return 16 / 9;
      const ratioParts = String(value).split(":").map((part) => Number(part.trim()));
      if (ratioParts.length === 2 && ratioParts[0] > 0 && ratioParts[1] > 0) {
        return ratioParts[0] / ratioParts[1];
      }
      const numeric = Number(value);
      return Number.isFinite(numeric) && numeric > 0 ? numeric : 16 / 9;
    }

    function formatPlaybackTime(totalSeconds) {
      const hours = Math.floor(totalSeconds / 3600);
      const minutes = Math.floor((totalSeconds % 3600) / 60);
      const seconds = Math.floor(totalSeconds % 60);
      if (hours > 0) {
        return `${hours}:${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`;
      }
      return `${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`;
    }

    function showPlaybackFeedback({ icon = null, label, tone = "neutral", position = "center" }) {
      if (!feedbackHud || !feedbackIcon || !feedbackIconUse || !feedbackLabel) return;

      clearTimeout(feedbackHideTimer);
      feedbackLayer?.setAttribute("data-feedback-position", position);
      const wasVisible = !feedbackHud.hidden && feedbackHud.classList.contains("is-visible");
      const hasIcon = Boolean(icon);
      if (hasIcon) {
        feedbackIcon.removeAttribute("hidden");
        feedbackIcon.style.display = "";
        feedbackIconUse.setAttribute("href", `#${icon}`);
      } else {
        feedbackIcon.setAttribute("hidden", "");
        feedbackIcon.style.display = "none";
      }
      feedbackLabel.textContent = label;
      feedbackHud.dataset.feedbackTone = tone;
      feedbackHud.dataset.feedbackHasIcon = hasIcon ? "true" : "false";
      feedbackHud.classList.toggle("ui-feedback-hud--text-capsule", !hasIcon);
      feedbackHud.hidden = false;
      feedbackHud.classList.remove("is-entering", "is-updating");
      void feedbackHud.offsetWidth;
      feedbackHud.classList.add("is-visible", wasVisible ? "is-updating" : "is-entering");
      feedbackHideTimer = window.setTimeout(() => {
        feedbackHud.classList.remove("is-visible", "is-entering", "is-updating");
        feedbackHud.hidden = true;
        if (position === "trailing") {
          accumulatedForwardSeconds = 0;
        } else if (position === "leading") {
          accumulatedRewindSeconds = 0;
        } else {
          accumulatedForwardSeconds = 0;
          accumulatedRewindSeconds = 0;
        }
      }, 900);
    }

    function setPlaybackProgress(nextSeconds) {
      playbackSeconds = Math.max(0, Math.min(durationSeconds, nextSeconds));
      const progress = (playbackSeconds / durationSeconds) * 100;
      progressSlider?.style.setProperty("--value", `${progress}%`);
      if (curTime) {
        curTime.textContent = formatPlaybackTime(playbackSeconds);
      }
    }

    function seekRelativeBy(deltaSeconds) {
      setPlaybackProgress(playbackSeconds + deltaSeconds);
      if (deltaSeconds > 0) {
        accumulatedRewindSeconds = 0;
        accumulatedForwardSeconds += Math.abs(deltaSeconds);
        showPlaybackFeedback({
          icon: "play-forward",
          label: `+ ${accumulatedForwardSeconds}s`,
          position: "trailing"
        });
        return;
      }

      accumulatedForwardSeconds = 0;
      accumulatedRewindSeconds += Math.abs(deltaSeconds);
      showPlaybackFeedback({
        icon: "play-back",
        label: `- ${accumulatedRewindSeconds}s`,
        position: "leading"
      });
    }

    function setPlaybackRunning(nextPlaying, showFeedback = true) {
      isPlaying = nextPlaying;
      playIcon.innerHTML = `<use href="#${isPlaying ? "pause" : "play"}"></use>`;
      playBtn.setAttribute("aria-label", isPlaying ? "Pause" : "Play");
      if (showFeedback) {
        showPlaybackFeedback({
          icon: isPlaying ? "play" : "pause",
          label: isPlaying ? "Play" : "Pause"
        });
      }
    }

    function togglePlaybackFromUser(showFeedback = true) {
      setPlaybackRunning(!isPlaying, showFeedback);
    }

    function setSubtitlesVisible(visible, showFeedback = true) {
      setToggleIconButton(subtitleToggle, visible);
      subtitleOverlay.hidden = !visible;
      if (showFeedback) {
        showPlaybackFeedback({
          icon: visible ? "caption-filled" : "caption",
          label: visible ? "Subtitles On" : "Subtitles Off"
        });
      }
    }

    function setShioriSaved(saved, showFeedback = true) {
      isShioriSaved = saved;
      if (showFeedback) {
        showPlaybackFeedback({
          icon: isShioriSaved ? "bookmark-filled" : "bookmark",
          label: isShioriSaved ? "Shiori Saved" : "Shiori Removed",
          tone: "success"
        });
      }
    }

    function copyCurrentSubtitleFromUser() {
      const hasSubtitle = Boolean(currentZh.textContent.trim() || currentJa.textContent.trim());
      showPlaybackFeedback({
        icon: "copy",
        label: hasSubtitle ? "Subtitle Copied" : "No Subtitle",
        tone: hasSubtitle ? "success" : "neutral"
      });
    }

    function setPlaybackSpeed(nextRate, showFeedback = true) {
      playbackRate = Math.max(0.5, Math.min(2, Math.round(nextRate * 4) / 4));
      const rateLabel = `${Number.isInteger(playbackRate) ? playbackRate : playbackRate.toFixed(2).replace(/0$/, "")}×`;
      speedButton.textContent = rateLabel;
      document.querySelectorAll(".speed-option").forEach((option) => {
        const selected = option.dataset.speed === rateLabel;
        option.classList.toggle("selected", selected);
        option.classList.toggle("ui-is-selected", selected);
        option.setAttribute("aria-checked", selected ? "true" : "false");
      });
      if (showFeedback) {
        showPlaybackFeedback({
          icon: "play-forward",
          label: rateLabel
        });
      }
    }

    function navigateAdjacentSearchResult(direction) {
      const rows = Array.from(document.querySelectorAll(".sidebar-row:not([hidden])"));
      if (!rows.length) {
        showPlaybackFeedback({ icon: "play-forward", label: "No Result" });
        return;
      }

      const selectedIndex = Math.max(0, rows.findIndex((row) => row.classList.contains("selected")));
      const nextIndex = Math.max(0, Math.min(rows.length - 1, selectedIndex + direction));
      const nextRow = rows[nextIndex];
      selectCue(nextRow);
      openVideo();
      nextRow.scrollIntoView({ block: "nearest" });
      accumulatedForwardSeconds = 0;
      accumulatedRewindSeconds = 0;
      showPlaybackFeedback({
        icon: direction < 0 ? "play-back" : "play-forward",
        label: direction < 0 ? "Previous Result" : "Next Result",
        position: direction < 0 ? "leading" : "trailing"
      });
    }

    function togglePrototypeFullscreen() {
      const enteringFullscreen = !document.body.classList.contains("prototype-fullscreen");
      if (enteringFullscreen && !hasActivePlayback()) return;
      if (enteringFullscreen) {
        openVideo();
      }
      document.body.classList.toggle("prototype-fullscreen", enteringFullscreen);
      fullscreenButton?.setAttribute("aria-label", enteringFullscreen ? "Exit Fullscreen" : "Fullscreen");
      fullscreenIcon?.setAttribute("href", enteringFullscreen ? "#fullscreen-exit" : "#viewfinder");
      if (enteringFullscreen) {
        hidePlayerChrome({ hideCursor: true });
      } else {
        showPlayerChrome({ protectsFromAutoHide: true });
      }
      showPlaybackFeedback({
        label: enteringFullscreen ? "Enter Fullscreen" : "Exit Fullscreen"
      });
      scheduleVideoFrameLayout();
    }

    function isEditableTarget(target) {
      return Boolean(target?.closest("input, textarea, select, [contenteditable='true']"));
    }

    function updatePlayerDockLayout(stageRect, mainRect) {
      if (!playerDock || !mainRect) return;

      const anchorRect = win.classList.contains("video-expanded") && stageRect
        ? stageRect
        : mainRect;
      const anchorWidth = Math.max(0, anchorRect.width);
      const anchorX = anchorRect.left - mainRect.left;
      const dockWidth = Math.max(0, anchorWidth - playerDockMargin * 2);
      const dockX = anchorX + playerDockMargin;

      playerDock.style.setProperty("--player-dock-width", `${dockWidth}px`);
      playerDock.style.setProperty("--player-dock-x", `${dockX}px`);
    }

    function isVideoExpanded() {
      return win.classList.contains("video-expanded");
    }

    function hasActivePlayback() {
      return !win.classList.contains("playback-closed");
    }

    function pointInVideoStage(point) {
      if (!videoStage || !point) return false;

      const rect = videoStage.getBoundingClientRect();
      return point.x >= rect.left
        && point.x <= rect.right
        && point.y >= rect.top
        && point.y <= rect.bottom;
    }

    function pointInElement(element, point) {
      if (!element || !point) return false;

      const rect = element.getBoundingClientRect();
      return point.x >= rect.left
        && point.x <= rect.right
        && point.y >= rect.top
        && point.y <= rect.bottom;
    }

    function pointInPlayerUi(point) {
      return pointInElement(playerDock, point) || pointInElement(closePlaybackButton, point);
    }

    function pointInPlaybackIdleZone(point) {
      return pointInVideoStage(point) && !pointInPlayerUi(point);
    }

    function clearPlayerChromeHideTimer() {
      clearTimeout(playerChromeHideTimer);
      playerChromeHideTimer = 0;
    }

    function setPlayerCursorHidden(hidden) {
      document.body.classList.toggle("player-cursor-hidden", hidden);
    }

    function setPlayerChromeVisible(visible) {
      const shouldShow = visible && hasActivePlayback();
      win.classList.toggle("player-chrome-visible", shouldShow);
      playerDock?.setAttribute("aria-hidden", shouldShow ? "false" : "true");
    }

    function hidePlayerChrome({ hideCursor = false } = {}) {
      clearPlayerChromeHideTimer();
      if (isVideoExpanded()) {
        setPlayerChromeVisible(false);
      }
      setPlayerCursorHidden(Boolean(hideCursor && pointInPlaybackIdleZone(lastPointerPosition)));
    }

    function schedulePlayerChromeHide() {
      clearPlayerChromeHideTimer();
      if (!isVideoExpanded() || !pointInPlaybackIdleZone(lastPointerPosition)) return;

      playerChromeHideTimer = window.setTimeout(() => {
        if (isVideoExpanded() && pointInPlaybackIdleZone(lastPointerPosition)) {
          hidePlayerChrome({ hideCursor: true });
        }
      }, playerChromeIdleDelay);
    }

    function showPlayerChrome({ protectsFromAutoHide = false } = {}) {
      setPlayerCursorHidden(false);
      if (!isVideoExpanded()) {
        clearPlayerChromeHideTimer();
        setPlayerChromeVisible(true);
        return;
      }

      setPlayerChromeVisible(true);
      if (protectsFromAutoHide || pointInPlayerUi(lastPointerPosition)) {
        clearPlayerChromeHideTimer();
      } else {
        schedulePlayerChromeHide();
      }
    }

    function syncPlayerChromeBoundary() {
      if (!isVideoExpanded()) {
        clearPlayerChromeHideTimer();
        setPlayerChromeVisible(true);
        setPlayerCursorHidden(false);
        return;
      }

      if (!pointInVideoStage(lastPointerPosition) && !pointInPlayerUi(lastPointerPosition)) {
        hidePlayerChrome();
      } else if (pointInPlayerUi(lastPointerPosition)) {
        showPlayerChrome({ protectsFromAutoHide: true });
      } else {
        schedulePlayerChromeHide();
      }
    }

    function registerPlayerChromeActivity(point) {
      lastPointerPosition = point;
      if (pointInPlayerUi(point)) {
        showPlayerChrome({ protectsFromAutoHide: true });
      } else if (pointInVideoStage(point)) {
        showPlayerChrome();
      } else {
        hidePlayerChrome();
        setPlayerCursorHidden(false);
      }
    }

    function updateVideoFrameLayout() {
      const mainRect = mainSurface?.getBoundingClientRect();
      if (!videoStage || !videoFrame || !mainRect) return;

      const stageRect = videoStage.getBoundingClientRect();
      const stageWidth = Math.max(0, stageRect.width);
      const stageHeight = Math.max(0, stageRect.height);
      if (stageWidth === 0 || stageHeight === 0) return;

      updatePlayerDockLayout(stageRect, mainRect);

      const aspectRatio = parseAspectRatio(videoFrame.dataset.videoAspect);
      let frameWidth;
      let frameHeight;
      if (stageWidth / stageHeight > aspectRatio) {
        frameHeight = stageHeight;
        frameWidth = frameHeight * aspectRatio;
      } else {
        frameWidth = stageWidth;
        frameHeight = frameWidth / aspectRatio;
      }

      const frameX = (stageWidth - frameWidth) / 2;
      const frameY = (stageHeight - frameHeight) / 2;

      [videoStage, videoFrame].forEach((el) => {
        el.style.setProperty("--video-frame-width", `${frameWidth}px`);
        el.style.setProperty("--video-frame-height", `${frameHeight}px`);
        el.style.setProperty("--video-frame-x", `${frameX}px`);
        el.style.setProperty("--video-frame-y", `${frameY}px`);
      });
      syncPlayerChromeBoundary();
    }

    function scheduleVideoFrameLayout() {
      cancelAnimationFrame(videoLayoutFrame);
      videoLayoutFrame = requestAnimationFrame(updateVideoFrameLayout);
    }

    function setTheme(theme) {
      const dark = theme === "dark";
      document.body.dataset.theme = dark ? "dark" : "light";
      themeLabel.textContent = dark ? "Dark" : "Light";
      themeIcon.setAttribute("href", dark ? "#moon" : "#sun");
      themeToggle.setAttribute("aria-label", dark ? "Current theme: dark mode. Switch to light mode" : "Current theme: light mode. Switch to dark mode");
      themeToggle.setAttribute("aria-pressed", dark ? "true" : "false");
      scheduleVideoFrameLayout();
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
      const showLibrary = mode === "library";
      const showShiori = mode === "shiori";
      const leavingSearch = (showLibrary || showShiori) && !win.classList.contains("library-mode") && !win.classList.contains("shiori-mode");
      if (leavingSearch) {
        searchModeDraftValue = searchInput.value;
      }
      win.classList.remove("video-expanded");
      win.classList.toggle("library-mode", showLibrary);
      win.classList.toggle("shiori-mode", showShiori);
      setTopbarModeButton(libraryToggle, showLibrary);
      setTopbarModeButton(topbarShioriToggle, showShiori);
      if (showLibrary || showShiori) {
        searchInput.value = "";
      } else {
        searchInput.value = searchModeDraftValue;
      }
      updateClearSearchVisibility();
      updateCollapseAllState();
      syncPlayerChromeBoundary();
      scheduleVideoFrameLayout();
    }

    libraryToggle.addEventListener("click", () => {
      setContentMode(win.classList.contains("library-mode") ? "search" : "library");
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
      if (win.classList.contains("library-mode")) return;
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
      const isMainSearchResult = Boolean(cue.closest(".search-state"));
      const isSidebarResult = Boolean(cue.closest(".sidebar"));
      const rank = cue.dataset.rank;
      document.querySelectorAll(".result-card, .library-episode-card").forEach((el) => {
        el.classList.remove("selected", "ui-is-selected");
      });
      document.querySelectorAll(".sidebar-row").forEach((el) => {
        const selected = (isMainSearchResult || isSidebarResult) && el.dataset.rank === rank;
        el.classList.toggle("selected", selected);
        el.classList.toggle("ui-is-selected", selected);
      });
      currentZh.textContent = cue.dataset.zh;
      currentJa.textContent = cue.dataset.ja;
    }

    function selectLibraryEpisode(episode) {
      document.querySelectorAll(".library-episode-card").forEach((el) => {
        el.classList.remove("selected", "ui-is-selected");
      });
      document.querySelectorAll(".sidebar-row").forEach((el) => {
        el.classList.remove("selected", "ui-is-selected");
      });
      currentZh.textContent = "";
      currentJa.textContent = "";
    }

    function openVideo() {
      win.classList.remove("playback-closed");
      win.classList.add("video-expanded");
      scheduleVideoFrameLayout();
      if (pointInVideoStage(lastPointerPosition)) {
        showPlayerChrome();
      } else {
        hidePlayerChrome();
      }
    }

    function closePlaybackSession() {
      clearPlayerChromeHideTimer();
      document.body.classList.remove("prototype-fullscreen");
      setPlayerCursorHidden(false);
      fullscreenButton?.setAttribute("aria-label", "Fullscreen");
      fullscreenIcon?.setAttribute("href", "#viewfinder");
      win.classList.remove("video-expanded", "player-chrome-visible");
      win.classList.add("playback-closed");
      isPlaying = false;
      playIcon.innerHTML = '<use href="#play"></use>';
      playBtn.setAttribute("aria-label", "Play");
      document.querySelectorAll(".result-card.selected, .result-card.ui-is-selected, .sidebar-row.selected, .sidebar-row.ui-is-selected, .library-episode-card.selected, .library-episode-card.ui-is-selected").forEach((el) => {
        el.classList.remove("selected", "ui-is-selected");
      });
      currentZh.textContent = "";
      currentJa.textContent = "";
      speedMenu.setAttribute("hidden", "");
      speedButton.setAttribute("aria-expanded", "false");
      feedbackHud?.classList.remove("is-visible");
      if (feedbackHud) feedbackHud.hidden = true;
      playerDock?.setAttribute("aria-hidden", "true");
      scheduleVideoFrameLayout();
    }

    document.querySelectorAll(".result-card").forEach((el) => {
      el.addEventListener("click", () => {
        selectCue(el);
        openVideo();
      });
    });

    document.querySelectorAll(".library-episode-card").forEach((el) => {
      el.addEventListener("click", () => {
        selectLibraryEpisode(el);
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

    closePlaybackButton.addEventListener("click", closePlaybackSession);

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
      const selected = !subtitleToggle.classList.contains("selected");
      setSubtitlesVisible(selected);
    });

    shioriButton.addEventListener("click", () => {
      setShioriSaved(!isShioriSaved);
    });

    copySubtitleButton.addEventListener("click", () => {
      copyCurrentSubtitleFromUser();
    });

    fullscreenButton.addEventListener("click", togglePrototypeFullscreen);

    previousResultButton.addEventListener("click", () => {
      navigateAdjacentSearchResult(-1);
    });

    nextResultButton.addEventListener("click", () => {
      navigateAdjacentSearchResult(1);
    });

    sidePanelToggle.addEventListener("click", () => {
      const selected = toggleIconButton(sidePanelToggle);
      win.classList.toggle("sidebar-hidden", !selected);
      scheduleVideoFrameLayout();
      syncPlayerChromeBoundary();
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
    setPlayerChromeVisible(true);
    updateVideoFrameLayout();

    document.addEventListener("pointermove", (event) => {
      registerPlayerChromeActivity({ x: event.clientX, y: event.clientY });
    });
    document.addEventListener("pointerdown", (event) => {
      registerPlayerChromeActivity({ x: event.clientX, y: event.clientY });
    });
    document.addEventListener("pointerleave", hidePlayerChrome);
    window.addEventListener("blur", hidePlayerChrome);

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
      setPlaybackSpeed(Number(opt.dataset.speed.replace("×", "")));
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

    function setVolume(nextVolume, remember = true, showFeedback = false) {
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
      if (showFeedback) {
        showPlaybackFeedback({
          icon: volume === 0 ? "speaker-muted" : "speaker",
          label: volume === 0 ? "Muted" : `Volume ${rounded}%`
        });
      }
    }

    volumeBtn.addEventListener("click", (e) => {
      e.stopPropagation();
      speedMenu.setAttribute("hidden", "");
      speedButton.setAttribute("aria-expanded", "false");
      setVolume(volume > 0 ? 0 : lastNonzeroVolume, volume === 0, true);
    });

    document.addEventListener("click", (e) => {
      if (!speedMenu.contains(e.target) && e.target !== speedButton) {
        speedMenu.setAttribute("hidden", "");
        speedButton.setAttribute("aria-expanded", "false");
      }
    });

    // Play/pause toggle
    playBtn.addEventListener("click", () => {
      togglePlaybackFromUser();
    });

    videoStage.addEventListener("click", (event) => {
      if (!isVideoExpanded() && !document.body.classList.contains("prototype-fullscreen")) return;
      if (event.button !== 0) return;
      const interactiveTarget = event.target.closest("button, input, textarea, select, [contenteditable='true'], [role='button'], [role='slider'], [role='menu']");
      if (interactiveTarget) return;
      togglePlaybackFromUser();
      showPlayerChrome();
    });

    document.addEventListener("keydown", (event) => {
      if (win.classList.contains("controls-disabled")) return;
      if (isEditableTarget(event.target)) return;
      if (event.metaKey || event.ctrlKey || event.altKey) return;
      if (!hasActivePlayback()) return;

      let handled = true;
      switch (event.code) {
        case "Escape":
          if (!document.body.classList.contains("prototype-fullscreen")) {
            handled = false;
            break;
          }
          togglePrototypeFullscreen();
          break;
        case "Space":
          togglePlaybackFromUser();
          break;
        case "KeyC":
          if (event.shiftKey) {
            handled = false;
            break;
          }
          setSubtitlesVisible(!subtitleToggle.classList.contains("selected"));
          break;
        case "KeyF":
          if (event.shiftKey) {
            handled = false;
            break;
          }
          togglePrototypeFullscreen();
          break;
        case "KeyQ":
          if (event.shiftKey) {
            handled = false;
            break;
          }
          copyCurrentSubtitleFromUser();
          break;
        case "KeyS":
          if (event.shiftKey) {
            handled = false;
            break;
          }
          setShioriSaved(!isShioriSaved);
          break;
        case "KeyA":
          if (event.shiftKey) {
            handled = false;
            break;
          }
          navigateAdjacentSearchResult(-1);
          break;
        case "KeyD":
          if (event.shiftKey) {
            handled = false;
            break;
          }
          navigateAdjacentSearchResult(1);
          break;
        case "ArrowLeft":
          seekRelativeBy(-5);
          break;
        case "ArrowRight":
          seekRelativeBy(5);
          break;
        case "ArrowUp":
          setVolume(volume + 5, true, true);
          break;
        case "ArrowDown":
          setVolume(volume - 5, true, true);
          break;
        case "Comma":
          if (event.shiftKey) {
            setPlaybackSpeed(playbackRate - 0.25);
          } else {
            handled = false;
          }
          break;
        case "Period":
          if (event.shiftKey) {
            setPlaybackSpeed(playbackRate + 0.25);
          } else {
            handled = false;
          }
          break;
        default:
          handled = false;
      }

      if (!handled) return;
      event.preventDefault();
      event.stopPropagation();
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

    window.addEventListener("resize", scheduleVideoFrameLayout);
    if ("ResizeObserver" in window) {
      const resizeObserver = new ResizeObserver(scheduleVideoFrameLayout);
      [videoStage, document.getElementById("playerDock"), document.querySelector(".sidebar")]
        .filter(Boolean)
        .forEach((element) => resizeObserver.observe(element));
    }
  
