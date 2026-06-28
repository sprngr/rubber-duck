# Rubber Duck Quickstart by Preference

Use this guide when you want to pick install path based on confidence level and harness preference.

## Support tiers

| Harness | Tier | Meaning | Install command |
|---|---|---|---|
| OpenCode | **Verified** | Maintainer-tested locally | `bash scripts/install.sh --opencode` |
| Claude Code | **Scaffolded** | Static checks + docs validated; runtime validate in your env | `bash scripts/install.sh --claude-code` |
| GitHub Copilot | **Scaffolded** | Static checks + docs validated; runtime validate in your env | `bash scripts/install.sh --copilot` |
| Pi | **Scaffolded** | Static checks + docs validated; runtime validate in your env | `bash scripts/install.sh --pi` |

---

## Step-by-step chooser

### Step 1: Choose confidence level

1. Need highest confidence right now → choose **Verified** (OpenCode).
2. Need a specific harness and can do local validation yourself → choose **Scaffolded**.

### Step 2: Choose installation mode

Option A (recommended): interactive chooser

```bash
bash scripts/install-harness.sh
```

Option B: direct harness command

```bash
# Verified
bash scripts/install.sh --opencode

# Scaffolded
bash scripts/install.sh --claude-code
bash scripts/install.sh --copilot
bash scripts/install.sh --pi
```

### Step 3: Verify quickly

1. Confirm install path exists:

```text
OpenCode:      ${XDG_CONFIG_HOME:-$HOME/.config}/opencode/rubber-duck/
Claude Code:  ${XDG_CONFIG_HOME:-$HOME/.config}/claude-code/rubber-duck/
GitHub Copilot:${XDG_CONFIG_HOME:-$HOME/.config}/copilot/rubber-duck/
Pi:            ${XDG_CONFIG_HOME:-$HOME/.config}/pi/rubber-duck/
```

2. Start fresh session in your harness.
3. Run `quack`.
4. Run one workflow command (for example `/duck-review`) against a sample prompt.

---

## Uninstall shortcuts

```bash
bash scripts/uninstall.sh --opencode
bash scripts/uninstall.sh --claude-code
bash scripts/uninstall.sh --copilot
bash scripts/uninstall.sh --pi
```

Add `--dry-run` to preview and `--force` to skip prompts.

---

## Recommendation

If unsure, start with OpenCode (Verified), confirm behavior, then expand to scaffolded harnesses that match your workflow.
