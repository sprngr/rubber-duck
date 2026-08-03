import { Pool } from "pg";

/**
 * Shared DB pool: all modules import this directly.
 * Coupling point for service extraction.
 */
export const db = new Pool({
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
});

export async function query<T>(sql: string, params: unknown[]): Promise<T[]> {
  const result = await db.query(sql, params);
  return result.rows as T[];
}
