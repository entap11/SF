import { existsSync, mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";

export type JsonRecord = Record<string, unknown>;

export interface HoneyLedgerStore {
  readonly kind: string;
  load(): JsonRecord | null;
  save(snapshot: JsonRecord): void;
}

function cleanString(value: unknown): string {
  return String(value ?? "").trim();
}

function clone(value: JsonRecord): JsonRecord {
  return JSON.parse(JSON.stringify(value)) as JsonRecord;
}

export class MemoryHoneyLedgerStore implements HoneyLedgerStore {
  readonly kind = "memory";
  private snapshot: JsonRecord | null = null;

  load(): JsonRecord | null {
    return this.snapshot == null ? null : clone(this.snapshot);
  }

  save(snapshot: JsonRecord): void {
    this.snapshot = clone(snapshot);
  }
}

export class FileHoneyLedgerStore implements HoneyLedgerStore {
  readonly kind = "file";
  readonly path: string;

  constructor(path = process.env.HONEY_LEDGER_PATH ?? "data/honey-ledger.json") {
    this.path = cleanString(path);
  }

  load(): JsonRecord | null {
    if (!this.path || this.path === ":memory:") {
      return null;
    }
    const resolved = resolve(this.path);
    if (!existsSync(resolved)) {
      return null;
    }
    try {
      return JSON.parse(readFileSync(resolved, "utf8")) as JsonRecord;
    } catch (err) {
      console.warn("HONEY_LEDGER_LOAD_FAILED", { path: resolved, err: err instanceof Error ? err.message : String(err) });
      return null;
    }
  }

  save(snapshot: JsonRecord): void {
    if (!this.path || this.path === ":memory:") {
      return;
    }
    const resolved = resolve(this.path);
    try {
      mkdirSync(dirname(resolved), { recursive: true });
      const tempPath = `${resolved}.${process.pid}.${Date.now()}.tmp`;
      writeFileSync(tempPath, JSON.stringify(snapshot, null, 2));
      renameSync(tempPath, resolved);
    } catch (err) {
      console.warn("HONEY_LEDGER_PERSIST_FAILED", { path: resolved, err: err instanceof Error ? err.message : String(err) });
    }
  }
}

export function createHoneyLedgerStore(storeOrPath?: HoneyLedgerStore | string): HoneyLedgerStore {
  if (storeOrPath != null && typeof storeOrPath === "object") {
    return storeOrPath;
  }
  const explicit = cleanString(storeOrPath);
  if (explicit && explicit !== "file" && explicit !== "memory" && explicit !== ":memory:") {
    return new FileHoneyLedgerStore(explicit);
  }
  const storeKind = cleanString(storeOrPath || process.env.HONEY_LEDGER_STORE || "file").toLowerCase();
  if (storeKind === "memory" || storeKind === ":memory:") {
    return new MemoryHoneyLedgerStore();
  }
  return new FileHoneyLedgerStore(process.env.HONEY_LEDGER_PATH ?? "data/honey-ledger.json");
}
