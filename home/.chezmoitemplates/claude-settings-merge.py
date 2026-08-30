#!/usr/bin/env python3
"""Merge our tracked constants into a live Claude Code settings.json.

Lives in .chezmoitemplates because three targets need it: the shared ~/.claude
root and each per-account config dir (~/.claude-personal, ~/.claude-work). Each
one's modify_settings.json.tmpl is a single includeTemplate of this file, so the
constants below have exactly one home.

Claude Code rewrites settings.json itself whenever a /config, /model, or /theme
toggle changes something, so tracking the file verbatim means permanent drift:
the app reorders keys and writes machine-local preferences back on its own.

chezmoi runs a modify_ script with the current target file on stdin and writes
our stdout back to it, which lets the file have two writers. We own the keys in
FORCE (re-injected on every apply) and the ones in SEED (written only when
absent, so a fresh machine gets a default and later toggles survive). Everything
else -- permissions.allow, enabledPlugins, and any key a future release adds --
passes through untouched.

Note: `chezmoi add`/`re-add` cannot round-trip this file. Edit the constants here.
"""

import json
import sys

# Repo wins on every apply.
FORCE = {
    "env": {
        "CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING": "1",
        "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1",
    },
    "statusLine": {
        "type": "command",
        "command": "bash $HOME/.claude/statusline-command.sh",
    },
    "model": "opus",
    "effortLevel": "xhigh",
    "outputStyle": "Concise",
    "tui": "fullscreen",
    "skipAutoPermissionPrompt": True,
}
# Note: the `claude` shell wrapper (~/.zsh/function) passes
# --dangerously-skip-permissions, which outranks this for interactive runs. This is
# what everything else gets -- GUI editors, cron, `command claude` -- and what
# `claude --permission-mode auto` falls back to.
FORCE_PERMISSIONS = {
    "defaultMode": "auto",
}

# Written only when the key is missing.
SEED = {
    "theme": "dark-daltonized",
    "verbose": True,
    "skipDangerousModePermissionPrompt": True,
}
SEED_PERMISSIONS = {
{{- if eq .class "work-devbox" }}
    "additionalDirectories": [
        "/home/coder/lwcode/services/.claude/skills",
        "/home/coder/lwcode/services/vulnerability/.claude/skills",
        "/home/coder/lwcode/services/vulnerability/vuln-feeds-manager/.claude/skills",
    ],
{{- end }}
}


def main() -> int:
    raw = sys.stdin.read()

    # Empty stdin means the file does not exist yet: bootstrap from our constants.
    if raw.strip():
        try:
            settings = json.loads(raw)
        except json.JSONDecodeError as err:
            # Exiting non-zero makes chezmoi report the error and leave the live
            # file alone, rather than replacing it with something malformed.
            print("settings.json is not valid JSON: %s" % err, file=sys.stderr)
            return 1
        if not isinstance(settings, dict):
            print("settings.json is not a JSON object", file=sys.stderr)
            return 1
    else:
        settings = {}

    # Live key order first, so a no-op apply produces a no-op diff.
    settings.update(FORCE)
    for key, value in SEED.items():
        settings.setdefault(key, value)

    permissions = settings.get("permissions")
    if not isinstance(permissions, dict):
        permissions = {}
    permissions.update(FORCE_PERMISSIONS)
    for key, value in SEED_PERMISSIONS.items():
        permissions.setdefault(key, value)
    settings["permissions"] = permissions

    print(json.dumps(settings, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
