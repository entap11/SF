/* Disconnected content workspace: repository snapshots in, browser-only drafts out. */
(() => {
  "use strict";
  const C = window.SF_CATALOG;
  const $ = (s, root = document) => root.querySelector(s);
  const esc = (value) =>
    String(value ?? "").replace(
      /[&<>"']/g,
      (c) =>
        ({
          "&": "&amp;",
          "<": "&lt;",
          ">": "&gt;",
          '"': "&quot;",
          "'": "&#39;",
        })[c],
    );
  const clone = (value) => JSON.parse(JSON.stringify(value));
  const KEY = "swarmfront.team-console.drafts.v1";
  const DAY = 86400000;
  const today = new Date().toISOString().slice(0, 10);
  let storageOK = true;
  let state = { version: 1, edits: {}, schedule: [] };
  try {
    const saved = JSON.parse(localStorage.getItem(KEY) || "null");
    if (saved?.version === 1 && saved.edits && Array.isArray(saved.schedule))
      state = saved;
  } catch {
    storageOK = false;
  }
  let page = "overview",
    weekOffset = 0,
    questFilter = "DAILY",
    search = "",
    track = "free",
    levelPage = 0;
  let calendarDate = today,
    calendarView = "week",
    library = "daily",
    librarySearch = "",
    contestPeriod = "WEEKLY";
  let dragged = null,
    lastFocus = null;
  const packs = [
    {
      id: "async-3",
      title: "Rolling async · 3 maps",
      family: "ASYNC_MAP_SET",
      count: 3,
      description: "A short map set. Four players qualify to close a cohort.",
      maps: C.time_map_ids.slice(0, 3),
    },
    {
      id: "async-5",
      title: "Rolling async · 5 maps",
      family: "ASYNC_MAP_SET",
      count: 5,
      description: "The longer route. Five maps, one verified run.",
      maps: C.time_map_ids.slice(0, 5),
    },
    {
      id: "time-3",
      title: "Time Puzzle · 3 maps",
      family: "TIME_PUZZLE",
      count: 3,
      description:
        "Free Roll Time Puzzle, with weekly, monthly and seasonal periods.",
      maps: C.time_map_ids.slice(0, 3),
    },
    {
      id: "time-5",
      title: "Time Puzzle · 5 maps",
      family: "TIME_PUZZLE",
      count: 5,
      description: "A five-map Time Puzzle built from the repository map pack.",
      maps: C.time_map_ids.slice(0, 5),
    },
    {
      id: "gauntlet",
      title: "The Gauntlet",
      family: "GAUNTLET",
      count: 18,
      description:
        "An 18-stage run with increasing difficulty. Natural defeats count for quests.",
      maps: C.gauntlet_map_ids,
    },
  ];
  const titles = {
    overview: "Overview",
    calendar: "Content calendar",
    contests: "Contests & maps",
    quests: "Daily & weekly quests",
    battlepath: "Battlepath",
    drafts: "Drafts",
    sources: "Source details",
  };
  const parseDate = (s) => new Date(s + "T00:00:00Z");
  const iso = (d) => new Date(d).toISOString().slice(0, 10);
  const monday = (s) => {
    const d = parseDate(s);
    d.setUTCDate(d.getUTCDate() - ((d.getUTCDay() + 6) % 7));
    return iso(d);
  };
  const shift = (s, n) => iso(parseDate(s).getTime() + n * DAY);
  const dateLabel = (s, options = { month: "short", day: "numeric" }) =>
    parseDate(s).toLocaleDateString("en-US", { ...options, timeZone: "UTC" });
  const weekStart = () => shift(monday(today), weekOffset * 7);
  const getQuest = (id) =>
    state.edits["quest:" + id]?.value || C.quests.find((q) => q.id === id);
  const getPack = (id) =>
    state.edits["contest:" + id]?.value || packs.find((p) => p.id === id);
  const passConfig = () => state.edits["season"]?.value || C.battlepath.config;
  const getLevel = (n) =>
    state.edits["level:" + n]?.value ||
    C.battlepath.levels.find((l) => l.level === n);
  const honey = (q) =>
    (q.reward.honey_centi / 100).toLocaleString("en-US", {
      maximumFractionDigits: 2,
    });
  const nectar = (q) =>
    (q.reward.nectar_milli / 1000).toLocaleString("en-US", {
      maximumFractionDigits: 3,
    });
  const draftBadge = (key) =>
    state.edits[key] ? '<span class="badge draft">Draft</span>' : "";
  function toast(message) {
    $("#toast").textContent = message;
    $("#toast").classList.add("show");
    clearTimeout(toast.timer);
    toast.timer = setTimeout(() => $("#toast").classList.remove("show"), 3400);
  }
  function save() {
    try {
      localStorage.setItem(KEY, JSON.stringify(state));
      storageOK = true;
      return true;
    } catch {
      storageOK = false;
      toast("Browser storage unavailable. Export your drafts to keep them.");
      return false;
    }
  }
  function edit(key, kind, value) {
    state.edits[key] = { kind, value, updated_at: new Date().toISOString() };
    save();
    closeEditor();
    render();
    toast("Draft saved locally. Nothing published.");
  }
  function currentAssignments(start = weekStart()) {
    const i = Math.round(
      (parseDate(start) - parseDate("2026-09-28")) / (7 * DAY),
    );
    return C.weeks[((i % 9) + 9) % 9].map((a, index) => ({
      id: a.quest_id,
      date: index < 21 ? shift(start, Math.floor(index / 3)) : start,
      period: index < 21 ? "DAILY" : "WEEKLY",
    }));
  }
  function heading(title, description, actions = "") {
    return `<div class="page-heading"><div><span class="eyebrow">CONTENT OPERATIONS</span><h1>${esc(title)}</h1><p>${esc(description)}</p></div>${actions}</div>`;
  }
  function weekControls() {
    return `<div class="week-toolbar"><button class="icon-button" data-action="week-prev" aria-label="Previous week">‹</button><span class="week-label">${dateLabel(weekStart())} – ${dateLabel(shift(weekStart(), 6))}</span><button class="icon-button" data-action="week-next" aria-label="Next week">›</button></div>`;
  }
  function miniCalendar() {
    const a = currentAssignments();
    return `<div class="calendar">${Array.from({ length: 7 }, (_, i) => {
      const date = shift(weekStart(), i);
      return `<div class="day ${date === today ? "today" : ""}"><div class="day-title"><b>${parseDate(date).getUTCDate()}</b>${dateLabel(date, { weekday: "short" }).toUpperCase()}</div>${a
        .filter((x) => x.period === "DAILY" && x.date === date)
        .map(
          (x) =>
            `<button data-quest="${esc(x.id)}">${esc(getQuest(x.id).title)}</button>`,
        )
        .join("")}</div>`;
    }).join("")}</div>`;
  }
  function overview() {
    const a = currentAssignments(),
      total = a.reduce((n, x) => n + getQuest(x.id).reward.honey_centi, 0),
      bonus = Math.floor((total * C.bonus_bps) / 10000);
    return (
      heading(
        "Plan the next week.",
        "Contests, quests and Battlepath. One place to line them up.",
        `<a class="button gold" href="#calendar">Open calendar ↗</a>`,
      ) +
      `
 <section class="hero"><div><span class="eyebrow">THE WEEKLY RHYTHM</span><h2>Different ways to play.<br>One connected week.</h2><p>Mix the modes, choose the maps, and give players a reason to explore the whole front.</p><a class="button ghost" href="#calendar">Build a schedule →</a></div><div class="hero-stats"><div class="hero-stat"><b>24</b><span>daily templates</span></div><div class="hero-stat"><b>4</b><span>weekly quests</span></div><div class="hero-stat"><b>10%</b><span>full-week Honey bonus</span></div></div></section>
 <div class="grid stats"><div class="stat"><span>DAILY ROTATION</span><b>3 per day</b><small>Shared progress across modes</small></div><div class="stat"><span>CONTEST STARTING POINTS</span><b>${packs.length} templates</b><small>Async, Time Puzzle & Gauntlet</small></div><div class="stat"><span>BATTLEPATH</span><b>${C.battlepath.levels.length} levels</b><small>Free · Premium · Elite</small></div><div class="stat"><span>FULL-WEEK QUEST HONEY</span><b>${((total + bonus) / 100).toFixed(2)}</b><small class="gold-text">${(total / 100).toFixed(2)} base + ${(bonus / 100).toFixed(2)} bonus · provisional</small></div></div>
 <section><div class="section-heading"><div><h2>The daily lineup</h2><p>Repository rotation${Object.keys(state.edits).some((k) => k.startsWith("quest:")) ? " with local quest drafts" : ""} · UTC</p></div>${weekControls()}</div>${miniCalendar()}<p class="section-note">A preview of the three-per-day rotation. Add it to the planning calendar to customize the schedule.</p></section>
 <div class="grid two-columns"><section class="card"><div class="section-heading"><h2>The weekly extras</h2><a href="#quests" data-weekly-link>View quests ↗</a></div>${C.quests
   .filter((q) => q.cadence === "WEEKLY")
   .map(
     (q) =>
       `<div class="line-item"><span>${esc(getQuest(q.id).title)}</span><button class="link-button" data-quest="${q.id}">Inspect →</button></div>`,
   )
   .join(
     "",
   )}</section><section class="card"><div class="eyebrow">NEXT UP</div><h3>Build a week by dropping it in.</h3><p>Pick from the catalog, drop onto the calendar, and review each contest’s maps and quest rewards.</p><div class="line-item"><span>Schedule entries</span><strong>${state.schedule.length}</strong></div><div class="line-item"><span>Content drafts</span><strong>${Object.keys(state.edits).length}</strong></div><div class="card-footer"><span class="badge muted-badge">Local only</span><a class="link-button" href="#drafts">Review drafts →</a></div></section></div>`
    );
  }
  function questCard(q, index) {
    return `<article class="card quest-card"><div class="card-top"><span class="badge ${q.cadence === "WEEKLY" ? "mint" : ""}">${q.cadence === "WEEKLY" ? "Weekly" : "Daily"}</span><span class="quest-number">${String(index + 1).padStart(2, "0")}</span></div><h3>${esc(q.title)}</h3>${draftBadge("quest:" + q.id)}<ul class="objectives">${q.objectives.map((o) => `<li>${o.target} ${esc(o.label)}</li>`).join("")}</ul><div class="card-footer"><span class="reward">${honey(q)} Honey · ${nectar(q)} Nectar</span><button class="link-button" data-quest="${esc(q.id)}">Edit draft →</button></div></article>`;
  }
  function questCards() {
    const rows = C.quests
      .map((q) => getQuest(q.id))
      .filter(
        (q) =>
          q.cadence === questFilter &&
          (q.title + " " + q.objectives.map((o) => o.label).join(" "))
            .toLowerCase()
            .includes(search.toLowerCase()),
      );
    return rows.length
      ? rows.map(questCard).join("")
      : '<div class="empty">No quests match that search.</div>';
  }
  function quests() {
    return (
      heading(
        "A reason to explore.",
        "The approved v1 catalog. Every quest mixes different parts of the game.",
      ) +
      `<div class="filters"><div class="segmented">${["DAILY", "WEEKLY"].map((c) => `<button data-filter="${c}" class="${questFilter === c ? "selected" : ""}">${c === "DAILY" ? "Daily · 24" : "Weekly · 4"}</button>`).join("")}</div><input class="search" id="quest-search" aria-label="Search quests" placeholder="Search quests or game types…" value="${esc(search)}"></div><div class="grid quest-grid" id="quest-grid">${questCards()}</div>`
    );
  }
  function mapSVG(id) {
    const entry = C.maps.find((m) => m.id === id);
    if (!entry) return "";
    const m = entry.definition;
    const w = m.grid?.w || m.grid_width || 20,
      h = m.grid?.h || m.grid_height || 28;
    const nodes = m.nodes || m.hives || [];
    const points = nodes.filter((n) => (n.kind || "hive") === "hive");
    return `<svg viewBox="-2 -2 ${w + 4} ${h + 4}" role="img" aria-label="${esc(entry.name)} hive positions"><rect x="0" y="0" width="${w}" height="${h}" fill="#162326" rx="1"/>${Array.from({ length: Math.ceil(h / 4) }, (_, i) => `<path d="M0 ${i * 4}H${w}" stroke="#263a37" stroke-width=".13"/>`).join("")}${Array.from({ length: Math.ceil(w / 4) }, (_, i) => `<path d="M${i * 4} 0V${h}" stroke="#263a37" stroke-width=".13"/>`).join("")}${points
      .map((n) => {
        const x = n.pos?.x ?? n.x,
          y = n.pos?.y ?? n.y;
        if (!Number.isFinite(x) || !Number.isFinite(y)) return "";
        const color =
          n.owner === "P1"
            ? "#e6bf66"
            : n.owner === "P2"
              ? "#86bca8"
              : "#71877a";
        return `<circle cx="${x}" cy="${y}" r=".63" fill="${color}"/><circle cx="${x}" cy="${y}" r="1.05" fill="none" stroke="${color}" stroke-opacity=".2" stroke-width=".2"/>`;
      })
      .join("")}</svg>`;
  }
  function contests() {
    return (
      heading(
        "Set the field.",
        "Repository contest templates and map sets, ready to inspect and draft.",
        `<a class="button gold" href="#calendar">Schedule a contest ↗</a>`,
      ) +
      `<p class="notice">These are content templates, not live contests. Map thumbnails show authored hive positions. Future-library maps still need release validation.</p><div class="grid pack-grid">${packs
        .map((base) => {
          const p = getPack(base.id);
          return `<article class="card"><div class="pack-art">${mapSVG(p.maps[0])}<span class="badge">${p.count} ${p.family === "GAUNTLET" ? "stages" : "maps"}</span></div><h3>${esc(p.title)}</h3><p>${esc(p.description)}</p><div class="pill-row"><span class="badge future">Map readiness unverified</span>${draftBadge("contest:" + p.id)}</div><div class="card-footer"><span class="quiet">${p.family === "GAUNTLET" ? "Weekly run" : "Ordered map set"}</span><button class="link-button" data-pack="${p.id}">Inspect & edit →</button></div></article>`;
        })
        .join("")}</div>`
    );
  }
  const rewardName = (r) =>
    !r || r.reward_type === "none"
      ? "No reward"
      : `${r.quantity ?? 1} ${String(r.reward_type).replaceAll("_", " ")}${r.buff_id ? " · " + r.buff_id.replaceAll("_", " ") : r.cosmetic_id ? " · " + r.cosmetic_id.replaceAll("_", " ") : ""}`;
  function battlepath() {
    const config = passConfig();
    const start = levelPage * 20 + 1;
    return (
      heading(
        "A season worth playing.",
        "Battlepath rewards from the game’s resolved configuration.",
        `<button class="button gold" data-action="season">Edit season draft</button>`,
      ) +
      `<section class="hero"><div><span class="eyebrow">BATTLEPATH · SOURCE CONFIGURATION</span><h2>${esc(config.display_name)}</h2><p>${dateLabel(iso(config.start_time_unix * 1000), { month: "short", day: "numeric", year: "numeric" })} – ${dateLabel(iso(config.end_time_unix * 1000), { month: "short", day: "numeric", year: "numeric" })} · ${config.total_levels} levels</p><span class="badge ${config.end_time_unix * 1000 < Date.now() ? "future" : "muted-badge"}">${config.end_time_unix * 1000 < Date.now() ? "Configured season has ended" : "Configuration preview"}</span> ${draftBadge("season")}</div><div class="hero-stats"><div class="hero-stat"><b>100</b><span>base levels</span></div><div class="hero-stat"><b>+20</b><span>extended levels</span></div></div></section><div class="track-controls"><div class="segmented">${["free", "premium", "elite"].map((t) => `<button data-track="${t}" class="${track === t ? "selected" : ""}">${t[0].toUpperCase() + t.slice(1)}</button>`).join("")}</div><div class="week-toolbar"><button class="icon-button" data-action="levels-prev" aria-label="Previous levels" ${levelPage === 0 ? "disabled" : ""}>‹</button><span class="week-label">Levels ${start}–${start + 19}</span><button class="icon-button" data-action="levels-next" aria-label="Next levels" ${levelPage === 5 ? "disabled" : ""}>›</button></div></div><div class="grid track-grid">${C.battlepath.levels
        .slice(start - 1, start + 19)
        .map((base) => {
          const l = getLevel(base.level),
            r = l.tracks[track];
          return `<article class="level-card"><span class="level">LEVEL ${l.level}</span>${draftBadge("level:" + l.level)}<div class="reward-icon">${r?.reward_type === "honey" ? "⬡" : r?.reward_type === "none" ? "—" : "◇"}</div><div class="reward-name">${esc(rewardName(r))}</div><small>${l.xp_required} Nectar to advance</small><button class="link-button" data-level="${l.level}">Edit reward →</button></article>`;
        })
        .join(
          "",
        )}</div><p class="section-note">This displays resolved game configuration, including defaults. It does not confirm deployed season settings or economic authority.</p>`
    );
  }
  function sources() {
    return (
      heading(
        "Know what you’re looking at.",
        "A repository snapshot, with browser drafts layered over it.",
      ) +
      `<div class="notice">Exported ${esc(new Date(C.generated_at).toLocaleString())}. No service credentials, player data or live environment connection.</div><div class="source-list">${C.sources.map((s) => `<article class="card"><div class="source-path">${esc(s.path)}</div><code>SHA-256 ${esc(s.sha256)}</code></article>`).join("")}</div><section class="card"><h3>What the preview does</h3><ul class="help-list"><li>Reads ${C.quests.length} quest definitions, ${C.battlepath.levels.length} resolved Battlepath levels and ${C.maps.length} referenced maps.</li><li>Saves draft edits and calendar entries in this browser; exports them as a planning bundle.</li><li>Uses the game’s existing Swarmfront logo and Iceland font.</li><li>Does not publish contests, change server assignments or distribute a beta build.</li></ul></section>`
    );
  }
  function drafts() {
    const entries = Object.entries(state.edits);
    return (
      heading(
        "A place to get it right.",
        "Local content edits and planned calendar entries.",
        `<button class="button gold" data-action="export">Export draft bundle ↗</button>`,
      ) +
      `<div class="notice">${entries.length} content draft${entries.length === 1 ? "" : "s"} · ${state.schedule.length} calendar entr${state.schedule.length === 1 ? "y" : "ies"}. Publishing is disconnected. Exported files are for review, not a direct service upload.</div>${entries.length ? entries.map(([key, d]) => `<div class="draft-row"><span class="badge draft">${esc(d.kind)}</span><div class="grow"><h3>${esc(d.value.title || d.value.display_name || "Battlepath level " + d.value.level)}</h3><p>Saved ${esc(new Date(d.updated_at).toLocaleString())}</p></div><button class="link-button" data-edit-key="${esc(key)}">Review →</button><button class="button small ghost" data-discard="${esc(key)}">Discard</button></div>`).join("") : '<div class="empty"><h2>Room for your next idea.</h2><p>Edit a quest, choose a map set, or plan a day on the calendar.</p><a class="button" href="#calendar">Open calendar →</a></div>'}<div class="schedule-list"><div class="section-heading"><h2>Planned on the calendar</h2><a href="#calendar">Open planner ↗</a></div>${
        state.schedule
          .slice()
          .sort((a, b) => a.start.localeCompare(b.start))
          .map(
            (event) =>
              `<div class="draft-row"><span class="badge">${esc(event.period)}</span><div class="grow"><h3>${esc(eventName(event))}</h3><p>${esc(dateLabel(event.start, { month: "short", day: "numeric", year: "numeric" }))} · ${event.kind === "quest" ? "Quest" : "Contest launch"} · local draft</p></div><button class="link-button" data-event="${esc(event.uid)}">Review →</button><button class="button small ghost" data-remove-event="${esc(event.uid)}">Remove</button></div>`,
          )
          .join("") || '<p class="quiet">No entries scheduled yet.</p>'
      }</div><button class="button" disabled>Publish to server · not connected</button>`
    );
  }
  function eventName(e) {
    return e.kind === "quest"
      ? getQuest(e.id)?.title || e.id
      : getPack(e.id)?.title || e.id;
  }
  function libraryItems() {
    const items =
      library === "contests"
        ? packs.map((p) => ({
            kind: "contest",
            id: p.id,
            period: p.family === "GAUNTLET" ? "WEEKLY" : contestPeriod,
            title: getPack(p.id).title,
            meta: `${p.count} ${p.family === "GAUNTLET" ? "stages" : "maps"} · ${p.family === "ASYNC_MAP_SET" ? "rolling cohorts" : "period contest"}`,
          }))
        : C.quests
            .filter(
              (q) => q.cadence === (library === "daily" ? "DAILY" : "WEEKLY"),
            )
            .map((q) => ({
              kind: "quest",
              id: q.id,
              period: q.cadence,
              title: getQuest(q.id).title,
              meta: getQuest(q.id)
                .objectives.map((o) => `${o.target} ${o.label}`)
                .join(" · "),
            }));
    return items.filter((i) =>
      (i.title + " " + i.meta)
        .toLowerCase()
        .includes(librarySearch.toLowerCase()),
    );
  }
  function libraryHTML() {
    return (
      libraryItems()
        .map(
          (i) =>
            `<div class="library-card" draggable="true" data-drag="${esc(JSON.stringify({ kind: i.kind, id: i.id, period: i.period }))}"><span class="drag-handle" aria-hidden="true">⠿</span><div><strong>${esc(i.title)}</strong><p>${esc(i.meta)}</p><div class="library-bottom"><span class="badge">${i.period.toLowerCase()}</span><button class="link-button" data-plan="${esc(JSON.stringify({ kind: i.kind, id: i.id, period: i.period }))}" aria-label="Schedule ${esc(i.title)}">＋ Add</button></div></div></div>`,
        )
        .join("") || '<p class="quiet">No matching catalog items.</p>'
    );
  }
  function planEvent(e) {
    const unsupported =
      e.kind === "contest" &&
      e.period === "DAILY" &&
      getPack(e.id)?.family === "TIME_PUZZLE";
    return `<button class="plan-event ${e.kind === "contest" ? "contest-event" : "quest-event"}" draggable="true" data-move="${esc(e.uid)}" data-event="${esc(e.uid)}"><span>${e.kind === "quest" ? "◇" : "⚑"}</span>${esc(eventName(e))}${unsupported ? '<small class="planning-warning">Needs daily period support</small>' : ""}</button>`;
  }
  function startFor(date, period) {
    return period === "WEEKLY"
      ? monday(date)
      : period === "MONTHLY"
        ? date.slice(0, 7) + "-01"
        : date;
  }
  function scheduleItems(start, period) {
    return state.schedule
      .filter((e) => e.start === start && e.period === period)
      .map(planEvent)
      .join("");
  }
  function calendar() {
    const start =
      calendarView === "month"
        ? monday(calendarDate.slice(0, 7) + "-01")
        : calendarView === "week"
          ? monday(calendarDate)
          : calendarDate;
    const days =
      calendarView === "month" ? 42 : calendarView === "week" ? 7 : 1;
    const weekly = monday(calendarDate),
      monthly = calendarDate.slice(0, 7) + "-01";
    return (
      heading(
        "Drop it in. Plan it out.",
        "Drag from the catalog, or use “Add” to choose a date. Everything here is a local schedule draft.",
        `<button class="button gold" data-action="seed-week">Use quest rotation</button>`,
      ) +
      `
 <div class="planner-controls"><div class="segmented">${["day", "week", "month"].map((v) => `<button data-view="${v}" class="${calendarView === v ? "selected" : ""}">${v[0].toUpperCase() + v.slice(1)}</button>`).join("")}</div><div class="week-toolbar"><button class="icon-button" data-action="calendar-prev" aria-label="Previous calendar period">‹</button><label class="date-jump"><span class="sr-only">Calendar date</span><input type="date" id="calendar-date" value="${calendarDate}" required></label><button class="icon-button" data-action="calendar-next" aria-label="Next calendar period">›</button><button class="button small ghost" data-action="calendar-today">Today</button></div></div>
 <div class="planner"><aside class="library"><div class="section-heading"><h2>The catalog</h2><span class="badge muted-badge">Drag or add</span></div><div class="segmented library-tabs">${[
   ["daily", "Daily"],
   ["weekly", "Weekly"],
   ["contests", "Contests"],
 ]
   .map(
     ([v, l]) =>
       `<button data-library="${v}" class="${library === v ? "selected" : ""}">${l}</button>`,
   )
   .join(
     "",
   )}</div>${library === "contests" ? `<label class="period-label">Contest launch cadence<select id="contest-period">${["DAILY", "WEEKLY", "MONTHLY"].map((p) => `<option ${contestPeriod === p ? "selected" : ""}>${p}</option>`).join("")}</select></label>` : ""}<input id="library-search" aria-label="Search schedule catalog" placeholder="Find something to schedule…" value="${esc(librarySearch)}"><div id="library-items">${libraryHTML()}</div></aside>
 <section class="planner-board" aria-label="Schedule calendar"><div class="period-rail" data-drop="${monthly}" data-drop-period="MONTHLY"><div class="rail-label"><strong>${dateLabel(monthly, { month: "long", year: "numeric" })}</strong><span>Monthly contest launches</span></div><div class="rail-events">${scheduleItems(monthly, "MONTHLY") || '<span class="drop-hint">Drop a monthly contest here</span>'}</div></div><div class="period-rail" data-drop="${weekly}" data-drop-period="WEEKLY"><div class="rail-label"><strong>Week of ${dateLabel(weekly)}</strong><span>Weekly quests & contests</span></div><div class="rail-events">${scheduleItems(weekly, "WEEKLY") || '<span class="drop-hint">Drop a weekly quest or contest here</span>'}</div></div>
 <div class="schedule-grid ${calendarView}">${Array.from(
   { length: days },
   (_, i) => {
     const day = shift(start, i),
       events = state.schedule.filter(
         (e) => e.start === day && e.period === "DAILY",
       );
     return `<div class="schedule-day ${day === today ? "today" : ""} ${calendarView === "month" && day.slice(0, 7) !== calendarDate.slice(0, 7) ? "outside-month" : ""}" data-drop="${day}"><div class="schedule-day-head"><span>${dateLabel(day, { weekday: "short" })}</span><b>${parseDate(day).getUTCDate()}</b></div>${events.map(planEvent).join("")}${
       calendarView === "month"
         ? state.schedule
             .filter((e) => e.start === day && e.period !== "DAILY")
             .map(planEvent)
             .join("")
         : ""
     }<span class="drop-hint">${events.length ? "＋ Drop another" : "Drop daily content"}</span></div>`;
   },
 ).join(
   "",
 )}</div><div class="planner-legend"><span><i class="quest-dot"></i> Quest</span><span><i class="contest-dot"></i> Contest</span><span>UTC · Draft schedule</span></div><p class="section-note">Weekly items snap to Monday; monthly items to the first. This previews when content would open. Server activation and recurring publication are not connected.</p></section></div>`
    );
  }
  function render() {
    page = location.hash.slice(1) || "overview";
    if (!titles[page]) page = "overview";
    $("#crumb").textContent = titles[page].toUpperCase();
    document.querySelectorAll("nav a").forEach((a) => {
      const active = a.dataset.page === page;
      a.classList.toggle("active", active);
      if (active) a.setAttribute("aria-current", "page");
      else a.removeAttribute("aria-current");
    });
    $("#draft-count").textContent =
      Object.keys(state.edits).length + state.schedule.length;
    $("#export").disabled =
      !Object.keys(state.edits).length && !state.schedule.length;
    $("#main").innerHTML =
      (!storageOK
        ? '<p class="notice">Browser storage is unavailable. Export to keep draft changes.</p>'
        : "") +
      { overview, calendar, quests, contests, battlepath, drafts, sources }[
        page
      ]();
  }
  function openEditor(html) {
    lastFocus = document.activeElement;
    $("#editor-content").innerHTML = html;
    $("#editor").showModal();
    $("#editor").scrollTop = 0;
    const input = $("input, select", $("#editor-content"));
    if (input) input.focus();
  }
  function closeEditor() {
    $("#editor").close();
    if (lastFocus?.isConnected) lastFocus.focus();
  }
  const buttons = () =>
    '<p id="form-error" class="error" role="alert"></p><div class="dialog-actions"><button class="button ghost" type="button" data-action="cancel">Cancel</button><button class="button gold" type="submit">Save local draft</button></div>';
  function questEditor(id) {
    const q = clone(getQuest(id));
    openEditor(
      `<h2 id="editor-title">${esc(q.title)}</h2><p class="intro">${q.cadence.toLowerCase()} quest · Edits create a local draft of v1. Published assignments are unaffected.</p><form id="quest-form"><label>Quest name<input name="title" maxlength="90" value="${esc(q.title)}" required></label><div class="form-row"><label>Honey reward<input name="honey" type="number" min="0" max="10000" step="0.01" value="${q.reward.honey_centi / 100}" required></label><label>Nectar reward<input name="nectar" type="number" min="0" max="100000" step="0.001" value="${q.reward.nectar_milli / 1000}" required></label></div><fieldset><legend>Completion mix</legend>${q.objectives.map((o, i) => `<label class="objective-edit"><span>${esc(o.label)}</span><input name="target-${i}" type="number" min="1" max="1000" step="1" value="${o.target}" required></label>`).join("")}</fieldset><p class="form-note">Game families and eligibility filters stay attached to each objective. A single game may advance multiple quests.</p>${buttons()}</form>`,
    );
    $("#quest-form").onsubmit = (e) => {
      e.preventDefault();
      const f = new FormData(e.target);
      q.title = String(f.get("title")).trim();
      q.reward = {
        honey_centi: Math.round(Number(f.get("honey")) * 100),
        nectar_milli: Math.round(Number(f.get("nectar")) * 1000),
      };
      q.objectives.forEach((o, i) => (o.target = Number(f.get("target-" + i))));
      if (!q.title || !(q.reward.honey_centi + q.reward.nectar_milli)) {
        return ($("#form-error").textContent =
          "Add a name and at least one reward.");
      }
      edit("quest:" + id, "Quest", q);
    };
  }
  function packEditor(id) {
    const p = clone(getPack(id));
    openEditor(
      `<h2 id="editor-title">${esc(p.title)}</h2><p class="intro">${p.count} ${p.family === "GAUNTLET" ? "stages" : "maps"} · ${p.family === "GAUNTLET" ? "The stage order is shown from the current Gauntlet configuration." : "Choose an ordered map set for a future contest."}</p><form id="pack-form"><label>Draft name<input name="title" value="${esc(p.title)}" maxlength="90" required></label><div class="map-preview" id="map-detail">${mapSVG(p.maps[0])}</div><div class="map-key"><span><i style="background:#e6bf66"></i>P1</span><span><i style="background:#86bca8"></i>P2</span><span><i style="background:#71877a"></i>Neutral</span><span>Hive positions</span></div><fieldset><legend>${p.family === "GAUNTLET" ? "Stage sequence" : "Map order"}</legend>${p.maps.map((id, i) => `<label class="map-pick"><span>${i + 1}</span><select aria-label="Map ${i + 1}" name="map-${i}" ${p.family === "GAUNTLET" ? "disabled" : ""}>${C.maps.map((m) => `<option value="${esc(m.id)}" ${m.id === id ? "selected" : ""}>${esc(m.name)}</option>`).join("")}</select></label>`).join("")}</fieldset><p class="notice">Map packs must be validated against supported client content before publishing. These source maps are currently in the future library.</p>${buttons()}</form>`,
    );
    $("#pack-form").onchange = (e) => {
      if (e.target.name.startsWith("map-"))
        $("#map-detail").innerHTML = mapSVG(e.target.value);
    };
    $("#pack-form").onsubmit = (e) => {
      e.preventDefault();
      const f = new FormData(e.target);
      p.title = String(f.get("title")).trim();
      if (!p.title) return ($("#form-error").textContent = "Add a draft name.");
      if (p.family !== "GAUNTLET")
        p.maps = p.maps.map((m, i) => String(f.get("map-" + i)));
      edit("contest:" + id, "Contest", p);
    };
  }
  function seasonEditor() {
    const c = clone(passConfig());
    openEditor(
      `<h2 id="editor-title">Season settings</h2><p class="intro">A local draft of the source season. Rewards and player progression are unchanged.</p><form id="season-form"><label>Season name<input name="name" value="${esc(c.display_name)}" maxlength="90" required></label><div class="form-row"><label>Starts · UTC<input name="start" type="date" value="${iso(c.start_time_unix * 1000)}" required></label><label>Ends · UTC<input name="end" type="date" value="${iso(c.end_time_unix * 1000)}" required></label></div><p class="form-note">The current configuration contains ${c.total_levels} levels and three reward tracks.</p>${buttons()}</form>`,
    );
    $("#season-form").onsubmit = (e) => {
      e.preventDefault();
      const f = new FormData(e.target),
        start = parseDate(String(f.get("start"))) / 1000,
        end = parseDate(String(f.get("end"))) / 1000;
      if (end <= start)
        return ($("#form-error").textContent =
          "The end must come after the start.");
      c.display_name = String(f.get("name")).trim();
      if (!c.display_name)
        return ($("#form-error").textContent = "Add a season name.");
      c.start_time_unix = start;
      c.end_time_unix = end;
      edit("season", "Season", c);
    };
  }
  function levelEditor(n) {
    const l = clone(getLevel(n)),
      r = l.tracks[track];
    openEditor(
      `<h2 id="editor-title">Level ${n} · ${esc(track)}</h2><p class="intro">${esc(rewardName(r))}. Edit this reward’s quantity and the level’s progression requirement.</p><form id="level-form"><label>Nectar to advance<input name="xp" type="number" min="1" max="100000" step="1" value="${l.xp_required}" required></label>${r && r.reward_type !== "none" ? `<label>Reward quantity<input name="quantity" type="number" min="1" max="100000" step="1" value="${r.quantity ?? 1}" required></label>` : '<p class="notice">This track has no reward at this level. Adding new reward types belongs in the publishing editor.</p>'}<p class="form-note">Changing Nectar affects this level across all tracks. Reward identity stays unchanged.</p>${buttons()}</form>`,
    );
    $("#level-form").onsubmit = (e) => {
      e.preventDefault();
      const f = new FormData(e.target);
      l.xp_required = Number(f.get("xp"));
      if (f.has("quantity"))
        l.tracks[track].quantity = Number(f.get("quantity"));
      edit("level:" + n, "Battlepath", l);
    };
  }
  function validItem(item) {
    return (
      item &&
      ["quest", "contest"].includes(item.kind) &&
      ["DAILY", "WEEKLY", "MONTHLY"].includes(item.period) &&
      (item.kind === "quest"
        ? C.quests.some((q) => q.id === item.id && q.cadence === item.period)
        : packs.some(
            (p) =>
              p.id === item.id &&
              (p.family !== "GAUNTLET" || item.period === "WEEKLY"),
          ))
    );
  }
  function scheduleCheck(item, date, ignoreUid) {
    const normalized = startFor(date, item.period);
    if (
      !/^\d{4}-\d{2}-\d{2}$/.test(date) ||
      !Number.isFinite(parseDate(date).getTime())
    )
      return "Choose a valid date.";
    const others = state.schedule.filter(
      (e) =>
        e.uid !== ignoreUid &&
        e.start === normalized &&
        e.period === item.period,
    );
    if (others.some((e) => e.kind === item.kind && e.id === item.id))
      return "That item is already scheduled for this period.";
    if (
      item.kind === "quest" &&
      others.filter((e) => e.kind === "quest").length >=
        (item.period === "DAILY" ? 3 : 4)
    )
      return "This period already has its quest slots filled. Remove one before adding another.";
    return "";
  }
  function scheduleItem(item, date, uid) {
    if (!validItem(item)) return "Choose an item from the catalog.";
    const error = scheduleCheck(item, date, uid);
    if (error) return error;
    const entry = {
      kind: item.kind,
      id: item.id,
      period: item.period,
      start: startFor(date, item.period),
      uid: uid || crypto.randomUUID(),
      updated_at: new Date().toISOString(),
    };
    state.schedule = state.schedule.filter((e) => e.uid !== uid);
    state.schedule.push(entry);
    save();
    render();
    toast(`Scheduled for ${dateLabel(entry.start)} · local draft`);
    return "";
  }
  function planEditor(item, date = calendarDate, uid) {
    if (!validItem(item)) return;
    const name = eventName(item);
    openEditor(
      `<h2 id="editor-title">${esc(name)}</h2><p class="intro">${item.period.toLowerCase()} ${item.kind === "quest" ? "quest" : "contest launch"}. ${item.period === "WEEKLY" ? "Starts on Monday." : item.period === "MONTHLY" ? "Starts on the first of the month." : "Starts on the selected day."}</p><form id="plan-form"><label>Planning date · UTC<input name="date" type="date" value="${date}" required></label>${item.kind === "contest" ? `<p class="notice">${getPack(item.id).family === "TIME_PUZZLE" && item.period === "DAILY" ? "Daily public Time Puzzle periods are not supported by the server yet. This remains a planning placeholder." : "This schedules a local launch window. Map validation and server activation are still required."}</p>` : '<p class="form-note">Up to three daily or four weekly quests per period. This does not replace already assigned player quests.</p>'}${buttons()}</form><hr class="section-divider"><button class="link-button" ${item.kind === "quest" ? `data-quest="${esc(item.id)}"` : `data-pack="${esc(item.id)}"`}>Inspect ${item.kind === "quest" ? "objectives & rewards" : "map set"} →</button>${uid ? `<button class="button small ghost remove-plan" data-remove-event="${esc(uid)}">Remove from calendar</button>` : ""}`,
    );
    $("#plan-form").onsubmit = (e) => {
      e.preventDefault();
      const date = String(new FormData(e.target).get("date"));
      const error = scheduleItem(item, date, uid);
      if (error) $("#form-error").textContent = error;
      else closeEditor();
    };
  }
  function exportDrafts() {
    if (!state.schedule.length && !Object.keys(state.edits).length)
      return toast("Create a draft or schedule an item first.");
    const payload = {
      schema: "swarmfront.dev_dashboard.planning_bundle.v1",
      environment: "LOCAL_PREVIEW",
      publishable: false,
      exported_at: new Date().toISOString(),
      catalog_exported_at: C.generated_at,
      sources: C.sources,
      ...state,
      notes: [
        "This is a planning bundle, not a service publication request.",
        "Validate maps, contest scopes, quest availability and reward authority before server activation.",
      ],
    };
    const url = URL.createObjectURL(
      new Blob([JSON.stringify(payload, null, 2)], {
        type: "application/json",
      }),
    );
    const a = document.createElement("a");
    a.href = url;
    a.download = `swarmfront-content-drafts-${today}.json`;
    a.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
    toast("Draft bundle exported.");
  }
  function seedWeek() {
    const start = monday(calendarDate);
    let added = 0,
      skipped = 0;
    for (const a of currentAssignments(start)) {
      const item = { kind: "quest", id: a.id, period: a.period };
      if (!scheduleCheck(item, a.date)) {
        state.schedule.push({
          ...item,
          start: a.date,
          uid: crypto.randomUUID(),
          updated_at: new Date().toISOString(),
        });
        added++;
      } else skipped++;
    }
    save();
    render();
    toast(
      `${added} quests added${skipped ? `; ${skipped} existing or full slots kept` : ""}. Local draft only.`,
    );
  }
  function changeCalendar(delta) {
    if (calendarView === "month") {
      const d = parseDate(calendarDate);
      d.setUTCDate(1);
      d.setUTCMonth(d.getUTCMonth() + delta);
      calendarDate = iso(d);
    } else
      calendarDate = shift(
        calendarDate,
        delta * (calendarView === "week" ? 7 : 1),
      );
    render();
  }
  document.addEventListener("click", (e) => {
    const t = e.target.closest("button,a");
    if (!t) return;
    if (t.hasAttribute("data-weekly-link")) questFilter = "WEEKLY";
    if (t.dataset.quest) {
      if ($("#editor").open) closeEditor();
      return questEditor(t.dataset.quest);
    }
    if (t.dataset.pack) {
      if ($("#editor").open) closeEditor();
      return packEditor(t.dataset.pack);
    }
    if (t.dataset.level) return levelEditor(Number(t.dataset.level));
    if (t.dataset.filter) {
      questFilter = t.dataset.filter;
      return render();
    }
    if (t.dataset.track) {
      track = t.dataset.track;
      return render();
    }
    if (t.dataset.view) {
      calendarView = t.dataset.view;
      return render();
    }
    if (t.dataset.library) {
      library = t.dataset.library;
      librarySearch = "";
      return render();
    }
    if (t.dataset.plan) return planEditor(JSON.parse(t.dataset.plan));
    if (t.dataset.event) {
      const event = state.schedule.find((e) => e.uid === t.dataset.event);
      if (event) return planEditor(event, event.start, event.uid);
    }
    if (t.dataset.removeEvent) {
      state.schedule = state.schedule.filter(
        (e) => e.uid !== t.dataset.removeEvent,
      );
      save();
      if ($("#editor").open) closeEditor();
      render();
      return toast("Removed from the local schedule.");
    }
    if (t.dataset.discard) {
      delete state.edits[t.dataset.discard];
      save();
      render();
      return toast("Draft discarded. Repository version restored.");
    }
    if (t.dataset.editKey) {
      const k = t.dataset.editKey;
      if (k === "season") return seasonEditor();
      if (k.startsWith("quest:")) return questEditor(k.slice(6));
      if (k.startsWith("contest:")) return packEditor(k.slice(8));
      if (k.startsWith("level:")) return levelEditor(Number(k.slice(6)));
    }
    const a = t.dataset.action;
    if (a === "week-prev") weekOffset--;
    if (a === "week-next") weekOffset++;
    if (a === "levels-prev") levelPage = Math.max(0, levelPage - 1);
    if (a === "levels-next") levelPage = Math.min(5, levelPage + 1);
    if (["week-prev", "week-next", "levels-prev", "levels-next"].includes(a))
      return render();
    if (a === "season") return seasonEditor();
    if (a === "cancel") return closeEditor();
    if (a === "export") return exportDrafts();
    if (a === "seed-week") return seedWeek();
    if (a === "calendar-prev") return changeCalendar(-1);
    if (a === "calendar-next") return changeCalendar(1);
    if (a === "calendar-today") {
      calendarDate = today;
      render();
    }
  });
  document.addEventListener("input", (e) => {
    if (e.target.id === "quest-search") {
      search = e.target.value;
      $("#quest-grid").innerHTML = questCards();
    }
    if (e.target.id === "library-search") {
      librarySearch = e.target.value;
      $("#library-items").innerHTML = libraryHTML();
    }
  });
  document.addEventListener("change", (e) => {
    if (e.target.id === "calendar-date" && e.target.value) {
      calendarDate = e.target.value;
      render();
    }
    if (e.target.id === "contest-period") {
      contestPeriod = e.target.value;
      $("#library-items").innerHTML = libraryHTML();
    }
  });
  document.addEventListener("dragstart", (e) => {
    const source = e.target.closest("[data-drag],[data-move]");
    if (!source) return;
    dragged = source.dataset.drag
      ? JSON.parse(source.dataset.drag)
      : { ...state.schedule.find((x) => x.uid === source.dataset.move) };
    e.dataTransfer.setData(
      "application/x-swarmfront-plan",
      JSON.stringify(dragged),
    );
    e.dataTransfer.effectAllowed = dragged.uid ? "move" : "copy";
    source.classList.add("dragging");
  });
  document.addEventListener("dragend", () => {
    dragged = null;
    document
      .querySelectorAll(".dragging,.drop-active")
      .forEach((n) => n.classList.remove("dragging", "drop-active"));
  });
  document.addEventListener("dragover", (e) => {
    const target = e.target.closest("[data-drop]");
    if (!target || !dragged) return;
    e.preventDefault();
    e.dataTransfer.dropEffect = dragged.uid ? "move" : "copy";
    target.classList.add("drop-active");
  });
  document.addEventListener("dragleave", (e) => {
    const target = e.target.closest("[data-drop]");
    if (target && !target.contains(e.relatedTarget))
      target.classList.remove("drop-active");
  });
  document.addEventListener("drop", (e) => {
    const target = e.target.closest("[data-drop]");
    if (!target) return;
    e.preventDefault();
    target.classList.remove("drop-active");
    let item;
    try {
      item = JSON.parse(
        e.dataTransfer.getData("application/x-swarmfront-plan"),
      );
    } catch {
      return;
    }
    if (!validItem(item)) return toast("Choose an item from the catalog.");
    if (target.dataset.dropPeriod && item.period !== target.dataset.dropPeriod)
      return toast(
        `That lane is for ${target.dataset.dropPeriod.toLowerCase()} items.`,
      );
    const error = scheduleItem(item, target.dataset.drop, item.uid);
    if (error) toast(error);
    dragged = null;
  });
  $("#close-editor").onclick = closeEditor;
  $("#export").onclick = exportDrafts;
  $("#editor").addEventListener("click", (e) => {
    if (e.target === $("#editor") && e.offsetX < 0) closeEditor();
  });
  window.addEventListener("hashchange", render);
  render();
})();
