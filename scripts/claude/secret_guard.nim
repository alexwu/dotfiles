## Claude Code PreToolUse hook for the `Bash` tool.
##
## Two-tier check on `tool_input.command`:
##
## 1. `alwaysDenyPattern` — specific files whose content is inherently
##    sensitive (private SSH keys, .env, cert/key files, token stores).
##    Any command that references these paths is denied.
##
## 2. `sensitiveDirPattern` — directories known to contain secrets
##    (`~/.ssh/`, `~/.aws/`, etc.). These are only denied when the
##    command would actually read content. Pure listing/metadata
##    commands (`ls`, `eza`, `tree`, `stat`, `file`, ...) pass through —
##    UNLESS the command also contains shell chaining (`|`, `;`, `&`,
##    backtick, `$(`), in which case the chain could re-introduce
##    content-reading downstream.
##
## Reads the hook payload JSON on stdin. On deny, emits a JSON decision;
## otherwise exits silently with no opinion so the normal permission
## flow runs.
##
## Wire it up in ~/.claude/settings.json under:
##   hooks.PreToolUse[].matcher = "Bash"
##   hooks.PreToolUse[].hooks[].type = "command"
##   hooks.PreToolUse[].hooks[].command = "$HOME/.local/bin/secret-guard"
##
## Smoke test:
##   echo '{"tool_input":{"command":"cat ~/.ssh/id_rsa"}}' | secret-guard

import std/[json, re]

let alwaysDenyPattern =
  re"""(?x)
    \bid_(rsa|ed25519|ecdsa|dsa)\b  # SSH private key filenames
  | \.pem\b                         # PEM certs/keys
  | \.p12\b                         # PKCS12
  | \.pfx\b                         # PKCS12 (Windows-flavored)
  | \bage\.txt\b                    # age encryption key files
  | \.netrc\b                       # netrc credentials
  | \.npmrc\b                       # npm registry auth
  | \.pypirc\b                      # PyPI auth
  | \.env(rc)?\b                    # .env / .envrc files
  | \.config/gh/hosts\b             # gh CLI tokens
  | github-copilot/apps\.json\b     # Copilot session tokens
  | atuin/key\b                     # atuin sync encryption key
"""

let sensitiveDirPattern =
  re"""(?x)
    \.ssh/                # SSH directory
  | \.aws/                # AWS credentials directory
  | \.gnupg/              # GPG keyring
  | \.config/op/          # 1Password CLI
  | \.config/fnox/        # fnox secret store
  | \.config/rclone/      # rclone cloud tokens
  | \.config/ngrok/       # ngrok authtoken
  | /sops/age/            # sops-age key directory
"""

# Commands that only list/stat/resolve paths — cannot read file content
# by themselves. Anchored to the start of the command string.
let inspectionOnlyCommand =
  re"""^\s*(ls|eza|exa|tree|stat|file|readlink|realpath|dirname|basename|pwd|which|type|whereis)(\s|$)"""

# Shell chaining or command substitution. If any of these are present
# alongside a sensitive-dir reference, we assume exfiltration is on the
# table and deny regardless of the leading command.
let shellChainingPattern = re"""[|;&`]|\$\("""

proc deny(reason: string) =
  let decision = %*{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "deny",
      "permissionDecisionReason": reason,
    }
  }
  echo decision

proc main() =
  let payload = parseJson(stdin.readAll())
  let cmd = payload{"tool_input", "command"}.getStr("")
  if cmd.len == 0:
    return

  if cmd.contains(alwaysDenyPattern):
    deny("secret-guard: command references a sensitive file")
    return

  if cmd.contains(sensitiveDirPattern):
    if cmd.contains(inspectionOnlyCommand) and not cmd.contains(shellChainingPattern):
      return
    deny("secret-guard: command may read content from a sensitive directory")
    return

when isMainModule:
  main()
