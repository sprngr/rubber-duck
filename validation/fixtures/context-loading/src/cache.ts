import { createClient } from "redis";

// Redis caching layer — deferred until performance baseline measured
// (see CONTEXT.md Deferred Decisions). TODO(architecture): <date> decide
// whether to adopt Redis once baseline exists.
export const cache = createClient({ url: process.env.REDIS_URL });