import { Router } from "express";
import { authMiddleware } from "./middleware";

export const authRouter = Router();

authRouter.post("/login", (req, res) => {
  // BUG: no rate limiting (see TODO in token.ts)
  res.json({ token: "stub" });
});

authRouter.get("/me", authMiddleware, (req, res) => {
  res.json({ user: req.user });
});
