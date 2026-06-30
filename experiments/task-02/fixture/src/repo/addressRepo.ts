type Address = {
  id: string;
  user_id: string;
  is_default: boolean;
  updated_at?: string;
};

// Minimal query-shape stub for fixture readability
const db = (table: string) => ({
  where: (_q: Record<string, unknown>) => ({
    first: async (): Promise<Address | undefined> => undefined,
  }),
});

export async function getDefaultAddress(userId: string) {
  return db("addresses")
    .where({ user_id: userId, is_default: true })
    .first();
}
