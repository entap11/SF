import type { QueryResult } from "pg";
import type { PGliteInterface } from "@electric-sql/pglite";

type PGliteResult<T> = { rows: T[]; affectedRows?: number };

export class PGlitePoolAdapter {
  constructor(private readonly db: PGliteInterface) {}

  async query<T extends Record<string, unknown> = Record<string, unknown>>(
    sql: string, params: unknown[] = []
  ): Promise<QueryResult<T>> {
    if (params.length === 0 && sql.split(";").filter((part) => part.trim()).length > 1) {
      const results = await this.db.exec(sql);
      return this.normalize((results.at(-1) ?? { rows: [], affectedRows: 0 }) as PGliteResult<T>);
    }
    return this.normalize(await this.db.query<T>(sql, params) as PGliteResult<T>);
  }

  async connect(): Promise<PGlitePoolAdapter & { release: () => void }> {
    return Object.assign(this, { release: () => undefined });
  }

  private normalize<T extends Record<string, unknown>>(result: PGliteResult<T>): QueryResult<T> {
    return {
      command: "",
      rowCount: result.rows.length > 0 ? result.rows.length : (result.affectedRows ?? 0),
      oid: 0,
      fields: [],
      rows: result.rows
    };
  }
}
