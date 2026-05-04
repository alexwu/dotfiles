---
paths:
  - "dot_claude/scripts/**"
  - "scripts/claude/**"
  - "run_onchange_build-scripts.sh.tmpl"
---

# Claude Scripts

## Scripts
- `dot_claude/scripts/executable_dictate.py` — streaming dictation via Voxtral Realtime
  - Uses PEP 723 inline deps (`uv run --script`), no separate requirements file
  - Connects to mlx_audio.server WebSocket at `/v1/audio/transcriptions/realtime`
  - `--start-server` spawns uvicorn in single-process mode on port 8800

## Scripts
- `scripts/<domain>/` at repo root — source only, ignored by chezmoi; binaries compile to `~/.local/bin/`
- `run_onchange_build-scripts.sh.tmpl` — chezmoi rebuilds on source-hash change (`include … | sha256sum`), skips cleanly if compiler missing
- `scripts/claude/secret_guard.nim` is a PreToolUse Bash hook that gates commands **reading content from** sensitive paths — not anything that merely mentions one. Splits the command on shell chaining (`|`, `;`, `&`, backtick, `$(`); for each segment, denies when the leading program is a content-reader (`cat`/`bat`/`rg`/`head`/`cp`/`curl`/`scp`/`openssl`/`jq`/`tar`/etc.) AND the segment mentions a sensitive path. Non-readers (`ls`/`eza`/`stat`/`echo`/`printf`/`git commit`/`git log`/…) pass through regardless of argument contents — that's why `git commit -m "…about .env…"` no longer false-positives. Sensitive paths covered: SSH keys, `.env`/`.envrc`, cloud creds, age/sops, rclone/ngrok/fnox/Copilot tokens, atuin sync key. Known miss: `ls ~/.ssh/ | xargs cat` — per-segment reasoning can't correlate listings with downstream readers (a full shell parser would be needed).
- `scripts/claude/git_add_guard.nim` is a PreToolUse Bash hook that blocks bulk `git add` forms (`-A`, `--all`, `.`, `-u`, `--update`) to force explicit-path staging. Pass-through for `git add <path>`, `git add dir/`, `git add -p`, and non-`git add` commands. Trailing `(\s|$)` on each blocked pattern prevents `--all-hands` / `.bashrc` false-positives.
- `scripts/claude/git_readonly_guard.nim` is a PreToolUse Bash hook scoped via subagent frontmatter to `code-explorer` (NOT global). Splits the command on shell chaining (`|`, `;`, `&`, backtick, `$(`, newline); for each segment that starts with `git`, allows only the read-only verb allowlist (`log`, `diff`, `show`, `blame`, `status`, `reflog`, `shortlog`, `grep`, `ls-files`, `ls-tree`, `cat-file`, `rev-parse`, `rev-list`, `describe`, `name-rev`, `merge-base`); anything else returns `permissionDecision: "deny"`. Non-git segments pass through untouched. Compound commands like `true && git push` are caught because the splitter handles `&&`.

## Nim gotchas (this repo)
- Source filenames must be valid Nim identifiers — underscores, not hyphens (`secret_guard.nim`, NOT `secret-guard.nim`). Binary output name (`-o:`) can still use hyphens.
- `std/re` can't compile patterns at `const` time in Nim 2.2+ — use `let` for module-level regex
- `nph` lives in `~/.nimble/bin/`; once zshrc is applied, it's on PATH via `path=(${NIMBLE_DIR:-$HOME/.nimble}/bin $path)`. `nimble shellenv` is project-scoped — NOT for rc-file use.
- `std/md5` is deprecated in Nim 2.2+ (points at the `checksums` nimble pkg). Stdlib version still works — wrap the import in `{.push warning[Deprecated]: off.}` / `{.pop.}` if you don't want the extra dep.
- For Nim CLIs with args/subcommands, use `cligen` (`dispatch` or `dispatchMulti`). Build stanza must `nimble install -y cligen` before `nim c` — see the `notify` stanza in `run_onchange_build-scripts.sh.tmpl` for the `nimble path cligen || nimble install` guard pattern.
