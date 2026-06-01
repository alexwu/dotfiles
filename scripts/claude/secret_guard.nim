## Claude Code PreToolUse hook for the `Bash` tool.
##
## Narrowly scoped: we only care about commands that actually READ
## content from disk (cat, bat, head, rg, cp, openssl, curl, scp, etc.).
## Everything else — ls, eza, echo, git commit, printf, stat, ... —
## passes through regardless of what strings appear in the arguments.
## That avoids false positives on things like
## `git commit -m "about .env files"` where the sensitive-looking
## substring is just text, not a path being opened.
##
## The check:
##   1. Split the command on shell chaining (|, ;, &, backtick, $().
##   2. For each segment, if its leading program is a known content
##      reader AND the segment mentions a sensitive path, deny.
##
## Known tradeoff: per-segment reasoning won't catch indirect exfil
## like `ls ~/.ssh/ | xargs cat` (neither segment alone has a reader
## with a sensitive path arg). A full fix would need real shell-parsing;
## for an accident-preventing guardrail this is acceptable.
##
## Second rule (env-var leakage): a printer (echo/printf/print) whose
## arguments expand a secret-named variable in a value-emitting form
## triggers `ask`. The ONLY presence-check form that never emits the
## value is `${VAR:+word}` (and `${VAR+word}`); the `:-`/`:=`/`:?`/`}`
## /`$VAR` forms all substitute the secret itself. That asymmetry is the
## exact footgun this catches — `echo "${API_KEY:-no}"` prints the key.
## Use `${VAR:+yes}` or `just -g env-isset VAR` instead. This rule is
## `ask`, not `deny`: `curl -H "Bearer $API_KEY"` is untouched (curl is
## not a printer), and a legit `printf '%s' "$TOKEN" > f` costs one
## confirm. Known misses: `cat <<<"$KEY"`, `tee`, env-prefixed printers
## (`LC_ALL=C echo …` is stripped; others are not).
##
## Wire it up in ~/.claude/settings.json:
##   hooks.PreToolUse[].matcher = "Bash"
##   hooks.PreToolUse[].hooks[].command = "$HOME/.local/bin/secret-guard"
##
## Smoke test:
##   echo '{"tool_input":{"command":"cat ~/.ssh/id_rsa"}}' | secret-guard

import std/[json, re, strutils]

# Programs that read or transform file content based on their argument
# positions. If one of these runs against a sensitive path, that's
# almost certainly exfiltration.
let contentReader =
  re"""(?x)
  ^\s*(
    cat|bat|nl|tac|less|more|head|tail|
    rg|grep|egrep|fgrep|ag|ack|
    awk|sed|tr|cut|sort|uniq|wc|
    cp|mv|rsync|
    tar|zip|gzip|bzip2|xz|7z|
    openssl|xxd|od|base64|hexdump|strings|
    jq|jaq|yq|dasel|
    dd|split|
    md5|md5sum|shasum|sha1sum|sha256sum|sha512sum|
    gpg|age|
    curl|wget|
    scp|ssh-keygen
  )(\s|$)
"""

# Paths we consider sensitive. Specific files and credential dirs
# collapsed into one list — classification no longer matters now that
# the content-reader gate does the heavy lifting.
let sensitivePath =
  re"""(?x)
    # Specific files
    \bid_(rsa|ed25519|ecdsa|dsa)\b  # SSH private keys
  | \.pem\b                         # PEM certs/keys
  | \.p12\b | \.pfx\b               # PKCS12
  | \bage\.txt\b                    # age encryption keys
  | \.netrc\b                       # netrc credentials
  | \.npmrc\b                       # npm registry auth
  | \.pypirc\b                      # PyPI auth
  | \.env(rc)?(?!\.(example|sample|template|dist|tmpl))\b  # .env / .envrc — but not .env.example / .env.sample / .env.template / .env.dist / .env.tmpl
  | \.config/gh/hosts\b             # gh CLI tokens
  | github-copilot/apps\.json\b     # Copilot session tokens
  | atuin/key\b                     # atuin sync encryption key
    # Credential directories
  | \.ssh/                          # SSH directory
  | \.aws/                          # AWS credentials directory
  | \.gnupg/                        # GPG keyring
  | \.config/op/                    # 1Password CLI
  | \.config/fnox/                  # fnox secret store
  | \.config/rclone/                # rclone cloud tokens
  | \.config/ngrok/                 # ngrok authtoken
  | /sops/age/                      # sops-age key directory
"""

# Shell chaining split-points: pipe, semicolon, ampersand, backtick,
# command substitution, newline. We don't try to parse quoting; we just
# treat these chars as segment boundaries so each segment is checked
# independently.
let shellChainingSplit = re"""[|;&`\n]+|\$\("""

# Programs whose job is to write their arguments to stdout. If one of
# these expands a secret-named variable in a value-emitting form, the
# secret lands in the transcript.
let outputProgram = re"^\s*(?:echo|printf|print)(?:\s|$)"

# Leading `KEY=value ` env-assignment prefixes — stripped before the
# leading-program check so `LC_ALL=C echo …` is still classified as a
# printer. (Matches the prefix-strip the other Bash guards use.)
let envAssignPrefix = re"^\s*(?:[A-Za-z_][A-Za-z0-9_]*=\S*\s+)+"

# Substrings that mark a variable name as a secret.
const SecretKw =
  r"(?:API_?KEY|SECRET|TOKEN|PASSWORD|PASSWD|PASSPHRASE|ACCESS_?KEY|PRIVATE_?KEY|CREDENTIALS?|AUTH_?TOKEN)"

# A secret-named expansion in a value-emitting form. Braced: the whole
# name is consumed possessively (no backtracking into the name), then
# the operator is required to be neither `+` nor `:+` — i.e. anything
# except the two safe presence forms `${VAR+w}` / `${VAR:+w}`. Braceless
# `$VAR` has no safe form (you can't write `:+` without braces) so any
# braceless secret expansion matches.
let secretEnvExpansion = re(
  r"\$(?:\{(?=[A-Za-z0-9_]*" & SecretKw & r")[A-Za-z0-9_]++(?!\+)(?!:\+)" &
    r"|(?=[A-Za-z0-9_]*" & SecretKw & r")[A-Za-z0-9_]+)"
)

proc emit(decision, reason: string) =
  echo %*{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": decision,
      "permissionDecisionReason": reason,
    }
  }

proc deny(reason: string) =
  emit("deny", reason)

proc ask(reason: string) =
  emit("ask", reason)

proc main() =
  let payload = parseJson(stdin.readAll())
  let cmd = payload{"tool_input", "command"}.getStr("")
  if cmd.len == 0:
    return

  for segment in cmd.split(shellChainingSplit):
    if segment.contains(contentReader) and segment.contains(sensitivePath):
      deny(
        "secret-guard: `" & segment.strip() & "` reads content from a sensitive path"
      )
      return

    let prog = segment.replace(envAssignPrefix, "")
    if prog.contains(outputProgram) and segment.contains(secretEnvExpansion):
      ask(
        "secret-guard: `" & segment.strip() &
          "` would print a secret-named variable. Only `${VAR:+yes}` (or " &
          "`just -g env-isset VAR`) is value-safe — the `${VAR:-…}` / `${VAR}` " &
          "/ `$VAR` forms all expand to the secret itself."
      )
      return

when isMainModule:
  main()
