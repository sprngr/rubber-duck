// session-start hook for opencode (dual V1 + V2 plugin API)
// Install: copy to .opencode/plugins/session-start.js
// Registers rubber-duck sessions at session.created, then injects the shared
// startup directive into the model system prompt on every model call. V2 uses
// ctx.event.subscribe + ctx.session.hook("context"); V1 uses the hook map
// returned by server(). System-level instructions are treated as directives by
// the model, unlike user-message injection.
// Cross-platform: Bun/node:fs, no shell dependency (mirrors duck-tape plugin).
import { Plugin } from "@opencode/plugin"
import { promises as fs } from "node:fs"
import path from "node:path"

const RUBBER_DUCK_AGENT = "rubber-duck"

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

// OpenCode V1 factory. Registers rubber-duck sessions; system.transform injects
// the directive into the system prompt for those sessions.
export const SessionStartHook = async ({ client, directory } = {}) => {
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

// OpenCode V2 plugin (dual export). setup uses ctx.event.subscribe and the
// session "context" hook; the shared V1 factory is exposed as server().
export default {
  ...Plugin.define({
    id: "session-start",
    async setup(ctx) {
      const rubberDuckSessions = new Set()
      const controller = new AbortController()

      void (async () => {
        for await (const event of ctx.event.subscribe({ signal: controller.signal })) {
          if (!event || event.type !== "session.created") continue
          const { sessionID, info } = event.properties || {}
          if (sessionID && info && info.agent === RUBBER_DUCK_AGENT) {
            rubberDuckSessions.add(sessionID)
          }
        }
      })()

      await ctx.session.hook("context", async (event) => {
        if (!rubberDuckSessions.has(event.sessionID)) return
        const directive = await loadDirective(ctx.location.directory)
        if (!directive) return
        const present = event.system.some(
          (part) => part && part.type === "text" && part.text === directive,
        )
        if (!present) event.system.push({ type: "text", text: directive })
      })

      return () => controller.abort()
    },
  }),
  server: SessionStartHook,
}
