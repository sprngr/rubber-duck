# OpenCode Adapter

## Status

Verified.

## Install

```bash
bash scripts/install.sh --opencode
```

## Path

```text
${XDG_CONFIG_HOME:-$HOME/.config}/opencode/rubber-duck/
```

## Manual verify steps

1. Run install command above.
2. Start fresh OpenCode session.
3. Send `quack` and verify status response.
4. Send `/duck-review` with sample diff prompt and verify routing.
