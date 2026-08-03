import { query } from "./db";

export async function handleOrders(req: express.Request, res: express.Response): Promise<void> {
  const result = await query(
    "INSERT INTO orders (user_id, total) VALUES ($1, $2) RETURNING *",
    [req.body.user_id, req.body.total],
  );
  res.json({ order: result[0] });
}
