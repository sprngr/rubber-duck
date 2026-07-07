export type DuckState = {
  enabled: boolean;
  activeSubagent?: string;
  policyEnabled: boolean;
  ambientMode: boolean;
};

export type DuckStateEntry = {
  type?: string;
  customType?: string;
  data?: unknown;
};

export const DEFAULT_STATE: DuckState = {
  enabled: true,
  activeSubagent: undefined,
  policyEnabled: true,
  ambientMode: true,
};

export const STATE_ENTRY_TYPE = "rubber-duck.pi-extension.state.v1";

export function coercePersistedState(value: unknown): DuckState | null {
  if (!value || typeof value !== "object") return null;
  const raw = value as Record<string, unknown>;

  const enabled = typeof raw.enabled === "boolean" ? raw.enabled : DEFAULT_STATE.enabled;
  const activeSubagent = typeof raw.activeSubagent === "string" ? raw.activeSubagent : undefined;
  const policyEnabled = typeof raw.policyEnabled === "boolean" ? raw.policyEnabled : DEFAULT_STATE.policyEnabled;
  const ambientMode = typeof raw.ambientMode === "boolean" ? raw.ambientMode : DEFAULT_STATE.ambientMode;

  return { enabled, activeSubagent, policyEnabled, ambientMode };
}

export function loadPersistedState(entries: unknown[] | undefined): DuckState | null {
  if (!entries?.length) return null;

  for (let i = entries.length - 1; i >= 0; i--) {
    const entry = entries[i] as DuckStateEntry;
    if (entry?.type !== "custom") continue;
    if (entry?.customType !== STATE_ENTRY_TYPE) continue;

    const parsed = coercePersistedState(entry.data);
    if (parsed) return parsed;
  }

  return null;
}
