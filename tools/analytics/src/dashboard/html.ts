export interface DateRange {
  start: string;
  end: string;
}

function esc(value: unknown): string {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

export function fmtInt(value: number | string | null | undefined): string {
  if (value == null) {
    return "0";
  }
  const n = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(n)) {
    return "0";
  }
  return Math.round(n).toLocaleString("en-US");
}

export function fmtMoneyCents(value: number | string | null | undefined): string {
  if (value == null) {
    return "$0.00";
  }
  const n = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(n)) {
    return "$0.00";
  }
  return `$${(n / 100).toFixed(2)}`;
}

export function fmtPct(value: number | string | null | undefined, decimals = 2): string {
  if (value == null) {
    return "0%";
  }
  const n = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(n)) {
    return "0%";
  }
  return `${(n * 100).toFixed(decimals)}%`;
}

export function fmtPctRaw(value: number | string | null | undefined, decimals = 2): string {
  if (value == null) {
    return "0%";
  }
  const n = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(n)) {
    return "0%";
  }
  return `${n.toFixed(decimals)}%`;
}

export function card(label: string, value: string): string {
  return `<div class=\"card\"><div class=\"label\">${esc(label)}</div><div class=\"value\">${esc(value)}</div></div>`;
}

export function table(headers: string[], rows: string[][]): string {
  const headHtml = headers.map((h) => `<th>${esc(h)}</th>`).join("");
  const bodyHtml = rows
    .map((r) => `<tr>${r.map((c) => `<td>${esc(c)}</td>`).join("")}</tr>`)
    .join("");
  return `<table><thead><tr>${headHtml}</tr></thead><tbody>${bodyHtml}</tbody></table>`;
}

export function layout(title: string, activePath: string, range: DateRange, body: string): string {
  const links = [
    { href: "/dashboard", label: "Overview" },
    { href: "/dashboard/retention", label: "Retention" },
    { href: "/dashboard/gameplay", label: "Gameplay" },
    { href: "/dashboard/stability", label: "Stability" }
  ];
  const nav = links
    .map((link) => {
      const active = activePath === link.href ? "active" : "";
      const href = `${link.href}?start=${encodeURIComponent(range.start)}&end=${encodeURIComponent(range.end)}`;
      return `<a class=\"${active}\" href=\"${href}\">${esc(link.label)}</a>`;
    })
    .join(" ");

  return `<!doctype html>
<html lang=\"en\">
<head>
  <meta charset=\"utf-8\" />
  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
  <title>${esc(title)}</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, Segoe UI, Roboto, sans-serif; margin: 0; background: #0f1420; color: #eef3ff; }
    header { padding: 16px 20px; border-bottom: 1px solid #2a3248; background: #151d2d; position: sticky; top: 0; }
    h1 { margin: 0 0 10px 0; font-size: 20px; }
    nav a { color: #9fb3d6; margin-right: 12px; text-decoration: none; font-weight: 600; }
    nav a.active { color: #fff; }
    form { margin-top: 10px; display: flex; gap: 8px; align-items: center; }
    input, button { border-radius: 6px; border: 1px solid #32415f; background: #111a2b; color: #eef3ff; padding: 6px 10px; }
    button { cursor: pointer; background: #204b8a; border-color: #3568b5; }
    main { padding: 20px; }
    .cards { display: grid; gap: 10px; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); margin-bottom: 18px; }
    .card { border: 1px solid #2a3248; border-radius: 10px; background: #151d2d; padding: 10px 12px; }
    .card .label { font-size: 12px; color: #9fb3d6; }
    .card .value { font-size: 22px; font-weight: 700; margin-top: 6px; }
    section { margin-top: 18px; }
    section h2 { margin: 0 0 8px 0; font-size: 16px; }
    table { width: 100%; border-collapse: collapse; border: 1px solid #2a3248; border-radius: 8px; overflow: hidden; }
    th, td { padding: 8px 10px; border-bottom: 1px solid #2a3248; text-align: left; font-size: 13px; }
    th { background: #1d2740; color: #cad7ef; }
    tr:last-child td { border-bottom: none; }
    .muted { color: #9fb3d6; font-size: 12px; }
  </style>
</head>
<body>
  <header>
    <h1>Swarmfront Analytics</h1>
    <nav>${nav}</nav>
    <form method=\"get\" action=\"${esc(activePath)}\">
      <label>Start <input type=\"date\" name=\"start\" value=\"${esc(range.start)}\" /></label>
      <label>End <input type=\"date\" name=\"end\" value=\"${esc(range.end)}\" /></label>
      <button type=\"submit\">Apply</button>
    </form>
  </header>
  <main>
    ${body}
  </main>
</body>
</html>`;
}
