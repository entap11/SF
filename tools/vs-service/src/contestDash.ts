import type { Request, Response } from "express";
import { existsSync } from "node:fs";
import { mkdir, readFile, readdir, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { guardEconomyMutation } from "./economyGuard.js";

type JsonRecord = Record<string, unknown>;

type MapEntry = {
  id: string;
  name: string;
  family: string;
  mode: string;
  path: string;
};

type PayoutRow = {
  placement: number;
  payout_bps: number;
};

type ContestConfig = {
  id: string;
  name: string;
  scope: string;
  family: string;
  schedule_kind: string;
  status: string;
  published: boolean;
  currency: string;
  price_usd: number;
  start_unix: number;
  end_unix: number;
  map_count: number;
  map_paths: string[];
  prize_pool_cents: number;
  house_rake_bps: number;
  min_players: number;
  max_players: number;
  payout_schedule: PayoutRow[];
};

type DashConfig = {
  schema: string;
  updated_unix: number;
  contests: ContestConfig[];
};

const SCHEMA = "swarmfront.contest_dash.v1";
const __filename = fileURLToPath(import.meta.url);
const serviceRoot = path.resolve(path.dirname(__filename), "..");
const projectRoot = path.resolve(serviceRoot, "../..");
const defaultConfigPath = path.join(serviceRoot, "var", "contest-dash-config.json");
const configPath = process.env.VS_CONTEST_DASH_PATH?.trim() || defaultConfigPath;

const SCOPES = ["WEEKLY", "MONTHLY", "SEASONAL"];
const FAMILIES = ["STAGE_RACE", "RACE", "GAUNTLET", "MISS_N_OUT"];
const SCHEDULE_KINDS = ["SCHEDULED", "SIT_AND_GO"];
const STATUSES = ["OPEN", "CLOSED", "PAYOUT_PENDING", "PAYOUT_APPROVED", "VOID"];
const MAP_COUNTS = [3, 5];
const DEFAULT_PAYOUTS: PayoutRow[] = [
  { placement: 1, payout_bps: 4000 },
  { placement: 2, payout_bps: 2500 },
  { placement: 3, payout_bps: 1500 },
  { placement: 4, payout_bps: 1000 },
  { placement: 5, payout_bps: 1000 }
];

function nowUnix(): number {
  return Math.floor(Date.now() / 1000);
}

function asRecord(value: unknown): JsonRecord {
  return value != null && typeof value === "object" && !Array.isArray(value) ? value as JsonRecord : {};
}

function cleanString(value: unknown, fallback = ""): string {
  const out = String(value ?? "").trim();
  return out || fallback;
}

function cleanUpper(value: unknown, allowed: string[], fallback: string): string {
  const out = cleanString(value, fallback).toUpperCase().replaceAll("-", "_").replaceAll(" ", "_");
  return allowed.includes(out) ? out : fallback;
}

function cleanInt(value: unknown, fallback = 0): number {
  const parsed = Number.parseInt(String(value ?? ""), 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function cleanBool(value: unknown): boolean {
  if (typeof value === "boolean") {
    return value;
  }
  const normalized = cleanString(value).toLowerCase();
  return ["1", "true", "yes", "on"].includes(normalized);
}

function centsFromDollars(value: unknown): number {
  const numeric = Number(value);
  if (!Number.isFinite(numeric)) {
    return 0;
  }
  return Math.max(0, Math.round(numeric * 100));
}

function htmlEscape(value: unknown): string {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function defaultContest(mapEntries: MapEntry[]): ContestConfig {
  const maps = mapEntries.slice(0, 5).map((entry) => entry.path);
  const timeSlice = new Date().toISOString().slice(0, 10);
  return {
    id: `WEEKLY_USD_5_${timeSlice}_RACE`,
    name: "Weekly $5 Race",
    scope: "WEEKLY",
    family: "RACE",
    schedule_kind: "SCHEDULED",
    status: "OPEN",
    published: false,
    currency: "USD",
    price_usd: 5,
    start_unix: 0,
    end_unix: 0,
    map_count: 5,
    map_paths: maps,
    prize_pool_cents: 0,
    house_rake_bps: 1000,
    min_players: 5,
    max_players: 10,
    payout_schedule: DEFAULT_PAYOUTS.map((row) => ({ ...row }))
  };
}

async function readJsonFile(filePath: string): Promise<unknown> {
  const text = await readFile(filePath, "utf8");
  return JSON.parse(text) as unknown;
}

async function listJsonFiles(dir: string): Promise<string[]> {
  const out: string[] = [];
  if (!existsSync(dir)) {
    return out;
  }
  const entries = await readdir(dir, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      out.push(...await listJsonFiles(fullPath));
    } else if (entry.isFile() && entry.name.endsWith(".json")) {
      out.push(fullPath);
    }
  }
  return out;
}

export async function listContestDashMaps(): Promise<MapEntry[]> {
  const mapRoot = path.join(projectRoot, "maps");
  const files = await listJsonFiles(mapRoot);
  const maps: MapEntry[] = [];
  for (const filePath of files) {
    const relPath = path.relative(projectRoot, filePath).split(path.sep).join("/");
    if (relPath.includes("__3p")) {
      continue;
    }
    try {
      const raw = asRecord(await readJsonFile(filePath));
      const id = cleanString(raw.id, path.basename(filePath, ".json"));
      const mode = cleanString(raw.mode);
      const buckets = Array.isArray(raw.player_buckets) ? raw.player_buckets.map((entry) => cleanString(entry).toUpperCase()) : [];
      if (mode.toLowerCase() === "3p" || buckets.includes("3P")) {
        continue;
      }
      maps.push({
        id,
        name: cleanString(raw.name, id.replace(/^MAP_/, "").replaceAll("_", " ")),
        family: cleanString(raw.display_family, cleanString(raw.family, "Map")),
        mode,
        path: `res://${relPath}`
      });
    } catch {
      continue;
    }
  }
  maps.sort((a, b) => `${a.family}|${a.name}|${a.id}`.localeCompare(`${b.family}|${b.name}|${b.id}`));
  return maps;
}

function normalizePayoutSchedule(value: unknown, isMoney: boolean): PayoutRow[] {
  const rawRows = Array.isArray(value) ? value : DEFAULT_PAYOUTS;
  const rows: PayoutRow[] = [];
  for (let i = 0; i < rawRows.length; i += 1) {
    const raw = asRecord(rawRows[i]);
    const placement = Math.max(1, cleanInt(raw.placement, i + 1));
    const payoutBps = Math.max(0, Math.min(10000, cleanInt(raw.payout_bps, 0)));
    if (payoutBps <= 0 && isMoney) {
      continue;
    }
    rows.push({ placement, payout_bps: payoutBps });
  }
  rows.sort((a, b) => a.placement - b.placement);
  return rows.length > 0 ? rows : [{ placement: 1, payout_bps: isMoney ? 10000 : 0 }];
}

function normalizeContest(value: unknown, maps: MapEntry[]): ContestConfig {
  const raw = asRecord(value);
  const scope = cleanUpper(raw.scope, SCOPES, "WEEKLY");
  const family = cleanUpper(raw.family ?? raw.contest_family, FAMILIES, "RACE");
  const scheduleKind = cleanUpper(raw.schedule_kind, SCHEDULE_KINDS, "SCHEDULED");
  const priceUsd = Math.max(0, cleanInt(raw.price_usd ?? raw.price, 5));
  const isMoney = priceUsd > 0;
  const mapCount = MAP_COUNTS.includes(cleanInt(raw.map_count, 5)) ? cleanInt(raw.map_count, 5) : 5;
  const allowedMaps = new Set(maps.map((entry) => entry.path));
  const rawMapPaths = Array.isArray(raw.map_paths) ? raw.map_paths : [];
  const selected = rawMapPaths
    .map((entry) => cleanString(entry))
    .filter((entry) => entry && allowedMaps.has(entry))
    .slice(0, mapCount);
  const fallbackMaps = maps.slice(0, mapCount).map((entry) => entry.path);
  while (selected.length < mapCount && fallbackMaps.length > 0) {
    selected.push(fallbackMaps[selected.length % fallbackMaps.length]);
  }
  const payoutSchedule = normalizePayoutSchedule(raw.payout_schedule ?? raw.payouts, isMoney);
  const fallbackId = `${scope}_${isMoney ? "USD" : "FREE"}_${priceUsd}_${family}`;
  return {
    id: cleanString(raw.id, fallbackId).toUpperCase(),
    name: cleanString(raw.name, `${scope} ${family}`),
    scope,
    family,
    schedule_kind: scheduleKind,
    status: cleanUpper(raw.status, STATUSES, "OPEN"),
    published: cleanBool(raw.published),
    currency: isMoney ? "USD" : "FREE",
    price_usd: priceUsd,
    start_unix: Math.max(0, cleanInt(raw.start_unix ?? raw.start_ts, 0)),
    end_unix: Math.max(0, cleanInt(raw.end_unix ?? raw.end_ts, 0)),
    map_count: mapCount,
    map_paths: selected,
    prize_pool_cents: Math.max(0, cleanInt(raw.prize_pool_cents, centsFromDollars(raw.prize_pool_usd))),
    house_rake_bps: isMoney ? Math.max(0, Math.min(10000, cleanInt(raw.house_rake_bps, 1000))) : 0,
    min_players: Math.max(0, cleanInt(raw.min_players, family === "GAUNTLET" ? 10 : 5)),
    max_players: Math.max(0, cleanInt(raw.max_players, family === "GAUNTLET" ? 10 : 10)),
    payout_schedule: payoutSchedule
  };
}

function validateContest(contest: ContestConfig): string[] {
  const errors: string[] = [];
  if (!contest.id) {
    errors.push("missing_contest_id");
  }
  if (contest.map_paths.length < contest.map_count) {
    errors.push("not_enough_maps");
  }
  if (contest.price_usd > 0) {
    const payoutTotal = contest.payout_schedule.reduce((sum, row) => sum + row.payout_bps, 0);
    if (payoutTotal !== 10000) {
      errors.push("money_payout_bps_must_total_10000");
    }
  }
  if (contest.end_unix > 0 && contest.start_unix > 0 && contest.end_unix <= contest.start_unix) {
    errors.push("end_must_be_after_start");
  }
  return errors;
}

async function loadConfig(maps: MapEntry[]): Promise<DashConfig> {
  let contests = [defaultContest(maps)];
  if (existsSync(configPath)) {
    try {
      const raw = asRecord(await readJsonFile(configPath));
      const rawContests = Array.isArray(raw.contests) ? raw.contests : [];
      if (rawContests.length > 0) {
        contests = rawContests.map((entry) => normalizeContest(entry, maps));
      }
    } catch {
      contests = [defaultContest(maps)];
    }
  }
  return {
    schema: SCHEMA,
    updated_unix: nowUnix(),
    contests
  };
}

async function saveConfig(config: DashConfig): Promise<void> {
  await mkdir(path.dirname(configPath), { recursive: true });
  await writeFile(configPath, `${JSON.stringify(config, null, 2)}\n`, "utf8");
}

export async function getContestDashState(): Promise<JsonRecord> {
  const maps = await listContestDashMaps();
  const config = await loadConfig(maps);
  return {
    ok: true,
    config_path: configPath,
    config,
    maps,
    presets: {
      scopes: SCOPES,
      families: FAMILIES,
      schedule_kinds: SCHEDULE_KINDS,
      statuses: STATUSES,
      map_counts: MAP_COUNTS
    }
  };
}

export async function saveContestDashContest(body: unknown): Promise<JsonRecord> {
  const blocked = guardEconomyMutation();
  if (blocked) return blocked;
  const maps = await listContestDashMaps();
  const config = await loadConfig(maps);
  const contest = normalizeContest(asRecord(body).contest ?? body, maps);
  const errors = validateContest(contest);
  if (errors.length > 0) {
    return { ok: false, err: "invalid_contest_config", errors, contest };
  }
  const nextContests = config.contests.filter((entry) => entry.id !== contest.id);
  nextContests.push(contest);
  nextContests.sort((a, b) => a.id.localeCompare(b.id));
  const nextConfig: DashConfig = {
    schema: SCHEMA,
    updated_unix: nowUnix(),
    contests: nextContests
  };
  await saveConfig(nextConfig);
  return { ok: true, contest, config: nextConfig };
}

export async function deleteContestDashContest(body: unknown): Promise<JsonRecord> {
  const blocked = guardEconomyMutation();
  if (blocked) return blocked;
  const id = cleanString(asRecord(body).id).toUpperCase();
  if (!id) {
    return { ok: false, err: "missing_contest_id" };
  }
  const maps = await listContestDashMaps();
  const config = await loadConfig(maps);
  const nextConfig: DashConfig = {
    schema: SCHEMA,
    updated_unix: nowUnix(),
    contests: config.contests.filter((entry) => entry.id !== id)
  };
  await saveConfig(nextConfig);
  return { ok: true, deleted_id: id, config: nextConfig };
}

export function renderContestDashHtml(): string {
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Swarmfront Contest Dash</title>
  <style>
    :root { color-scheme: dark; --bg:#11140f; --panel:#181d15; --line:#303a2b; --text:#eef5e8; --muted:#aab6a0; --accent:#f2c94c; --bad:#ff6b6b; --good:#56d084; }
    * { box-sizing: border-box; }
    body { margin:0; font:14px/1.35 system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; background:var(--bg); color:var(--text); }
    header { display:flex; align-items:center; justify-content:space-between; gap:16px; padding:18px 22px; border-bottom:1px solid var(--line); background:#151a12; position:sticky; top:0; z-index:2; }
    h1 { margin:0; font-size:20px; letter-spacing:0; }
    main { display:grid; grid-template-columns:minmax(240px, 340px) 1fr; min-height:calc(100vh - 65px); }
    aside { border-right:1px solid var(--line); padding:16px; background:#131810; overflow:auto; }
    section { padding:18px; overflow:auto; }
    button, input, select { font:inherit; }
    button { border:1px solid var(--line); background:#232b1f; color:var(--text); padding:9px 12px; border-radius:6px; cursor:pointer; }
    button:hover { border-color:var(--accent); }
    button.primary { background:#3a3317; border-color:#7d6821; color:#fff7cf; }
    button.danger { background:#351d1d; border-color:#6c3131; color:#ffdede; }
    input, select { width:100%; border:1px solid var(--line); border-radius:6px; padding:9px 10px; background:#0d110b; color:var(--text); }
    label { display:block; color:var(--muted); font-size:12px; margin:0 0 5px; }
    .grid { display:grid; grid-template-columns:repeat(4, minmax(140px, 1fr)); gap:14px; }
    .wide { grid-column:span 2; }
    .full { grid-column:1 / -1; }
    .panel { border:1px solid var(--line); border-radius:8px; padding:14px; background:var(--panel); margin-bottom:14px; }
    .panel h2 { margin:0 0 12px; font-size:15px; }
    .contest-list { display:flex; flex-direction:column; gap:8px; }
    .contest-list button { text-align:left; }
    .contest-list button.active { border-color:var(--accent); background:#2c2918; }
    .maps { display:grid; grid-template-columns:repeat(2, minmax(220px, 1fr)); gap:10px; }
    .payout-row { display:grid; grid-template-columns:90px 1fr 80px; gap:10px; align-items:end; margin-bottom:8px; }
    .muted { color:var(--muted); }
    .status { min-height:20px; color:var(--muted); }
    .status.good { color:var(--good); }
    .status.bad { color:var(--bad); }
    pre { white-space:pre-wrap; overflow:auto; max-height:260px; background:#0d110b; border:1px solid var(--line); padding:12px; border-radius:6px; }
    @media (max-width: 900px) { main { grid-template-columns:1fr; } aside { border-right:0; border-bottom:1px solid var(--line); } .grid { grid-template-columns:1fr; } .wide { grid-column:auto; } .maps { grid-template-columns:1fr; } }
  </style>
</head>
<body>
  <header>
    <h1>Swarmfront Contest Dash</h1>
    <div>
      <button id="reload">Reload</button>
      <button id="newContest">New Contest</button>
      <button id="save" class="primary">Save</button>
    </div>
  </header>
  <main>
    <aside>
      <div class="panel">
        <h2>Contests</h2>
        <div id="contestList" class="contest-list"></div>
      </div>
      <div class="panel">
        <h2>Service</h2>
        <div class="muted">API base: <code>/v1</code></div>
        <div class="muted">Config: <span id="configPath"></span></div>
      </div>
    </aside>
    <section>
      <div class="panel">
        <h2>Contest Setup</h2>
        <div class="grid">
          <div class="wide"><label>ID</label><input id="id" /></div>
          <div class="wide"><label>Name</label><input id="name" /></div>
          <div><label>Scope</label><select id="scope"></select></div>
          <div><label>Family</label><select id="family"></select></div>
          <div><label>Schedule</label><select id="schedule_kind"></select></div>
          <div><label>Status</label><select id="statusField"></select></div>
          <div><label>Published</label><select id="published"><option value="false">No</option><option value="true">Yes</option></select></div>
          <div><label>Price USD</label><input id="price_usd" type="number" min="0" step="1" /></div>
          <div><label>Start Unix</label><input id="start_unix" type="number" min="0" step="1" /></div>
          <div><label>End Unix</label><input id="end_unix" type="number" min="0" step="1" /></div>
          <div><label>Map Count</label><select id="map_count"></select></div>
          <div><label>Prize Pool USD</label><input id="prize_pool_usd" type="number" min="0" step="1" /></div>
          <div><label>House Rake BPS</label><input id="house_rake_bps" type="number" min="0" max="10000" step="100" /></div>
          <div><label>Min Players</label><input id="min_players" type="number" min="0" step="1" /></div>
          <div><label>Max Players</label><input id="max_players" type="number" min="0" step="1" /></div>
        </div>
      </div>
      <div class="panel">
        <h2>Maps</h2>
        <div id="maps" class="maps"></div>
      </div>
      <div class="panel">
        <h2>Payouts</h2>
        <div id="payoutRows"></div>
        <button id="addPayout">Add Payout Row</button>
        <div id="payoutTotal" class="status"></div>
      </div>
      <div class="panel">
        <h2>Payload</h2>
        <div id="status" class="status"></div>
        <pre id="payload"></pre>
        <button id="delete" class="danger">Delete Selected Contest</button>
      </div>
    </section>
  </main>
  <script>
    const $ = (id) => document.getElementById(id);
    let state = null;
    let selectedId = "";

    function option(select, value, label = value) {
      const node = document.createElement("option");
      node.value = value;
      node.textContent = label;
      select.appendChild(node);
    }

    function numberValue(id) {
      const n = Number($(id).value);
      return Number.isFinite(n) ? Math.trunc(n) : 0;
    }

    function currentContest() {
      const rows = [...document.querySelectorAll(".payout-row")].map((row, index) => ({
        placement: Number(row.querySelector(".placement").value || index + 1),
        payout_bps: Number(row.querySelector(".payout").value || 0)
      }));
      const mapPaths = [...document.querySelectorAll(".map-select")].map((select) => select.value).filter(Boolean);
      return {
        id: $("id").value.trim().toUpperCase(),
        name: $("name").value.trim(),
        scope: $("scope").value,
        family: $("family").value,
        schedule_kind: $("schedule_kind").value,
        status: $("statusField").value,
        published: $("published").value === "true",
        price_usd: numberValue("price_usd"),
        start_unix: numberValue("start_unix"),
        end_unix: numberValue("end_unix"),
        map_count: numberValue("map_count"),
        map_paths: mapPaths,
        prize_pool_cents: Math.max(0, Math.round(Number($("prize_pool_usd").value || 0) * 100)),
        house_rake_bps: numberValue("house_rake_bps"),
        min_players: numberValue("min_players"),
        max_players: numberValue("max_players"),
        payout_schedule: rows
      };
    }

    function renderSelectOptions() {
      for (const id of ["scope", "family", "schedule_kind", "statusField", "map_count"]) $(id).innerHTML = "";
      state.presets.scopes.forEach((value) => option($("scope"), value));
      state.presets.families.forEach((value) => option($("family"), value));
      state.presets.schedule_kinds.forEach((value) => option($("schedule_kind"), value));
      state.presets.statuses.forEach((value) => option($("statusField"), value));
      state.presets.map_counts.forEach((value) => option($("map_count"), value, String(value) + " maps"));
    }

    function renderContestList() {
      const list = $("contestList");
      list.innerHTML = "";
      state.config.contests.forEach((contest) => {
        const button = document.createElement("button");
        button.className = contest.id === selectedId ? "active" : "";
        button.textContent = String(contest.id) + (contest.published ? " (published)" : "");
        button.onclick = () => selectContest(contest.id);
        list.appendChild(button);
      });
    }

    function renderMaps(contest) {
      const root = $("maps");
      root.innerHTML = "";
      const count = Number($("map_count").value || contest.map_count || 5);
      for (let i = 0; i < count; i += 1) {
        const wrap = document.createElement("div");
        const label = document.createElement("label");
        label.textContent = "Map " + String(i + 1);
        const select = document.createElement("select");
        select.className = "map-select";
        state.maps.forEach((map) => option(select, map.path, String(map.name) + " - " + String(map.family) + " - " + String(map.mode || "map")));
        select.value = contest.map_paths?.[i] || state.maps[i % Math.max(1, state.maps.length)]?.path || "";
        select.onchange = renderPayload;
        wrap.append(label, select);
        root.appendChild(wrap);
      }
    }

    function renderPayoutRows(contest) {
      const root = $("payoutRows");
      root.innerHTML = "";
      const rows = contest.payout_schedule?.length ? contest.payout_schedule : [{ placement: 1, payout_bps: 10000 }];
      rows.forEach((payout, index) => addPayoutRow(payout.placement || index + 1, payout.payout_bps || 0));
      renderPayoutTotal();
    }

    function addPayoutRow(placement = 1, payoutBps = 0) {
      const row = document.createElement("div");
      row.className = "payout-row";
      row.innerHTML = \`
        <div><label>Place</label><input class="placement" type="number" min="1" step="1" value="\${placement}" /></div>
        <div><label>Payout BPS</label><input class="payout" type="number" min="0" max="10000" step="100" value="\${payoutBps}" /></div>
        <button type="button">Remove</button>
      \`;
      row.querySelector("button").onclick = () => { row.remove(); renderPayoutTotal(); renderPayload(); };
      row.querySelectorAll("input").forEach((input) => input.addEventListener("input", () => { renderPayoutTotal(); renderPayload(); }));
      $("payoutRows").appendChild(row);
    }

    function renderPayoutTotal() {
      const total = [...document.querySelectorAll(".payout")].reduce((sum, input) => sum + Number(input.value || 0), 0);
      $("payoutTotal").textContent = "Payout total: " + String(total) + " bps (" + (total / 100).toFixed(1) + "%)";
      $("payoutTotal").className = total === 10000 ? "status good" : "status bad";
    }

    function renderPayload() {
      $("payload").textContent = JSON.stringify(currentContest(), null, 2);
    }

    function selectContest(id) {
      selectedId = id;
      const contest = state.config.contests.find((entry) => entry.id === id) || state.config.contests[0];
      $("id").value = contest.id || "";
      $("name").value = contest.name || "";
      $("scope").value = contest.scope || "WEEKLY";
      $("family").value = contest.family || "RACE";
      $("schedule_kind").value = contest.schedule_kind || "SCHEDULED";
      $("statusField").value = contest.status || "OPEN";
      $("published").value = String(Boolean(contest.published));
      $("price_usd").value = contest.price_usd ?? 5;
      $("start_unix").value = contest.start_unix ?? 0;
      $("end_unix").value = contest.end_unix ?? 0;
      $("map_count").value = contest.map_count ?? 5;
      $("prize_pool_usd").value = Number(contest.prize_pool_cents || 0) / 100;
      $("house_rake_bps").value = contest.house_rake_bps ?? 1000;
      $("min_players").value = contest.min_players ?? 5;
      $("max_players").value = contest.max_players ?? 10;
      renderMaps(contest);
      renderPayoutRows(contest);
      renderContestList();
      renderPayload();
    }

    async function loadState() {
      const response = await fetch("/v1/contest_dash/config");
      state = await response.json();
      $("configPath").textContent = state.config_path || "";
      renderSelectOptions();
      selectedId = state.config.contests[0]?.id || "";
      selectContest(selectedId);
      $("status").textContent = "Loaded " + String(state.config.contests.length) + " contests and " + String(state.maps.length) + " maps.";
      $("status").className = "status good";
    }

    async function saveContest() {
      const contest = currentContest();
      const response = await fetch("/v1/contest_dash/config", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ contest })
      });
      const result = await response.json();
      if (!result.ok) {
        $("status").textContent = "Save failed: " + String(result.err || "unknown") + " " + (result.errors || []).join(", ");
        $("status").className = "status bad";
        return;
      }
      $("status").textContent = "Saved " + String(result.contest.id) + ".";
      $("status").className = "status good";
      await loadState();
      selectContest(result.contest.id);
    }

    async function deleteContest() {
      const id = $("id").value.trim().toUpperCase();
      if (!id || !window.confirm("Delete " + id + "?")) return;
      const response = await fetch("/v1/contest_dash/delete", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ id })
      });
      const result = await response.json();
      $("status").textContent = result.ok ? "Deleted " + id + "." : "Delete failed: " + String(result.err || "unknown");
      $("status").className = result.ok ? "status good" : "status bad";
      await loadState();
    }

    function newContest() {
      const base = state.config.contests[0] || {};
      selectContest(base.id);
      $("id").value = "WEEKLY_USD_5_" + new Date().toISOString().slice(0, 10) + "_RACE";
      $("name").value = "Weekly $5 Race";
      $("published").value = "false";
      renderPayload();
    }

    ["id","name","scope","family","schedule_kind","statusField","published","price_usd","start_unix","end_unix","map_count","prize_pool_usd","house_rake_bps","min_players","max_players"].forEach((id) => {
      window.addEventListener("load", () => $(id).addEventListener("input", () => {
        if (id === "map_count") renderMaps(currentContest());
        renderPayload();
      }));
    });
    $("reload").onclick = loadState;
    $("save").onclick = saveContest;
    $("delete").onclick = deleteContest;
    $("newContest").onclick = newContest;
    $("addPayout").onclick = () => { addPayoutRow(document.querySelectorAll(".payout-row").length + 1, 0); renderPayoutTotal(); renderPayload(); };
    loadState().catch((error) => {
      $("status").textContent = String(error);
      $("status").className = "status bad";
    });
  </script>
</body>
</html>`;
}

export async function handleContestDashState(_req: Request, res: Response): Promise<void> {
  res.json(await getContestDashState());
}

export async function handleContestDashSave(req: Request, res: Response): Promise<void> {
  const result = await saveContestDashContest(req.body);
  res.status(result.ok === true ? 200 : result.err === "economy_disabled" ? 503 : 400).json(result);
}

export async function handleContestDashDelete(req: Request, res: Response): Promise<void> {
  const result = await deleteContestDashContest(req.body);
  res.status(result.ok === true ? 200 : result.err === "economy_disabled" ? 503 : 400).json(result);
}

export function handleContestDashPage(_req: Request, res: Response): void {
  res.type("html").send(renderContestDashHtml());
}

export function contestDashInfo(): JsonRecord {
  return {
    path: "/dash",
    config_path: htmlEscape(configPath),
    api: {
      get_config: "/v1/contest_dash/config",
      save_config: "/v1/contest_dash/config",
      delete_config: "/v1/contest_dash/delete"
    }
  };
}
