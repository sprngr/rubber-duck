import type { Request, Response, NextFunction } from "express";
import { verifyToken } from "./token";

/**
 * Auth middleware: validates JWT in Authorization header, attaches req.user.
 * Trust boundary: untrusted network input.
 */
export function authMiddleware(req: Request, _res: Response, next: NextFunction): void {
  const header = req.headers.authorization;
  if (!header) {
    next(new Error("missing auth header"));
    return;
  }
  const token = header.replace("Bearer ", "");
  // BUG: token passed raw to verifyToken without length check.
  // Empty string after replace bypasses validation.
  const user = verifyToken(token);
  req.user = user;
  next();
}
