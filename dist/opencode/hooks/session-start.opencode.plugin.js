// session-start hook for opencode
// Install: copy to .opencode/plugins/session-start.js
// Registers rubber-duck sessions at session.created, then injects the shared
// startup directive into the system prompt on every model call via
// experimental.chat.system.transform. System-level instructions are treated as
// directives by the model, unlike user-message injection.
// Cross-platform: Bun/node:fs, no shell dependency (mirrors duck-tape plugin).
import { promises as fs } from "node:fs"
import path from "node:path"

const RUBBER_DUCK_AGENT = "🦆"

// Locate and read the shared directive text (session-start.directive.md).
// Tries plugin-adjacent candidates, then falls back to cwd. Returns null on miss.
async function loadDirective(directory) {
  const base = directory || process.cwd()
  const candidates = [
    path.join(base, ".opencode", "session-start.directive.md"),
    path.join(base, ".agents", "session-start.directive.md"),
  ]
  for (const p of candidates) {
    try {
      return await fs.readFile(p, "utf8")
    } catch {
      // try next candidate
    }
  }
  return null
}

// Plugin factory. Registers rubber-duck sessions; system.transform injects the
// directive into the system prompt for those sessions.
export const SessionStartHook = async ({ client, directory }) => {
  const rubberDuckSessions = new Set()

  return {
    event: async ({ event }) => {
      if (!event || event.type !== "session.created") return
      try {
        const { sessionID, info } = event.properties || {}
        if (!sessionID || !client) {
          await client?.app?.log?.({
            body: {
              service: "session-start",
              level: "warn",
              message: "session.created: missing sessionID or client; no-op",
              extra: { event },
            },
          })
          return null
        }
        // Opt-in: only act when primary agent is rubber-duck. Otherwise silent.
        if (!info || info.agent !== RUBBER_DUCK_AGENT) {
          await client.app.log({
            body: {
              service: "session-start",
              level: "debug",
              message: `session.created: agent=${info?.agent ?? "unknown"}; no-op (not rubber-duck)`,
              extra: { sessionID },
            },
          })
          return null
        }
        rubberDuckSessions.add(sessionID)
        await client.app.log({
          body: {
            service: "session-start",
            level: "info",
            message: "session.created: registered rubber-duck session",
            extra: { sessionID },
          },
        })
      } catch {
        // Any error: no-op (fail safe). Hook must not break session startup.
        try {
          await client?.app?.log?.({
            body: {
              service: "session-start",
              level: "error",
              message: "session.created: registration failed; no-op",
            },
          })
        } catch {
          // swallow log failure
        }
      }
      return null
    },
    "experimental.chat.system.transform": async ({ sessionID }, output) => {
      if (!rubberDuckSessions.has(sessionID)) return
      try {
        const directive = await loadDirective(directory)
        if (!directive) {
          await client?.app?.log?.({
            body: {
              service: "session-start",
              level: "warn",
              message: "system.transform: rubber-duck session but directive not found; skipping",
              extra: { sessionID },
            },
          })
          return
        }
        if (!output.system.includes(directive)) {
          output.system.push(directive)
        }
        await client?.app?.log?.({
          body: {
            service: "session-start",
            level: "info",
            message: "system.transform: injected session-start directive into system prompt",
            extra: { sessionID },
          },
        })
      } catch {
        // Any error: no-op (fail safe).
      }
    },
  }
}
