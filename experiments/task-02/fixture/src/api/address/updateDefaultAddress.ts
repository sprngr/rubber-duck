type Request = {
  auth: { userId: string };
  body: { addressId: string };
};

type Response = {
  status: (code: number) => { send: () => unknown };
};

// Minimal DB shape for fixture readability
const db = {
  tx: async (fn: (trx: any) => Promise<void>) => fn((table: string) => ({
    where: (_q: Record<string, unknown>) => ({
      update: async (_u: Record<string, unknown>) => {},
    }),
  })),
};

export async function updateDefaultAddress(req: Request, res: Response) {
  const userId = req.auth.userId;
  const { addressId } = req.body;

  await db.tx(async (trx) => {
    // BUG: global unset (not scoped by user_id)
    await trx("addresses")
      .where({ is_default: true })
      .update({ is_default: false });

    // BUG: set not scoped by user ownership
    await trx("addresses")
      .where({ id: addressId })
      .update({ is_default: true, updated_at: new Date() });
  });

  return res.status(204).send();
}
