# Pi Adapter

## Status

Scaffolded (static checks validated).

## Install

```bash
bash scripts/install.sh --pi
```

## Path

```text
${XDG_CONFIG_HOME:-$HOME/.config}/pi/rubber-duck/
```

## Notes

- Includes local plugin scaffold + command mapping files.
- Runtime behavior should be validated in your Pi environment.

## Manual verify steps

1. Run install command above.
2. Confirm files under target path.
3. Start fresh Pi session.
4. Try `/quack` and `/duck-debug` prompts.
