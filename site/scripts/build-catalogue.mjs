#!/usr/bin/env node
// Build skill catalogue pages from skills/*/SKILL.md + installer tier.

import { readFile, writeFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(here, "..", "..");
const skillsOut = resolve(repoRoot, "site", "content", "skills");
const notesDir = resolve(repoRoot, "site", "catalogue-notes");

async function loadGroups() {
  const raw = await readFile(resolve(repoRoot, "site", "catalogue.groups.json"), "utf8");
  return JSON.parse(raw).groups;
}

async function readSkillFrontmatter(name) {
  const raw = await readFile(resolve(repoRoot, "skills", name, "SKILL.md"), "utf8");
  const m = raw.match(/^---\n([\s\S]*?)\n---/);
  const body = m ? m[1] : "";
  const nm = body.match(/^name:\s*(.+)$/m);
  const dm = body.match(/^description:\s*>([\s\S]*?)(?=^\w|\Z)/m);
  return {
    name: nm ? nm[1].trim() : name,
    description: dm ? dm[1].replace(/\n\s+/g, " ").trim() : "",
  };
}

async function loadTiers() {
  const raw = await readFile(resolve(repoRoot, "scripts", "rubber-duck.sh"), "utf8");
  const pick = (label) => {
    const m = raw.match(new RegExp(`${label}=\\(([\\s\\S]*?)\\)`));
    return m ? [...m[1].matchAll(/"([^"]+)"/g)].map((x) => x[1]) : [];
  };
  const defaults = new Set(pick("DEFAULT_SKILLS"));
  const extras = new Set(pick("EXTRAS_SKILLS"));
  return (name) => (defaults.has(name) ? "default" : extras.has(name) ? "extra" : "unknown");
}

const groups = await loadGroups();
const tierOf = await loadTiers();

let index = `---\ntitle: Skills\n---\n\n# Skills Catalogue\n\nEvery duck skill: purpose, triggers, boundaries.\n\nTier: **default** = installed by installer; **extra** = opt-in via \`--extras\`.\n`;

for (const group of groups) {
  index += `\n## ${group.title}\n\n${group.description}\n\n`;
  for (const name of group.skills) {
    const fm = await readSkillFrontmatter(name);
    const tier = tierOf(name);
    index += `- [${fm.name}](./${name}.md) — _${tier}_ — ${fm.description}\n`;
    const notesPath = resolve(notesDir, `${name}.md`);
    const notes = existsSync(notesPath)
      ? await readFile(notesPath, "utf8")
      : `> TODO(site): add editorial notes for ${name} at site/catalogue-notes/${name}.md`;
    const page = `---\ntitle: ${fm.name}\n---\n\n# ${fm.name}\n\n**Tier:** ${tier}\n**Group:** ${group.title}\n\n${fm.description}\n\n[Source SKILL.md](https://github.com/sprngr/rubber-duck/blob/main/skills/${name}/SKILL.md)\n\n## Notes\n\n${notes}\n`;
    await writeFile(resolve(skillsOut, `${name}.md`), page);
  }
}

await writeFile(resolve(skillsOut, "index.md"), index);
console.log("[build-catalogue] wrote skills/index.md + 14 per-skill pages");
