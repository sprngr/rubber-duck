import express from "express";
import { handleAuth } from "./auth";
import { handleOrders } from "./orders";
import { handleBilling } from "./billing";
import { db } from "./db";

const app = express();

app.post("/login", handleAuth);
app.post("/orders", handleOrders);
app.post("/billing/charge", handleBilling);

app.listen(3000, () => console.log("monolith on :3000"));

export { app, db };
