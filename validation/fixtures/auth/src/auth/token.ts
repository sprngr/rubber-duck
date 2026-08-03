import jwt from "jsonwebtoken";

/**
 * Verify JWT. Returns decoded payload or throws.
 * TODO(security): 2024-03-05 audit rate-limiting on /login endpoint
 */
export function verifyToken(token: string): { id: string; role: string } {
  // BUG: empty token not rejected before jwt.verify call.
  const decoded = jwt.verify(token, process.env.JWT_SECRET!) as { id: string; role: string };
  return decoded;
}
