// duck-tape pre-compact hook for opencode
// Install: copy to .opencode/plugins/duck-tape.js
// Inlines marker logic in JS. No shell call. Cross-platform (Bun fs).
import { promises as fs } from "node:fs"
import path from "node:path"

async function latestStateFile(dir) {
  try {
    const entries = await fs.readdir(dir)
    const states = entries
      .filter((f) => f.endsWith(".state.md"))
      .map((f) => ({ name: f, path: path.join(dir, f) }))
    if (states.length === 0) return null
    const statted = await Promise.all(
      states.map(async (s) => ({ ...s, mtime: (await fs.stat(s.path)).mtimeMs }))
    )
    statted.sort((a, b) => b.mtime - a.mtime)
    return statted[0].name
  } catch {
    return null
  }
}

export const DuckTapeCompact = async ({ directory }) => {
  return {
    "experimental.session.compacting": async () => {
      const cwd = directory || process.cwd()
      const duckTapeDir = path.join(cwd, ".duck-tape")
      await fs.mkdir(duckTapeDir, { recursive: true })

      // .gitignore if missing
      const gitignore = path.join(duckTapeDir, ".gitignore")
      try {
        await fs.access(gitignore)
      } catch {
        await fs.writeFile(gitignore, "*\n")
      }

      const timestamp = new Date().toISOString()
      const latest = await latestStateFile(duckTapeDir)

      let line = `${timestamp} | cwd: ${cwd}`
      if (latest) line += ` | latest-state: ${latest}`
      line += "\n"

      const marker = path.join(duckTapeDir, ".last-compact")
      await fs.writeFile(marker, line)
      return marker
    },
  }
}
