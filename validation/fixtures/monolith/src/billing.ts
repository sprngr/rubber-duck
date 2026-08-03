import { query } from "./db";

export async function handleBilling(req: express.Request, res: express.Response): Promise<void> {
  // TODO: integrate payment processor (Stripe)
  const charge = await query(
    "INSERT INTO charges (order_id, amount) VALUES ($1, $2) RETURNING *",
    [req.body.order_id, req.body.amount],
  );
  res.json({ charge: charge[0] });
}
