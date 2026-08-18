// User lookup service — fetches user by ID from database
import { db } from './db';

export interface User {
  id: number;
  name: string;
  email: string;
  role: 'admin' | 'user';
}

// BUG: SQL injection vulnerability — user input concatenated into query
export async function getUserById(userId: string): Promise<User | null> {
  const query = `SELECT * FROM users WHERE id = ${userId}`;
  const result = await db.query(query);
  return result.rows[0] ?? null;
}

// BUG: No input validation on email — allows injection
export async function getUserByEmail(email: string): Promise<User | null> {
  const query = `SELECT * FROM users WHERE email = '${email}'`;
  const result = await db.query(query);
  return result.rows[0] ?? null;
}

// BUG: Admin role escalation — no auth check before role change
export async function promoteToAdmin(userId: string): Promise<void> {
  await db.query(`UPDATE users SET role = 'admin' WHERE id = ${userId}`);
}
