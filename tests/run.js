// duck-tape hooks behavioral tests (JS surface: opencode.plugin.js)
// Imports the plugin, mocks client.session.messages, asserts state file + marker.
import { promises as fs } from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const repoRoot = path.resolve(__dirname, "..")
const hooksDir = path.join(repoRoot, "skills", "duck-tape", "hooks")
const fixturesDir = path.join(__dirname, "fixtures")
const expectedDir = path.join(__dirname, "expected")

let failures = 0

function normalize(text, cwd, isState) {
  let result = text
  if (isState) {
    result = result.replace(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{3})?Z/g, "__TIMESTAMP__")
    result = result.replace(/\d{4}-\d{2}-\d{2}-(\d{2}[:-]\d{2}|\d{4})/g, "__STAMP__")
  }
  // Cwd path -> __CWD__ (replace all occurrences, handle both path formats).
  const cwdNormalized = cwd.replace(/\\/g, "/")
  result = result.split(cwd).join("__CWD__")
  result = result.split(cwdNormalized).join("__CWD__")
  return result
}

function assertEqual(label, actual, expected) {
  if (actual === expected) {
    console.log(`  PASS: ${label}`)
  } else {
    console.error(`  FAIL: ${label}`)
    console.error(`  --- expected ---`)
    console.error(JSON.stringify(expected))
    console.error(`  --- actual ---`)
    console.error(JSON.stringify(actual))
    failures++
  }
}

async function runTest() {
  console.log("\n=== opencode.plugin.js (opencode) ===")

  const tmpdir = await fs.mkdtemp(path.join("/tmp", "duck-test-js-"))
  const sessionId = "test-session"

  // Mock client: returns fixture data wrapped in { data: [...] }.
  const mockClient = {
    session: {
      messages: async ({ path: { id } }) => {
        if (id === "extract-test") {
          return { data: [
            { info: { role: "user", time: { created: 1 } }, parts: [{ type: "text", text: "<system>system prompt</system>" }] },
            { info: { role: "user", time: { created: 2 } }, parts: [{ type: "text", text: "Real first prompt" }] },
            { info: { role: "assistant", time: { created: 3 } }, parts: [{ type: "text", text: "DECIDED: use postgres" }] },
            { info: { role: "assistant", time: { created: 4 } }, parts: [{ type: "text", text: "we will use vite" }] },
            { info: { role: "assistant", time: { created: 5 } }, parts: [{ type: "text", text: "Final summary" }] },
            { info: { role: "user", time: { created: 6 } }, parts: [] },
            { info: null, parts: null },
          ] }
        }
        const data = JSON.parse(
          await fs.readFile(path.join(fixturesDir, "opencode-snapshot.json"), "utf-8")
        )
        return { data }
      },
    },
  }

  // Import the plugin (ES module).
  const pluginPath = path.join(hooksDir, "opencode.plugin.js")
  const pluginUrl = `file://${pluginPath}`
  const { DuckTapeCompact } = await import(pluginUrl)

  const hooks = await DuckTapeCompact({ client: mockClient, directory: tmpdir })
  const hook = hooks["experimental.session.compacting"]

  // Run the hook with a mock session ID.
  const result = await hook({ sessionID: sessionId })

  // Find the generated state file.
  const duckTapeDir = path.join(tmpdir, ".duck-tape")
  const entries = await fs.readdir(duckTapeDir)
  const stateFileName = entries.find((f) => f.endsWith("-auto.state.md"))
  if (!stateFileName) {
    console.error("  FAIL: no state file produced")
    failures++
    return
  }

  const statePath = path.join(duckTapeDir, stateFileName)
  const stateContent = await fs.readFile(statePath, "utf-8")
  const markerContent = await fs.readFile(path.join(duckTapeDir, ".last-compact"), "utf-8")

  const expectedState = await fs.readFile(path.join(expectedDir, "opencode-state.md"), "utf-8")
  const expectedMarker = await fs.readFile(path.join(expectedDir, "opencode-marker.txt"), "utf-8")

  const normalizedState = normalize(stateContent, tmpdir, true)
  const normalizedMarker = normalize(markerContent, tmpdir, true)

  assertEqual("state file", normalizedState, expectedState)
  assertEqual("marker", normalizedMarker, expectedMarker)

  // Verify Date nit fix: timestamp and stamp derive from same Date instance.
  // If they crossed a minute boundary, the stamp in Session: line would not
  // match the Created: timestamp's date/time. Check they're consistent.
  const stateTimestamp = stateContent.match(/Created: (\S+)/)?.[1]
  const stateStamp = stateContent.match(/Session: (\S+)-auto/)?.[1]
  if (stateTimestamp && stateStamp) {
    const tsDate = stateTimestamp.slice(0, 10)
    const tsTime = stateTimestamp.slice(11, 16)
    const stampMatch = stateStamp.match(/^(\d{4}-\d{2}-\d{2})-(\d{2})(?::|-)?(\d{2})$/)
    const stampDate = stampMatch?.[1]
    const stampTime = stampMatch ? `${stampMatch[2]}:${stampMatch[3]}` : null
    if (tsDate === stampDate && tsTime === stampTime) {
      console.log("  PASS: timestamp/stamp consistency (Date nit fix)")
    } else {
      console.error(`  FAIL: timestamp/stamp mismatch: ${stateTimestamp} vs ${stateStamp}`)
      failures++
    }
  }

  // Verify rotation: three-tier eviction (auto before manual), just-written file excluded.
  // Setup: 4 manual (oldest) + 7 auto (medium) + hook creates 1 new auto = 12 total.
  // New auto is excluded from eviction candidates (11 candidates > 10 cap).
  // Eviction should drop oldest auto, not oldest manual, not the new file.
  console.log("\n=== opencode.plugin.js rotation ===")
  const rotDir = await fs.mkdtemp(path.join("/tmp", "duck-test-rot-"))
  const rotDuckTape = path.join(rotDir, ".duck-tape")
  await fs.mkdir(rotDuckTape, { recursive: true })
  await fs.writeFile(path.join(rotDuckTape, ".gitignore"), "*\n")

  const baseTime = new Date("2026-07-01T00:00:00Z").getTime() / 1000

  // 4 manual state files (oldest: hours 0-3).
  for (let i = 0; i < 4; i++) {
    const fname = `2026-07-0${i + 1}-000${i}.state.md`
    await fs.writeFile(path.join(rotDuckTape, fname), "# manual\n")
    await fs.utimes(path.join(rotDuckTape, fname), baseTime + i * 3600, baseTime + i * 3600)
  }

  // 7 auto state files (medium: hours 10-16).
  for (let i = 0; i < 7; i++) {
    const fname = `2026-07-0${i + 1}-100${i}-auto.state.md`
    await fs.writeFile(path.join(rotDuckTape, fname), "# auto\n")
    const t = baseTime + (10 + i) * 3600
    await fs.utimes(path.join(rotDuckTape, fname), t, t)
  }

  // Run the hook (creates 1 new auto state file, triggers rotation).
  const rotHooks = await DuckTapeCompact({ client: mockClient, directory: rotDir })
  await rotHooks["experimental.session.compacting"]({ sessionID: "rot-test" })

  const rotEntries = await fs.readdir(rotDuckTape)
  const rotStates = rotEntries.filter((f) => f.endsWith(".state.md"))

  // 12 total - 2 evicted = 10 retained (cap: 10 total, new auto excluded from candidates).
  if (rotStates.length === 10) {
    console.log("  PASS: rotation evicts 2 of 12, retains 10 (cap: 10 total)")
  } else {
    console.error(`  FAIL: expected 10 state files, got ${rotStates.length}`)
    failures++
  }

  // Three-tier: oldest auto should be evicted, all 4 manual should survive.
  const autoRemaining = rotStates.filter((f) => f.endsWith("-auto.state.md"))
  const manualRemaining = rotStates.filter((f) => !f.endsWith("-auto.state.md"))

  if (manualRemaining.length === 4) {
    console.log("  PASS: all manual files retained (three-tier: auto evicted first)")
  } else {
    console.error(`  FAIL: expected 4 manual files retained, got ${manualRemaining.length}`)
    failures++
  }

  if (autoRemaining.length === 6) {
    console.log("  PASS: 6 auto files remain (was 8 including new, 2 oldest evicted)")
  } else {
    console.error(`  FAIL: expected 6 auto files remaining, got ${autoRemaining.length}`)
    failures++
  }

  // Verify the two oldest autos (hours 10 and 11) were evicted, not hour 12+.
  const oldestAutoSurvives = autoRemaining.some((f) => f.includes("-1000-auto"))
  const secondOldestAutoSurvives = autoRemaining.some((f) => f.includes("-1001-auto"))
  if (!oldestAutoSurvives && !secondOldestAutoSurvives) {
    console.log("  PASS: two oldest autos evicted (hours 10 and 11 gone)")
  } else {
    console.error(`  FAIL: oldest autos should be evicted (hour10=${oldestAutoSurvives} hour11=${secondOldestAutoSurvives})`)
    failures++
  }

  // Verify the just-written auto file survived (it's newest, excluded from eviction).
  const newAutoSurvives = autoRemaining.some((f) => f.includes("-auto.state.md") && !f.startsWith("2026-07-"))
  if (newAutoSurvives) {
    console.log("  PASS: just-written auto file retained (excluded from eviction)")
  } else {
    console.error("  FAIL: just-written auto file was evicted (should be excluded)")
    failures++
  }

  // Verify sec fix: path-traversal sessionId falls back to marker-only, no file
  // written outside .duck-tape/.
  console.log("\n=== opencode.plugin.js sessionId traversal guard ===")
  const secDir = await fs.mkdtemp(path.join("/tmp", "duck-test-sec-"))
  const secDuckTape = path.join(secDir, ".duck-tape")
  const secHooks = await DuckTapeCompact({ client: mockClient, directory: secDir })
  const secMarker = path.join(secDuckTape, ".last-compact")
  const escapeTarget = path.join(secDir, "evil-transcript.json")

  // Traversal payload: climb out of .duck-tape/ into secDir/.
  await secHooks["experimental.session.compacting"]({ sessionID: "../../../evil" })

  const markerExists = await fs.access(secMarker).then(() => true).catch(() => false)
  const escapeExists = await fs.access(escapeTarget).then(() => true).catch(() => false)
  if (markerExists && !escapeExists) {
    console.log("  PASS: traversal sessionId -> marker-only, no escape file")
  } else {
    console.error(`  FAIL: marker=${markerExists} escape=${escapeExists}`)
    failures++
  }

  // Verify extraction: < prefixed user text skipped, multiple decision variants, guards.
  console.log("\n=== opencode.plugin.js extraction edge cases ===")
  const extDir = await fs.mkdtemp(path.join("/tmp", "duck-test-ext-"))
  const extHooks = await DuckTapeCompact({ client: mockClient, directory: extDir })
  await extHooks["experimental.session.compacting"]({ sessionID: "extract-test" })
  const extEntries = await fs.readdir(path.join(extDir, ".duck-tape"))
  const extStateFile = extEntries.find((f) => f.endsWith("-auto.state.md"))
  const extState = await fs.readFile(path.join(extDir, ".duck-tape", extStateFile), "utf-8")

  const checks = [
    ["firstPrompt skips < prefixed", extState.includes("Real first prompt"), !extState.includes("<system>")],
    ["DECISION_PATTERN: DECIDED", extState.includes("DECIDED: use postgres"), true],
    ["DECISION_PATTERN: we will use", extState.includes("we will use vite"), true],
    ["lastText is final assistant text", extState.includes("Final summary"), true],
  ]
  for (const [label, ...conds] of checks) {
    if (conds.every(Boolean)) console.log(`  PASS: ${label}`)
    else { console.error(`  FAIL: ${label}`); failures++ }
  }

  await fs.rm(extDir, { recursive: true, force: true })

  // Cleanup.
  await fs.rm(tmpdir, { recursive: true, force: true })
  await fs.rm(rotDir, { recursive: true, force: true })
  await fs.rm(secDir, { recursive: true, force: true })
}

console.log("### duck-tape hook tests (JS) ###")
await runTest()
console.log(`\n=== Results: ${failures} failure(s) ===`)
process.exit(failures > 0 ? 1 : 0)
