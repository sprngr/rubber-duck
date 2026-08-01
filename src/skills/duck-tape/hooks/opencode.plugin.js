// duck-tape pre-compact hook for opencode (Angle A: auto-checkpoint)
// Install: copy to .opencode/plugins/duck-tape.js
// Fetches session messages via SDK, extracts content into Agent State file.
// Falls back to marker-only write on any error. Cross-platform (Bun fs).
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

function truncate200(s) {
  if (!s) return ""
  if (s.length > 200) s = s.slice(0, 200)
  s = s.replace(/\r\n/g, " ").replace(/\n/g, " ").replace(/\r/g, " ")
  s = s.replace(/\|/g, "\\|")
  return s
}

const DECISION_PATTERN = /APPROVED|DECIDED|CHOSE|DECISION|we will use|going with|let's go with/i

function extractTarget(part) {
  const input = part.state?.input || {}
  return input.file_path || input.command || input.filePath || "unknown"
}

async function writeMarkerOnly(duckTapeDir, timestamp, cwd) {
  const latest = await latestStateFile(duckTapeDir)
  let line = `${timestamp} | cwd: ${cwd}`
  if (latest) line += ` | latest-state: ${latest}`
  line += "\n"
  const marker = path.join(duckTapeDir, ".last-compact")
  await fs.writeFile(marker, line)
  return marker
}

// Incremental transcript snapshot for Angle B recovery.
// Writes messages created after the last existing state file's mtime.
// Called before renderState writes the new state file, so the delta window
// captures content since the previous checkpoint, not the one being created.
async function writeTranscriptSnapshot(duckTapeDir, sessionId, messageList) {
  let sinceMs = 0
  try {
    const entries = await fs.readdir(duckTapeDir)
    const states = entries.filter((f) => f.endsWith(".state.md"))
    if (states.length > 0) {
      const statted = await Promise.all(
        states.map(async (f) => ({
          mt: (await fs.stat(path.join(duckTapeDir, f))).mtimeMs,
        }))
      )
      sinceMs = Math.max(...statted.map((s) => s.mt))
    }
  } catch {
    // No state files or stat error: include all messages.
  }
  const filtered = messageList.filter((m) => {
    const c = m?.info?.time?.created
    return typeof c === "number" && c > sinceMs
  })
  const snapPath = path.join(duckTapeDir, `${sessionId}-transcript.json`)
  await fs.writeFile(snapPath, JSON.stringify(filtered))
  return snapPath
}

async function renderState(duckTapeDir, transcriptRef, cwd, stamp, timestamp, firstPrompt, toolCalls, lastText, decisions, snapshotPath) {
  if (!firstPrompt && toolCalls.length === 0 && !lastText) {
    return false
  }

  const firstPromptT = truncate200(firstPrompt)
  const lastTextT = truncate200(lastText)

  let sb = ""
  sb += "# Agent State\n\n"
  sb += `Session: ${stamp}-auto | Cwd: ${cwd} | Trigger: pre-compact-auto\n`
  sb += `Created: ${timestamp} | Updated: ${timestamp} | Compactions: 0\n\n`
  sb += "## Approved Workflow\n"
  sb += firstPromptT ? firstPromptT + "\n" : "(not derivable from transcript)\n"
  sb += "\n"
  sb += "## Position\n"
  sb += `- **Current:** ${lastTextT}\n`
  sb += "- **Done:**\n"
  if (toolCalls.length > 0) {
    for (const line of toolCalls) {
      if (!line) continue
      sb += `  - ${line} (${timestamp})\n`
    }
  } else {
    sb += "  (none extracted)\n"
  }
  sb += "- **Remaining:** (not derivable from transcript)\n\n"
  sb += "## Decision Log\n"
  if (decisions.length > 0) {
    for (const line of decisions) {
      if (!line) continue
      const snippet = truncate200(line)
      sb += `${timestamp} AUTO-EXTRACTED: ${snippet}\n`
    }
  } else {
    sb += "(none detected)\n"
  }
  sb += "\n"
  sb += "## Established Facts\n"
  sb += "(auto-extracted; not reliably derivable from transcript shell parsing)\n\n"
  sb += "## Re-derivation\n"
  sb += `Read session messages via SDK for session ${transcriptRef} for full content.\n`
  sb += "Read latest manual state file in .duck-tape/ for higher-fidelity checkpoint.\n\n"
  sb += "## Suggested Skills\n"
  sb += "- duck-tape (run /duck-tape for full state before next compaction)\n"

  const stateFile = path.join(duckTapeDir, `${stamp}-auto.state.md`)
  await fs.writeFile(stateFile, sb)

  // Rotation cap: 10 files. Eviction precedence: auto, recovered, manual.
  const all = (await fs.readdir(duckTapeDir))
    .filter((f) => f.endsWith(".state.md"))
    .map((f) => ({ name: f, path: path.join(duckTapeDir, f) }))
  if (all.length > 0) {
    const statted = await Promise.all(
      all.map(async (s) => ({ ...s, mtime: (await fs.stat(s.path)).mtimeMs }))
    )
    let count = statted.length
    while (count > 10) {
      const autos = statted.filter((s) => s.name.endsWith("-auto.state.md"))
      let drop
      if (autos.length > 0) {
        drop = autos.sort((a, b) => a.mtime - b.mtime)[0]
      } else {
        const recovered = statted.filter((s) => s.name.endsWith("-recovered.state.md"))
        if (recovered.length > 0) {
          drop = recovered.sort((a, b) => a.mtime - b.mtime)[0]
        } else {
          drop = statted.sort((a, b) => a.mtime - b.mtime)[0]
        }
      }
      try { await fs.unlink(drop.path) } catch {}
      statted.splice(statted.indexOf(drop), 1)
      count--
    }
  }

  // Marker points at newest state file.
  const latest = await latestStateFile(duckTapeDir)
  let line = `${timestamp} | cwd: ${cwd} | latest-state: ${latest}`
  if (snapshotPath) {
    try { await fs.access(snapshotPath); line += ` | transcript: ${snapshotPath}` } catch {}
  }
  line += "\n"
  const marker = path.join(duckTapeDir, ".last-compact")
  await fs.writeFile(marker, line)
  return stateFile
}

export const DuckTapeCompact = async ({ client, directory }) => {
  return {
    "experimental.session.compacting": async (input) => {
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
      const stamp = new Date().toISOString().slice(0, 10) + "-" + new Date().toISOString().slice(11, 16)

      // Require client + sessionId for extraction. Accept both sessionId and sessionID (opencode uses sessionID).
      if (!client || (!input?.sessionId && !input?.sessionID)) {
        return await writeMarkerOnly(duckTapeDir, timestamp, cwd)
      }

      const sessionId = input.sessionId || input.sessionID

      try {
        const messages = await client.session.messages({ path: { id: sessionId } })

        // Normalize: opencode returns { data: [...] } wrapper at runtime.
        const messageList = Array.isArray(messages) ? messages
          : (messages && Array.isArray(messages.data)) ? messages.data
          : null

        if (!messageList) {
          return await writeMarkerOnly(duckTapeDir, timestamp, cwd)
        }

        let firstPrompt = null
        const toolCalls = []
        let lastText = null
        const decisions = []

        for (const { info, parts } of messageList) {
          if (!info || !parts) continue

          if (info.role === "user" && !firstPrompt) {
            for (const part of parts) {
              if (part.type === "text" && typeof part.text === "string") {
                if (!part.text.startsWith("<")) {
                  firstPrompt = part.text
                  break
                }
              }
            }
          }

          if (info.role === "assistant") {
            for (const part of parts) {
              if (part.type === "tool") {
                const target = extractTarget(part)
                toolCalls.push(`${part.tool}: ${target}`)
              }
              if (part.type === "text" && typeof part.text === "string") {
                lastText = part.text
                if (DECISION_PATTERN.test(part.text)) {
                  decisions.push(part.text)
                }
              }
            }
          }
        }

        // Last 10 unique decisions.
        const uniqueDecisions = []
        const seen = new Set()
        for (const d of decisions) {
          if (!seen.has(d)) {
            seen.add(d)
            uniqueDecisions.push(d)
          }
        }
        const trimmedDecisions = uniqueDecisions.length > 10
          ? uniqueDecisions.slice(uniqueDecisions.length - 10)
          : uniqueDecisions

        // Incremental snapshot for Angle B recovery (before state file write).
        let snapshotPath = null
        try {
          snapshotPath = await writeTranscriptSnapshot(duckTapeDir, sessionId, messageList)
        } catch {
          // Snapshot failure is non-fatal; marker omits transcript field.
        }

        const ok = await renderState(
          duckTapeDir, sessionId, cwd, stamp, timestamp,
          firstPrompt, toolCalls, lastText, trimmedDecisions, snapshotPath
        )
        if (!ok) {
          return await writeMarkerOnly(duckTapeDir, timestamp, cwd)
        }
        return ok
      } catch {
        // Any SDK or parse error: marker-only fallback.
        return await writeMarkerOnly(duckTapeDir, timestamp, cwd)
      }
    },
  }
}
