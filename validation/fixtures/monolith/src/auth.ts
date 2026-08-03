import { query } from "./db";

export async function handleAuth(req: express.Request, res: express.Response): Promise<void> {
  // TODO: replace with proper JWT validation
  const users = await query("SELECT * FROM users WHERE email = $1", [req.body.email]);
  res.json({ user: users[0] });
}
