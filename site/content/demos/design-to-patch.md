---
title: Design → Patch
---

# Design → Patch

Setting up a new static site. User picked structured workflow via `quack design`.

---

**User:** I want to spin up a static site for the rubber-duck project on GitHub Pages built with docmd.

**Duck:** This is multi-step (tooling + content + deployment). Approach?
1. Conversational
2. Structured `quack design` — formal option comparison

Framing questions: scope of first cut? Content source? Demos format? Deploy target? Site location?

**User:** 2

**Duck:** Routing: duck-design.

Plan is multi-component. Chunking. Slices:
1. Foundation — docmd install, scaffold, workflow
2. Skill catalogue
3. Docs (usage)
4. Philosophy + Architecture
5. Static demos

Main tradeoff: fast launch vs completeness. Start where?

**User:** Work through all 5, starting with 1.

**Duck:** Foundation slice — decisions to lock:
- Site source location: `site/` vs consume `docs/` vs hybrid?
- Node install: root vs isolated `site/package.json`?
- Deploy: Actions on main vs `gh-pages` branch?

**User:** Hybrid. Isolated. Actions on main.

**Duck:** Phase 1a preflight — 6 files, ~75 lines. All skeleton. `site/package.json`, `docmd.config.json`, `.gitignore`, README, landing stub, Makefile edit. Approve?

**User:** ok

**Duck:** *[applies files, verifies `make check-site` exits 0]* Phase 1a done. Phase 1b next: 5 section stubs...
