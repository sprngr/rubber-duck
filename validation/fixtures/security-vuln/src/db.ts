// Minimal DB interface for fixture
export const db = {
  query: async (sql: string) => ({ rows: [] as any[] }),
};
