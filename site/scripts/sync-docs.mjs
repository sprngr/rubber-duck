#!/usr/bin/env node
// Sync docs/ -> site/content/reference/
// Phase 2 minimal wiring: mirror-copy only. No link rewrite.
// TODO(site,spike): 2026-08-06 evaluate link rewrite need after first docmd build
//   spike: docmd may or may not resolve relative markdown links across nested dirs
//   unknowns:
//     - does docmd rewrite ../ links between synced pages?
//     - are absolute links from docs/ still valid inside site nav?
//   success: first live build renders reference/ pages with working cross-links

import { cp, rm, mkdir } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(here, "..", "..");
const src = resolve(repoRoot, "docs");
const dest = resolve(repoRoot, "site", "content", "reference");

await rm(dest, { recursive: true, force: true });
await mkdir(dest, { recursive: true });
await cp(src, dest, { recursive: true });

console.log(`[sync-docs] copied ${src} -> ${dest}`);
