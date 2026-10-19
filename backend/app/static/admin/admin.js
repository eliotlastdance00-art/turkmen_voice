(() => {
  "use strict";

  const API = "/api/v1/admin";
  const PAGE_SIZE = 20;
  const AUTO_REFRESH_MS = 45_000;
  const EXPORTS = {
    zip: { path: `${API}/export.zip`, filename: "dataset_bundle.zip" },
    whisper: { path: `${API}/export/whisper.jsonl`, filename: "whisper.jsonl" },
    jsonl: { path: `${API}/export.jsonl`, filename: "dataset.jsonl" },
    csv: { path: `${API}/export.csv`, filename: "dataset.csv" },
    tsv: { path: `${API}/export.tsv`, filename: "metadata.tsv" },
    report: { path: `${API}/export/report.json`, filename: "dataset_report.json" },
  };
  const STATUS_LABELS = {
    pending: "Barlag garaşýar",
    approved: "Tassyklanan",
    rejected: "Ret edilen",
  };
  const SIGNAL_CLASSES = new Set(["warn", "bad", "good", "muted"]);
  const $ = (id) => document.getElementById(id);
  const numberFormat = new Intl.NumberFormat("tk-TM", { maximumFractionDigits: 0 });
  const decimalFormat = new Intl.NumberFormat("tk-TM", { minimumFractionDigits: 1, maximumFractionDigits: 1 });

  // Remove the persistent credential key used by the previous admin panel.
  try { localStorage.removeItem("tk_admin"); } catch (_) { /* Storage can be disabled in private contexts. */ }
  let token = sessionStorage.getItem("tk_admin") || "";
  let offset = 0;
  let queueLoadId = 0;
  let isRefreshing = false;
  let autoRefreshTimer = null;
  let searchTimer = null;
  let pendingReviewId = null;
  let pendingReviewCard = null;
  let toastTimer = null;

  function node(tag, className, text) {
    const element = document.createElement(tag);
    if (className) element.className = className;
    if (text !== undefined && text !== null) element.textContent = String(text);
    return element;
  }

  function safeCount(value) {
    const parsed = Number(value);
    return Number.isFinite(parsed) && parsed > 0 ? parsed : 0;
  }

  function formatCount(value) {
    return numberFormat.format(safeCount(value));
  }

  function formatScore(value, digits = 2) {
    const parsed = Number(value);
    if (!Number.isFinite(parsed)) return "—";
    return new Intl.NumberFormat("tk-TM", {
      minimumFractionDigits: digits,
      maximumFractionDigits: digits,
    }).format(parsed);
  }

  function formatBytes(value) {
    const bytes = safeCount(value);
    if (bytes < 1024) return `${formatCount(bytes)} B`;
    if (bytes < 1_048_576) return `${formatScore(bytes / 1024, 0)} KB`;
    return `${formatScore(bytes / 1_048_576, 1)} MB`;
  }

  function shortId(value) {
    const text = String(value || "");
    if (text.length <= 16) return text || "—";
    return `${text.slice(0, 8)}…${text.slice(-5)}`;
  }

  function formatDate(value) {
    if (!value) return "—";
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return "—";
    return new Intl.DateTimeFormat("tk-TM", {
      day: "2-digit",
      month: "short",
      year: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    }).format(date);
  }

  function formatDuration(milliseconds) {
    const seconds = safeCount(milliseconds) / 1000;
    return `${decimalFormat.format(seconds)} sek.`;
  }

  function setText(id, value) {
    $(id).textContent = value === undefined || value === null ? "—" : String(value);
  }

  function showToast(message, isError = false) {
    const toast = $("toast");
    toast.textContent = String(message);
    toast.classList.toggle("is-error", isError);
    toast.hidden = false;
    window.clearTimeout(toastTimer);
    toastTimer = window.setTimeout(() => { toast.hidden = true; }, 3600);
  }

  function showLogin(message = "") {
    token = "";
    sessionStorage.removeItem("tk_admin");
    window.clearInterval(autoRefreshTimer);
    $("dashboard").hidden = true;
    $("loginScreen").hidden = false;
    $("logoutButton").hidden = true;
    $("adminToken").value = "";
    $("loginMessage").textContent = message;
    $("loginButton").disabled = false;
    $("loginButton").classList.remove("is-loading");
  }

  function showDashboard() {
    $("loginScreen").hidden = true;
    $("dashboard").hidden = false;
    $("logoutButton").hidden = false;
    window.clearInterval(autoRefreshTimer);
    autoRefreshTimer = window.setInterval(() => {
      if (!document.hidden) refreshDashboard();
    }, AUTO_REFRESH_MS);
  }

  async function api(path, options = {}) {
    let response;
    const headers = new Headers(options.headers || {});
    if (token) headers.set("X-Admin-Token", token);
    if (options.body && !headers.has("Content-Type")) headers.set("Content-Type", "application/json");

    try {
      response = await fetch(path, {
        ...options,
        headers,
        cache: "no-store",
        credentials: "same-origin",
      });
    } catch (_) {
      throw new Error("Serwere birikmek başa barmady. Baglanyşygy barlaň.");
    }

    if (response.status === 401) {
      showLogin("Admin tokeni nädogry ýa-da möhleti geçen. Täzeden giriň.");
      throw new Error("token");
    }
    if (!response.ok) {
      let detail = `Isleg şowsuz (${response.status}).`;
      try {
        const payload = await response.json();
        if (typeof payload.detail === "string" && payload.detail) detail = payload.detail;
      } catch (_) {
        // Some export and proxy errors are plain text; avoid showing raw HTML.
      }
      throw new Error(detail);
    }
    if (response.status === 204) return null;
    return response.json();
  }

  async function loadHealth() {
    const status = $("serverStatus");
    try {
      const response = await fetch("/api/v1/health", { cache: "no-store", credentials: "same-origin" });
      if (!response.ok) throw new Error("health");
      const data = await response.json();
      status.classList.toggle("is-secure", data.admin_protected === true);
      status.classList.toggle("is-open", data.admin_protected === false);
      if (data.admin_protected === true) {
        setText("serverText", "Serwer işleýär · admin goragly");
      } else {
        setText("serverText", "Duýduryş · admin goragy ýapyk");
      }
    } catch (_) {
      status.classList.remove("is-secure", "is-open");
      setText("serverText", "Serwere birikmedi");
    }
  }

  function renderRatingDistribution(distribution, total) {
    const container = $("ratingDistribution");
    container.replaceChildren();
    const counts = new Map();
    for (const item of Array.isArray(distribution) ? distribution : []) {
      const score = Number(item.score);
      if (score >= 1 && score <= 5) counts.set(score, safeCount(item.count));
    }
    const maximum = Math.max(1, ...counts.values());

    for (let score = 5; score >= 1; score -= 1) {
      const count = counts.get(score) || 0;
      const row = node("div", "distribution-row");
      const label = node("span", "distribution-label", `${score}★`);
      const bar = node("progress", `score-${score}`);
      bar.max = maximum;
      bar.value = count;
      bar.setAttribute("aria-label", `${score} ýyldyz: ${formatCount(count)} baha`);
      const value = node("span", "distribution-count", formatCount(count));
      row.append(label, bar, value);
      container.append(row);
    }
    setText("ratingTotalChip", `${formatCount(total)} baha`);
  }

  function dayKey(date) {
    return date.toISOString().slice(0, 10);
  }

  function renderActivityChart(recordings, ratings) {
    const chart = $("activityChart");
    chart.replaceChildren();
    const recordingByDay = new Map();
    const ratingByDay = new Map();
    for (const item of Array.isArray(recordings) ? recordings : []) {
      if (item.day) recordingByDay.set(String(item.day).slice(0, 10), safeCount(item.recordings));
    }
    for (const item of Array.isArray(ratings) ? ratings : []) {
      if (item.day) ratingByDay.set(String(item.day).slice(0, 10), safeCount(item.ratings));
    }

    const days = [];
    const now = new Date();
    for (let index = 13; index >= 0; index -= 1) {
      const date = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() - index));
      const key = dayKey(date);
      days.push({
        key,
        date,
        recordings: recordingByDay.get(key) || 0,
        ratings: ratingByDay.get(key) || 0,
      });
    }
    const max = Math.max(1, ...days.map((day) => Math.max(day.recordings, day.ratings)));
    const hasData = days.some((day) => day.recordings || day.ratings);
    if (!hasData) {
      chart.append(node("p", "empty-chart", "Soňky 14 günde işjeňlik bolmady."));
      return;
    }

    const dayFormat = new Intl.DateTimeFormat("tk-TM", { day: "numeric", month: "short", timeZone: "UTC" });
    for (const day of days) {
      const cell = node("div", "activity-day");
      cell.title = `${day.key} · ${formatCount(day.recordings)} ýazgy · ${formatCount(day.ratings)} baha`;
      const bars = node("div", "activity-bars");
      const recordingsBar = node("progress", "activity-recordings");
      recordingsBar.max = max;
      recordingsBar.value = day.recordings;
      recordingsBar.setAttribute("aria-label", `${day.key}: ${formatCount(day.recordings)} ýazgy`);
      const ratingsBar = node("progress", "activity-ratings");
      ratingsBar.max = max;
      ratingsBar.value = day.ratings;
      ratingsBar.setAttribute("aria-label", `${day.key}: ${formatCount(day.ratings)} baha`);
      bars.append(recordingsBar, ratingsBar);
      const label = node("span", "activity-label", dayFormat.format(day.date));
      cell.append(bars, label);
      chart.append(cell);
    }
  }

  function renderModerators(moderators) {
    const tbody = $("moderatorRows");
    tbody.replaceChildren();
    const entries = Array.isArray(moderators) ? moderators.slice(0, 6) : [];
    $("moderatorEmpty").hidden = entries.length > 0;
    for (const moderator of entries) {
      const row = node("tr");
      row.append(
        node("td", "", moderator.display_name || "Anonim"),
        node("td", "", formatCount(moderator.ratings_given)),
        node("td", "", moderator.average_score === null || moderator.average_score === undefined ? "—" : formatScore(moderator.average_score)),
        node("td", "", formatCount(moderator.mismatch_reports)),
      );
      tbody.append(row);
    }
  }

  function renderStats(stats) {
    setText("pendingValue", formatCount(stats.pending_recordings ?? stats.pending));
    setText("approvedValue", formatCount(stats.approved_recordings ?? stats.approved));
    setText("ratingsValue", formatCount(stats.ratings_total));

    const ratingAverage = stats.rating_average;
    const averageText = ratingAverage === null || ratingAverage === undefined ? "—" : formatScore(ratingAverage);
    setText("averageRatingValue", averageText);
    setText("ratingAverageLarge", averageText);
    setText("ratingMatchCaption", `Tekste gabat geliş: ${formatCount(stats.ratings_match_total)} baha`);
    setText("matchPercent", `${formatScore(stats.rating_match_percent ?? 0, 1)}%`);
    setText("disputedValue", formatCount(stats.disputed_recordings));
    setText("consensusValue", formatCount(stats.consensus_recordings));
    setText("healthyValue", formatCount(stats.healthy_recordings));

    const totalSeconds = safeCount(stats.approved_seconds ?? stats.total_seconds);
    const targetSeconds = Math.max(1, safeCount(stats.target_seconds));
    const progress = Math.min(100, Math.round((totalSeconds / targetSeconds) * 1000) / 10);
    $("targetProgress").value = progress;
    const currentHours = decimalFormat.format(totalSeconds / 3600);
    const targetHours = decimalFormat.format(targetSeconds / 3600);
    setText("targetCaption", `${currentHours} / ${targetHours} sagat · ${decimalFormat.format(progress)}%`);

    renderRatingDistribution(stats.rating_distribution, stats.ratings_total);
    renderActivityChart(stats.daily, stats.ratings_daily);
    renderModerators(stats.top_raters || stats.moderators);
  }

  function badgeClass(kind) {
    const safeKind = SIGNAL_CLASSES.has(kind) ? kind : "muted";
    return `signal-badge signal-${safeKind}`;
  }

  function addDetail(detailsGrid, label, value) {
    const item = node("div", "detail-item");
    item.append(node("span", "detail-label", label), node("span", "detail-value", value || "—"));
    detailsGrid.append(item);
  }

  function renderRecord(recording) {
    const status = String(recording.status || "");
    const ratingCount = safeCount(recording.rating_count);
    const reportCount = safeCount(recording.report_count);
    const mismatchCount = safeCount(recording.mismatch_count);
    const score = recording.community_score === null || recording.community_score === undefined
      ? Number.NaN
      : Number(recording.community_score);
    const hasAlert = reportCount > 0 || mismatchCount > 0 || (ratingCount > 0 && Number.isFinite(score) && score < 3);
    const card = node("article", `record-card${hasAlert ? " has-alert" : ""}`);
    const recordingId = String(recording.id || "");
    card.dataset.recordingId = recordingId;

    const heading = node("div", "record-heading");
    const copy = node("div", "record-copy");
    copy.append(node("p", "record-text", recording.text || "Tekst ýok"));
    const meta = node("div", "record-meta");
    meta.append(
      node("span", "", `ID ${shortId(recordingId)}`),
      node("span", "", recording.display_name || "Anonim"),
      node("span", "", formatDate(recording.created_at)),
      node("span", "", formatDuration(recording.duration_ms)),
    );
    copy.append(meta);
    const statusClass = Object.hasOwn(STATUS_LABELS, status) ? `status-${status}` : "status-other";
    const badge = node("span", `status-badge ${statusClass}`, STATUS_LABELS[status] || "Näbelli status");
    heading.append(copy, badge);

    const body = node("div", "record-body");
    const rating = node("div", "record-rating");
    if (ratingCount > 0 && Number.isFinite(score)) {
      const scoreline = node("div", "rating-scoreline");
      scoreline.append(node("strong", "", formatScore(score)), node("span", "", `/ 5 · ${formatCount(ratingCount)} baha`));
      const progress = node("progress", "record-score-progress");
      progress.max = 5;
      progress.value = Math.max(0, Math.min(5, score));
      progress.setAttribute("aria-label", `${formatScore(score)} ýyldyz, ${formatCount(ratingCount)} baha`);
      rating.append(scoreline, progress);
    } else {
      rating.append(node("span", "rating-no-data", ratingCount ? `${formatCount(ratingCount)} baha · ortaça ýok` : "Baha garaşylýar"));
    }

    const signals = node("div", "record-signals");
    const labels = Array.isArray(recording.labels) ? recording.labels : [];
    if (labels.length) {
      for (const label of labels.slice(0, 5)) {
        signals.append(node("span", badgeClass(label.kind), label.text || "Bellik"));
      }
    } else {
      signals.append(node("span", "signal-badge signal-good", "Aýratyn duýduryş ýok"));
    }

    const audioWrap = node("div", "record-audio");
    audioWrap.append(node("span", "audio-label", "Ses ýazgysy"));
    const audio = node("audio");
    audio.controls = true;
    audio.preload = "none";
    audio.setAttribute("aria-label", `${shortId(recordingId)} ýazgysyny diňle`);
    audio.src = `/api/v1/recordings/${encodeURIComponent(recordingId)}/audio`;
    audioWrap.append(audio);
    body.append(rating, signals, audioWrap);

    const actions = node("div", "record-actions");
    const approveButton = node("button", "button button-approve", "Tassykla");
    approveButton.type = "button";
    approveButton.dataset.action = "approve";
    approveButton.disabled = status === "approved";
    approveButton.setAttribute("aria-label", `${shortId(recordingId)} ýazgyny tassykla`);
    const rejectButton = node("button", "button button-reject", "Ret et");
    rejectButton.type = "button";
    rejectButton.dataset.action = "reject";
    rejectButton.disabled = status === "rejected";
    rejectButton.setAttribute("aria-label", `${shortId(recordingId)} ýazgyny ret et`);
    const commentsButton = node("button", "feedback-toggle", `Baha jikme-jigi (${formatCount(ratingCount)})`);
    commentsButton.type = "button";
    commentsButton.dataset.action = "comments";
    commentsButton.setAttribute("aria-expanded", "false");
    actions.append(approveButton, rejectButton, commentsButton);

    const more = node("details", "record-details");
    more.append(node("summary", "", "Has giňişleýin"));
    const moreContent = node("div", "details-content");
    const detailGrid = node("div", "details-grid");
    addDetail(detailGrid, "Ýazgy ID", recordingId);
    addDetail(detailGrid, "Sözlem ID", recording.sentence_id);
    addDetail(detailGrid, "Faýl ölçegi", formatBytes(recording.size_bytes));
    addDetail(detailGrid, "Ses ýygylygy", `${formatCount(recording.sample_rate || 16_000)} Hz`);
    addDetail(detailGrid, "Format", `${formatCount(recording.channels || 1)} kanal · ${formatCount(recording.bits_per_sample || 16)} bit`);
    addDetail(detailGrid, "Normallaşdyrylan tekst", recording.text_normalized || recording.text);
    if (recording.rejection_reason) addDetail(detailGrid, "Soňky karar sebäbi", recording.rejection_reason);
    const deleteButton = node("button", "button button-delete", "Ýazgyny öçür");
    deleteButton.type = "button";
    deleteButton.dataset.action = "delete";
    moreContent.append(detailGrid, deleteButton);
    more.append(moreContent);

    const feedback = node("section", "feedback-panel");
    feedback.hidden = true;
    feedback.setAttribute("aria-label", "Jemgyýetçilik baha teswirleri");
    feedback.setAttribute("aria-live", "polite");
    card.append(heading, body, actions, more, feedback);
    return card;
  }

  function renderQueue(items) {
    const list = $("recordingList");
    list.replaceChildren();
    if (!Array.isArray(items) || items.length === 0) {
      const empty = node("div", "queue-empty", "Bu süzgüç boýunça ýazgy tapylmady. Süzgüji ýa-da gözleg sözüni üýtgedip görüň.");
      list.append(empty);
      return;
    }
    const fragment = document.createDocumentFragment();
    for (const recording of items) fragment.append(renderRecord(recording));
    list.append(fragment);
  }

  function updatePagination(total) {
    const from = total === 0 ? 0 : offset + 1;
    const to = Math.min(total, offset + PAGE_SIZE);
    setText("pageSummary", `${formatCount(from)}–${formatCount(to)} / ${formatCount(total)} ýazgy`);
    $("previousPage").disabled = offset <= 0;
    $("nextPage").disabled = offset + PAGE_SIZE >= total;
  }

  async function loadQueue() {
    const requestId = ++queueLoadId;
    const list = $("recordingList");
    list.setAttribute("aria-busy", "true");
    const params = new URLSearchParams({
      limit: String(PAGE_SIZE),
      offset: String(offset),
      sort: $("sortFilter").value,
    });
    if ($("statusFilter").value) params.set("status", $("statusFilter").value);
    const query = $("searchInput").value.trim();
    if (query) params.set("q", query);

    try {
      const data = await api(`${API}/recordings?${params.toString()}`);
      if (requestId !== queueLoadId) return;
      const total = safeCount(data.total);
      if (offset > 0 && offset >= total) {
        offset = Math.max(0, offset - PAGE_SIZE);
        return loadQueue();
      }
      renderQueue(data.items);
      updatePagination(total);
      setText("queueCount", `${formatCount(total)} ýazgy`);
    } catch (error) {
      if (requestId !== queueLoadId || error.message === "token") return;
      list.replaceChildren(node("div", "queue-error", `Ýazgylar ýüklenmedi: ${error.message}`));
      setText("queueCount", "Ýalňyşlyk");
      updatePagination(0);
    } finally {
      if (requestId === queueLoadId) list.setAttribute("aria-busy", "false");
    }
  }

  async function refreshDashboard() {
    if (isRefreshing || !token || $("dashboard").hidden) return;
    isRefreshing = true;
    const button = $("refreshButton");
    button.disabled = true;
    button.classList.add("is-loading");
    button.setAttribute("aria-busy", "true");
    const queueRequestId = ++queueLoadId;
    try {
      const [stats, recordings] = await Promise.all([
        api(`${API}/stats`),
        loadQueueData(),
      ]);
      renderStats(stats);
      if (queueRequestId === queueLoadId) {
        renderQueue(recordings.items);
        updatePagination(safeCount(recordings.total));
        setText("queueCount", `${formatCount(recordings.total)} ýazgy`);
      }
      setText("updatedAt", `Täzelendi: ${formatDate(new Date().toISOString())}`);
    } catch (error) {
      if (error.message !== "token") showToast(`Maglumat täzelenmedi: ${error.message}`, true);
    } finally {
      isRefreshing = false;
      button.disabled = false;
      button.classList.remove("is-loading");
      button.removeAttribute("aria-busy");
    }
  }

  async function loadQueueData() {
    const params = new URLSearchParams({
      limit: String(PAGE_SIZE),
      offset: String(offset),
      sort: $("sortFilter").value,
    });
    if ($("statusFilter").value) params.set("status", $("statusFilter").value);
    const query = $("searchInput").value.trim();
    if (query) params.set("q", query);
    $("recordingList").setAttribute("aria-busy", "true");
    try {
      const data = await api(`${API}/recordings?${params.toString()}`);
      if (offset > 0 && offset >= safeCount(data.total)) {
        offset = Math.max(0, offset - PAGE_SIZE);
        return loadQueueData();
      }
      return data;
    } finally {
      $("recordingList").setAttribute("aria-busy", "false");
    }
  }

  async function refreshQueueAfterAction() {
    await Promise.all([loadQueue(), api(`${API}/stats`).then(renderStats)]);
  }

  function setCardBusy(card, busy) {
    card.querySelectorAll("button").forEach((button) => {
      if (busy) {
        button.dataset.disabledBeforeBusy = String(button.disabled);
        button.disabled = true;
      } else {
        button.disabled = button.dataset.disabledBeforeBusy === "true";
        delete button.dataset.disabledBeforeBusy;
      }
    });
    card.setAttribute("aria-busy", String(busy));
  }

  async function reviewRecording(recordingId, approved, reason = null, card = null) {
    if (card) setCardBusy(card, true);
    try {
      await api(`${API}/recordings/${encodeURIComponent(recordingId)}/review`, {
        method: "POST",
        body: JSON.stringify({ approved, reason }),
      });
    } catch (error) {
      if (error.message !== "token") showToast(`Karar saklanmady: ${error.message}`, true);
      if (card && card.isConnected) setCardBusy(card, false);
      return;
    }
    if (card && card.isConnected) setCardBusy(card, false);
    showToast(approved ? "Ýazgy tassyklandy." : "Ýazgy ret edildi.");
    try {
      await refreshQueueAfterAction();
    } catch (error) {
      if (error.message !== "token") showToast(`Karar saklandy, ýöne panel täzelenmedi: ${error.message}`, true);
    }
  }

  async function deleteRecording(recordingId, card) {
    const confirmation = window.confirm("Bu ses ýazgysyny we oňa degişli baha maglumatlaryny hemişelik öçürmelimi?");
    if (!confirmation) return;
    setCardBusy(card, true);
    try {
      await api(`${API}/recordings/${encodeURIComponent(recordingId)}`, { method: "DELETE" });
    } catch (error) {
      if (error.message !== "token") showToast(`Ýazgy öçürilmedi: ${error.message}`, true);
      if (card.isConnected) setCardBusy(card, false);
      return;
    }
    if (card.isConnected) setCardBusy(card, false);
    showToast("Ýazgy öçürildi.");
    try {
      await refreshQueueAfterAction();
    } catch (error) {
      if (error.message !== "token") showToast(`Ýazgy öçürildi, ýöne panel täzelenmedi: ${error.message}`, true);
    }
  }

  function renderFeedback(panel, summary) {
    panel.replaceChildren();
    const score = summary.average_score ?? summary.community_score;
    const average = score === null || score === undefined ? "—" : `${formatScore(score)} / 5`;
    panel.append(node("p", "feedback-summary", `Ortaça baha: ${average} · ${formatCount(summary.rating_count)} baha · tekst gabat gelmedik baha: ${formatCount(summary.mismatch_count)}.`));
    const comments = Array.isArray(summary.comments) ? summary.comments : [];
    if (!comments.length) {
      panel.append(node("p", "feedback-comment", "Teswir ýazylan baha ýok. Ýokardaky ýyldyz we tekst gabat geliş görkezijilerine serediň."));
      return;
    }
    const list = node("div", "feedback-list");
    for (const comment of comments) {
      const item = node("article", "feedback-item");
      const top = node("div", "feedback-topline");
      top.append(
        node("strong", "", `${formatCount(comment.score)} / 5`),
        node("span", "", comment.matches_text ? "Tekste gabat gelýär" : "Tekste gabat gelenok"),
        node("span", "", formatDate(comment.created_at)),
      );
      item.append(top, node("p", "feedback-comment", comment.comment || ""));
      list.append(item);
    }
    panel.append(list);
  }

  async function toggleFeedback(button, card) {
    const panel = card.querySelector(".feedback-panel");
    if (!panel.hidden) {
      panel.hidden = true;
      button.setAttribute("aria-expanded", "false");
      return;
    }
    panel.hidden = false;
    button.setAttribute("aria-expanded", "true");
    if (panel.dataset.loaded === "true") return;
    panel.replaceChildren(node("p", "feedback-comment", "Baha maglumatlary ýüklenýär…"));
    try {
      const summary = await api(`${API}/rating-summary/${encodeURIComponent(card.dataset.recordingId)}`);
      renderFeedback(panel, summary);
      panel.dataset.loaded = "true";
    } catch (error) {
      if (error.message !== "token") panel.replaceChildren(node("p", "feedback-comment", `Baha maglumatlary ýüklenmedi: ${error.message}`));
    }
  }

  function openRejectDialog(recordingId, card) {
    pendingReviewId = recordingId;
    pendingReviewCard = card;
    $("reviewReason").value = "";
    const dialog = $("reviewDialog");
    if (typeof dialog.showModal === "function") {
      dialog.showModal();
      window.setTimeout(() => $("reviewReason").focus(), 0);
    } else {
      const reason = window.prompt("Ret etmegiň sebäbi:", "");
      if (reason !== null) reviewRecording(recordingId, false, reason.trim() || "Sebäp görkezilmedi.", card);
      pendingReviewId = null;
      pendingReviewCard = null;
    }
  }

  async function downloadExport(key, button) {
    const config = EXPORTS[key];
    if (!config) return;
    button.disabled = true;
    try {
      const response = await fetch(config.path, {
        headers: token ? { "X-Admin-Token": token } : {},
        cache: "no-store",
        credentials: "same-origin",
      });
      if (response.status === 401) {
        showLogin("Admin tokeni nädogry ýa-da möhleti geçen. Täzeden giriň.");
        return;
      }
      if (!response.ok) {
        let detail = `Eksport şowsuz (${response.status}).`;
        try {
          const payload = await response.json();
          if (typeof payload.detail === "string") detail = payload.detail;
        } catch (_) { /* Keep the safe status message. */ }
        throw new Error(detail);
      }
      const blob = await response.blob();
      const objectUrl = URL.createObjectURL(blob);
      const anchor = node("a");
      anchor.href = objectUrl;
      anchor.download = config.filename;
      document.body.append(anchor);
      anchor.click();
      anchor.remove();
      window.setTimeout(() => URL.revokeObjectURL(objectUrl), 1200);
      showToast(`Eksport taýýar: ${config.filename}`);
    } catch (error) {
      showToast(error.message || "Eksport şowsuz.", true);
    } finally {
      button.disabled = false;
    }
  }

  $("loginForm").addEventListener("submit", async (event) => {
    event.preventDefault();
    const enteredToken = $("adminToken").value.trim();
    if (!enteredToken) {
      $("loginMessage").textContent = "Admin tokenini giriziň.";
      return;
    }
    token = enteredToken;
    $("loginButton").disabled = true;
    $("loginButton").classList.add("is-loading");
    $("loginMessage").textContent = "";
    try {
      await api(`${API}/stats`);
      sessionStorage.setItem("tk_admin", token);
      $("adminToken").value = "";
      showDashboard();
      await refreshDashboard();
    } catch (error) {
      if (error.message !== "token") {
        showLogin(`Giriş başa barmady: ${error.message}`);
        $("adminToken").focus();
      }
    } finally {
      $("loginButton").disabled = false;
      $("loginButton").classList.remove("is-loading");
    }
  });

  $("logoutButton").addEventListener("click", () => showLogin("Panelden çykdyňyz."));
  $("refreshButton").addEventListener("click", refreshDashboard);
  $("statusFilter").addEventListener("change", () => { offset = 0; loadQueue(); });
  $("sortFilter").addEventListener("change", () => { offset = 0; loadQueue(); });
  $("searchInput").addEventListener("input", () => {
    window.clearTimeout(searchTimer);
    searchTimer = window.setTimeout(() => { offset = 0; loadQueue(); }, 280);
  });
  $("previousPage").addEventListener("click", () => {
    offset = Math.max(0, offset - PAGE_SIZE);
    loadQueue();
  });
  $("nextPage").addEventListener("click", () => {
    offset += PAGE_SIZE;
    loadQueue();
  });

  $("recordingList").addEventListener("click", (event) => {
    const button = event.target.closest("button[data-action]");
    if (!button) return;
    const card = button.closest(".record-card");
    if (!card) return;
    const recordingId = card.dataset.recordingId;
    const action = button.dataset.action;
    if (action === "approve") reviewRecording(recordingId, true, null, card);
    if (action === "reject") openRejectDialog(recordingId, card);
    if (action === "delete") deleteRecording(recordingId, card);
    if (action === "comments") toggleFeedback(button, card);
  });

  $("reviewForm").addEventListener("submit", async (event) => {
    event.preventDefault();
    if (!pendingReviewId) return;
    const reason = $("reviewReason").value.trim() || "Sebäp görkezilmedi.";
    const recordingId = pendingReviewId;
    const card = pendingReviewCard;
    pendingReviewId = null;
    pendingReviewCard = null;
    $("reviewDialog").close();
    await reviewRecording(recordingId, false, reason, card);
  });
  $("cancelReview").addEventListener("click", () => {
    pendingReviewId = null;
    pendingReviewCard = null;
    $("reviewDialog").close();
  });
  $("reviewDialog").addEventListener("cancel", () => {
    pendingReviewId = null;
    pendingReviewCard = null;
  });
  $("reviewDialog").addEventListener("click", (event) => {
    if (event.target === $("reviewDialog")) {
      pendingReviewId = null;
      pendingReviewCard = null;
      $("reviewDialog").close();
    }
  });
  document.querySelectorAll("[data-export]").forEach((button) => {
    button.addEventListener("click", () => downloadExport(button.dataset.export, button));
  });

  async function boot() {
    await loadHealth();
    if (!token) {
      showLogin();
      return;
    }
    try {
      await api(`${API}/stats`);
      showDashboard();
      await refreshDashboard();
    } catch (error) {
      if (error.message !== "token") showLogin(`Panel ýüklenmedi: ${error.message}`);
    }
  }

  boot();
})();
