## ast-grep (tree-sitter-bash) rules for the PreToolUse Bash guards.
##
## These are the structural replacements for the per-segment regex in the
## sibling `*_guard.nim` hooks. Each rule is a self-contained ast-grep YAML
## document with `language: bash`; a guard fires when ANY of its rules match
## (`ast_bash.anyFires`), or — for git-confirm, which needs to know WHICH rule
## fired to classify risk — via `ast_bash.firedRuleIds` over `combined(guard)`.
##
## Design notes proven against tree-sitter-bash CSTs (see test_ast_guards.nim):
##   * Env-prefixes (`FOO=bar git push`) parse as a `variable_assignment`
##     sibling of the `command`; `field: name` is still the real program. No
##     env-prefix stripping needed — AST handles it for free.
##   * Shell chaining / pipelines / command-substitution / backticks are all
##     proper subtrees, so `kind: command` matches at any nesting depth without
##     the regex split's dangling-paren artifacts.
##   * A flag inside double quotes (`git push "--force"`) parses as
##     `string > string_content`, NOT a `word`. Every flag check therefore
##     carries a second arm matching the exact `string_content`, or a quoted
##     flag would slip past — this is the structural form of the old
##     `dequoteFlag` regex.
##   * KNOWN GAPS (shared with the regex guards, NOT closed by AST):
##       - embedded shell in a quoted arg: `bash -c "git push --force"` — the
##         script body is opaque `string_content`, tree-sitter does not recurse.
##       - variable-indirect program name: `C=cat; $C ~/.ssh/id_rsa` — the
##         command_name is a `simple_expansion`, not a literal.
##       - cross-command dataflow: `ls ~/.ssh/ | xargs cat` — each command
##         parses cleanly, but "cat consumes what ls listed" is semantic.
##
## INVARIANT: every rule const's `id:` MUST equal its `ruleMeta` key, or the
## git-confirm union code defaults to a blank risk label for AST-only matches.

import std/[tables, strutils]

# ── wezterm-guard ──────────────────────────────────────────────────────────
const WeztermKill* = """
id: wezterm-kill
language: bash
rule:
  kind: command
  all:
    - has: { field: name, regex: '^wezterm$' }
    - has: { kind: word, regex: '^cli$', stopBy: end }
    - has: { kind: word, regex: '^kill-[a-z]+$', stopBy: end }
"""

# ── git-add-guard ──────────────────────────────────────────────────────────
# Bulk staging: -A / --all / -u / --update / bare `.`. The bare dot is an exact
# word match, so `git add .gitignore` and `git add ./src` (words `.gitignore`
# / `./src`) are NOT caught — no `(\s|$)` boundary hack required.
const GitAddBulk* = """
id: git-add-bulk
language: bash
rule:
  kind: command
  all:
    - has: { field: name, regex: '^git$' }
    - has: { kind: word, regex: '^add$', stopBy: end }
    - any:
        - has: { kind: word, regex: '^(-A|--all|-u|--update)$', stopBy: end }
        - has: { kind: word, regex: '^\.$', stopBy: end }
"""

# ── git-confirm-guard ──────────────────────────────────────────────────────
# Tier 1 — verb alone is enough.
const GitRewrite* = """
id: git-rewrite
language: bash
rule:
  kind: command
  all:
    - has: { field: name, regex: '^git$' }
    - has: { kind: word, regex: '^(rebase|filter-branch|filter-repo)$', stopBy: end }
"""

# Publishes / records state — plain commit or push (any form).
const GitCommitPush* = """
id: git-commit-push
language: bash
rule:
  kind: command
  all:
    - has: { field: name, regex: '^git$' }
    - has: { kind: word, regex: '^(commit|push)$', stopBy: end }
"""

# `git commit --amend` rewrites the last commit, so it leaves the ask-tier
# GitCommitPush set and joins the catastrophic history-rewrite tier. Amend also
# fires GitCommitPush (both match `commit`); firedRuleIds returns the union and
# the catastrophic flag is an anyIt, so the stricter rule wins.
const GitCommitAmend* = """
id: git-commit-amend
language: bash
rule:
  kind: command
  all:
    - has: { field: name, regex: '^git$' }
    - has: { kind: word, regex: '^commit$', stopBy: end }
    - any:
        - has: { kind: word, regex: '^--amend$', stopBy: end }
        - has: { kind: string_content, regex: '^--amend$', stopBy: end }
"""

# Universal --force on ANY subcommand (word or quoted). `--force-with-lease`
# is intentionally NOT matched here (longer word) — it is gated by the push
# rule, mirroring the regex guard's word-boundary carve-out.
const GitForce* = """
id: git-force
language: bash
rule:
  kind: command
  all:
    - has: { field: name, regex: '^git$' }
    - any:
        - has: { kind: word, regex: '^--force$', stopBy: end }
        - has: { kind: string_content, regex: '^--force$', stopBy: end }
"""

const GitResetHard* = """
id: git-reset-hard
language: bash
rule:
  kind: command
  all:
    - has: { field: name, regex: '^git$' }
    - has: { kind: word, regex: '^reset$', stopBy: end }
    - any:
        - has: { kind: word, regex: '^--hard$', stopBy: end }
        - has: { kind: string_content, regex: '^--hard$', stopBy: end }
"""

# Catastrophic remote push forms: force flags, +refspec / :refspec, delete,
# mirror. Plain fast-forward push stays out of this set (it is GitCommitPush,
# which is ask-tier, not catastrophic).
const GitPushDestructive* = """
id: git-push-destructive
language: bash
rule:
  kind: command
  all:
    - has: { field: name, regex: '^git$' }
    - has: { kind: word, regex: '^push$', stopBy: end }
    - any:
        - has: { kind: word, regex: '^(--force|--force-with-lease|-f|--delete|-d|--mirror)$', stopBy: end }
        - has: { kind: string_content, regex: '^(--force|--force-with-lease|-f)$', stopBy: end }
        - has: { kind: word, regex: '^[+:]', stopBy: end }
"""

# branch: force-clobber (catastrophic) vs delete (ask-tier) — split so the
# ruleId carries the distinction the never-allow tier depends on.
const GitBranchForce* = """
id: git-branch-force
language: bash
rule:
  kind: command
  all:
    - has: { field: name, regex: '^git$' }
    - has: { kind: word, regex: '^branch$', stopBy: end }
    - any:
        - has: { kind: word, regex: '^(-f|-M|--force)$', stopBy: end }
        - has: { kind: string_content, regex: '^(-f|-M|--force)$', stopBy: end }
"""

const GitBranchDelete* = """
id: git-branch-delete
language: bash
rule:
  kind: command
  all:
    - has: { field: name, regex: '^git$' }
    - has: { kind: word, regex: '^branch$', stopBy: end }
    - any:
        - has: { kind: word, regex: '^(-d|-D|--delete)$', stopBy: end }
        - has: { kind: string_content, regex: '^(-d|-D|--delete)$', stopBy: end }
"""

const GitTagForce* = """
id: git-tag-force
language: bash
rule:
  kind: command
  all:
    - has: { field: name, regex: '^git$' }
    - has: { kind: word, regex: '^tag$', stopBy: end }
    - any:
        - has: { kind: word, regex: '^(-f|--force)$', stopBy: end }
        - has: { kind: string_content, regex: '^(-f|--force)$', stopBy: end }
"""

const GitTagDelete* = """
id: git-tag-delete
language: bash
rule:
  kind: command
  all:
    - has: { field: name, regex: '^git$' }
    - has: { kind: word, regex: '^tag$', stopBy: end }
    - any:
        - has: { kind: word, regex: '^(-d|--delete)$', stopBy: end }
        - has: { kind: string_content, regex: '^(-d|--delete)$', stopBy: end }
"""

# clean is destructive in every form except the -n / --dry-run no-op.
const GitClean* = """
id: git-clean
language: bash
rule:
  kind: command
  all:
    - has: { field: name, regex: '^git$' }
    - has: { kind: word, regex: '^clean$', stopBy: end }
    - not:
        has: { kind: word, regex: '^(-n|--dry-run)$', stopBy: end }
"""

const GitStashDrop* = """
id: git-stash-drop
language: bash
rule:
  kind: command
  all:
    - has: { field: name, regex: '^git$' }
    - has: { kind: word, regex: '^stash$', stopBy: end }
    - has: { kind: word, regex: '^(drop|clear)$', stopBy: end }
"""

# stash pop — detected (ask-tier), recoverable, NOT catastrophic.
const GitStashPop* = """
id: git-stash-pop
language: bash
rule:
  kind: command
  all:
    - has: { field: name, regex: '^git$' }
    - has: { kind: word, regex: '^stash$', stopBy: end }
    - has: { kind: word, regex: '^pop$', stopBy: end }
"""

# stash push/save with an untracked-including flag.
const GitStashUntracked* = """
id: git-stash-untracked
language: bash
rule:
  kind: command
  all:
    - has: { field: name, regex: '^git$' }
    - has: { kind: word, regex: '^stash$', stopBy: end }
    - has: { kind: word, regex: '^(push|save)$', stopBy: end }
    - any:
        - has: { kind: word, regex: '^(-u|--include-untracked|-a|--all)$', stopBy: end }
        - has: { kind: string_content, regex: '^(-u|--include-untracked|-a|--all)$', stopBy: end }
"""

const GitCheckoutDiscard* = """
id: git-checkout-discard
language: bash
rule:
  kind: command
  all:
    - has: { field: name, regex: '^git$' }
    - has: { kind: word, regex: '^checkout$', stopBy: end }
    - any:
        - has: { kind: word, regex: '^(--|\.|-f|--force)$', stopBy: end }
        - has: { kind: string_content, regex: '^(--|-f|--force)$', stopBy: end }
"""

const GitRestore* = """
id: git-restore
language: bash
rule:
  kind: command
  all:
    - has: { field: name, regex: '^git$' }
    - has: { kind: word, regex: '^restore$', stopBy: end }
"""

const GitReflogDestroy* = """
id: git-reflog-destroy
language: bash
rule:
  kind: command
  all:
    - has: { field: name, regex: '^git$' }
    - has: { kind: word, regex: '^reflog$', stopBy: end }
    - has: { kind: word, regex: '^(expire|delete|clear)$', stopBy: end }
"""

const GitSwitchDiscard* = """
id: git-switch-discard
language: bash
rule:
  kind: command
  all:
    - has: { field: name, regex: '^git$' }
    - has: { kind: word, regex: '^switch$', stopBy: end }
    - any:
        - has: { kind: word, regex: '^(--discard-changes|-f|--force)$', stopBy: end }
        - has: { kind: string_content, regex: '^(--discard-changes|-f|--force)$', stopBy: end }
"""

# gc with an explicit --prune (immediate prune destroys the recovery path).
const GitGcPrune* = """
id: git-gc-prune
language: bash
rule:
  kind: command
  all:
    - has: { field: name, regex: '^git$' }
    - has: { kind: word, regex: '^gc$', stopBy: end }
    - has: { kind: word, regex: '^--prune', stopBy: end }
"""

# ── git-confirm tier-2 minors (ask-tier, not catastrophic) ─────────────────
const GitWorktreeRemove* = """
id: git-worktree-remove
language: bash
rule:
  kind: command
  all:
    - has: { field: name, regex: '^git$' }
    - has: { kind: word, regex: '^worktree$', stopBy: end }
    - has: { kind: word, regex: '^(remove|prune)$', stopBy: end }
"""

const GitConfigUnset* = """
id: git-config-unset
language: bash
rule:
  kind: command
  all:
    - has: { field: name, regex: '^git$' }
    - has: { kind: word, regex: '^config$', stopBy: end }
    - any:
        - has: { kind: word, regex: '^--unset', stopBy: end }
        - has: { kind: string_content, regex: '^--unset', stopBy: end }
"""

const GitRm* = """
id: git-rm
language: bash
rule:
  kind: command
  all:
    - has: { field: name, regex: '^git$' }
    - has: { kind: word, regex: '^rm$', stopBy: end }
"""

const GitUpdateRef* = """
id: git-update-ref
language: bash
rule:
  kind: command
  all:
    - has: { field: name, regex: '^git$' }
    - has: { kind: word, regex: '^update-ref$', stopBy: end }
    - any:
        - has: { kind: word, regex: '^(-d|--stdin)$', stopBy: end }
        - has: { kind: string_content, regex: '^(-d|--stdin)$', stopBy: end }
"""

const GitRemoteRemove* = """
id: git-remote-remove
language: bash
rule:
  kind: command
  all:
    - has: { field: name, regex: '^git$' }
    - has: { kind: word, regex: '^remote$', stopBy: end }
    - has: { kind: word, regex: '^(remove|rm)$', stopBy: end }
"""

const GitSubmoduleDeinit* = """
id: git-submodule-deinit
language: bash
rule:
  kind: command
  all:
    - has: { field: name, regex: '^git$' }
    - has: { kind: word, regex: '^submodule$', stopBy: end }
    - has: { kind: word, regex: '^deinit$', stopBy: end }
"""

const GitSymbolicRefDel* = """
id: git-symbolic-ref-del
language: bash
rule:
  kind: command
  all:
    - has: { field: name, regex: '^git$' }
    - has: { kind: word, regex: '^symbolic-ref$', stopBy: end }
    - any:
        - has: { kind: word, regex: '^-d$', stopBy: end }
        - has: { kind: string_content, regex: '^-d$', stopBy: end }
"""

const GitRerere* = """
id: git-rerere
language: bash
rule:
  kind: command
  all:
    - has: { field: name, regex: '^git$' }
    - has: { kind: word, regex: '^rerere$', stopBy: end }
    - has: { kind: word, regex: '^(clear|forget|gc)$', stopBy: end }
"""

const GitNotes* = """
id: git-notes
language: bash
rule:
  kind: command
  all:
    - has: { field: name, regex: '^git$' }
    - has: { kind: word, regex: '^notes$', stopBy: end }
    - has: { kind: word, regex: '^(prune|remove)$', stopBy: end }
"""

const GitReplace* = """
id: git-replace
language: bash
rule:
  kind: command
  all:
    - has: { field: name, regex: '^git$' }
    - has: { kind: word, regex: '^replace$', stopBy: end }
"""

# ── truncation-guard ───────────────────────────────────────────────────────
# Real output truncation: `head`/`tail` invoked as an actual program (the
# truncating command in a pipeline, e.g. `… | tail -40`). Keyed on `field:
# name`, so a `--tail` FLAG (`kubectl logs --tail=100`, `bd close … --tail 40`)
# parses as a `word` arg and does NOT match, and the literal word "tail" inside
# a heredoc / quoted string is `string_content` and does NOT match either.
# `memo … --tail N` is likewise not a head/tail command, so it passes free
# without the old leading-`memo` carve-out.
const PipeTruncate* = """
id: pipe-truncate
language: bash
rule:
  kind: command
  has: { field: name, regex: '^(head|tail)$' }
"""

# ── secret-guard (reference only — secret-guard stays on regex) ─────────────
# Content reader whose argument is a sensitive PATH (matched only as a `word`,
# deliberately NOT as string_content). Retained for the corpus that documents
# secret-guard's AST tradeoff; secret_guard.nim is NOT migrated.
const SecretReaderPath* = """
id: secret-reader-path
language: bash
rule:
  kind: command
  all:
    - has:
        field: name
        regex: '^(cat|bat|nl|tac|less|more|head|tail|rg|grep|egrep|fgrep|ag|ack|awk|sed|tr|cut|sort|uniq|wc|cp|mv|rsync|tar|zip|gzip|bzip2|xz|7z|openssl|xxd|od|base64|hexdump|strings|jq|jaq|yq|dasel|dd|split|md5|md5sum|shasum|sha1sum|sha256sum|sha512sum|gpg|age|curl|wget|scp|ssh-keygen)$'
    - has:
        kind: word
        regex: '(id_(rsa|ed25519|ecdsa|dsa)|\.pem$|\.p12$|\.pfx$|\.netrc|\.npmrc|\.pypirc|\.ssh/|\.aws/|\.gnupg/|\.config/(op|fnox|rclone|ngrok)/|/sops/age/|atuin/key|\.env$)'
        stopBy: end
"""

# ── metadata + combiner ────────────────────────────────────────────────────
type RuleInfo* = object
  label*: string ## risk label for the ask reason
  catastrophic*: bool ## never-auto-allow tier

# ruleId → (label, catastrophic). `let`, not `const`: toTable is a runtime proc.
# The catastrophic flags mirror git_confirm_guard.nim's catastrophicPatterns
# (:249-253) plus the cleanAny special case (:288); the catastrophic-parity
# test in test_ast_guards.nim enforces that they never under-mark.
let ruleMeta*: Table[string, RuleInfo] = {
  "git-rewrite": RuleInfo(label: "rewrites history", catastrophic: true),
  "git-commit-push": RuleInfo(label: "publishes / records state", catastrophic: false),
  "git-commit-amend": RuleInfo(label: "rewrites history", catastrophic: true),
  "git-force": RuleInfo(label: "--force flag", catastrophic: true),
  "git-reset-hard": RuleInfo(label: "destructive flag/arg", catastrophic: true),
  "git-push-destructive": RuleInfo(label: "destructive flag/arg", catastrophic: true),
  "git-branch-force": RuleInfo(label: "destructive flag/arg", catastrophic: true),
  "git-branch-delete": RuleInfo(label: "destructive flag/arg", catastrophic: false),
  "git-tag-force": RuleInfo(label: "destructive flag/arg", catastrophic: true),
  "git-tag-delete": RuleInfo(label: "destructive flag/arg", catastrophic: false),
  "git-clean": RuleInfo(label: "destructive flag/arg", catastrophic: true),
  "git-stash-drop": RuleInfo(label: "destructive flag/arg", catastrophic: true),
  "git-stash-pop": RuleInfo(label: "destructive flag/arg", catastrophic: false),
  "git-stash-untracked": RuleInfo(label: "destructive flag/arg", catastrophic: false),
  "git-checkout-discard": RuleInfo(label: "destructive flag/arg", catastrophic: true),
  "git-restore": RuleInfo(label: "destructive flag/arg", catastrophic: true),
  "git-reflog-destroy": RuleInfo(label: "destructive flag/arg", catastrophic: true),
  "git-switch-discard": RuleInfo(label: "destructive flag/arg", catastrophic: true),
  "git-gc-prune": RuleInfo(label: "destructive flag/arg", catastrophic: true),
  "git-worktree-remove": RuleInfo(label: "destructive flag/arg", catastrophic: false),
  "git-config-unset": RuleInfo(label: "destructive flag/arg", catastrophic: false),
  "git-rm": RuleInfo(label: "destructive flag/arg", catastrophic: false),
  "git-update-ref": RuleInfo(label: "destructive flag/arg", catastrophic: false),
  "git-remote-remove": RuleInfo(label: "destructive flag/arg", catastrophic: false),
  "git-submodule-deinit": RuleInfo(label: "destructive flag/arg", catastrophic: false),
  "git-symbolic-ref-del": RuleInfo(label: "destructive flag/arg", catastrophic: false),
  "git-rerere": RuleInfo(label: "destructive flag/arg", catastrophic: false),
  "git-notes": RuleInfo(label: "destructive flag/arg", catastrophic: false),
  "git-replace": RuleInfo(label: "destructive flag/arg", catastrophic: false),
}.toTable

# Guard → rule-set map. A guard fires when ANY of its rules match.
let guardRules*: Table[string, seq[string]] = {
  "wezterm": @[WeztermKill],
  "git-add": @[GitAddBulk],
  "git-confirm": @[
    GitRewrite, GitCommitPush, GitCommitAmend, GitForce, GitResetHard,
    GitPushDestructive, GitBranchForce, GitBranchDelete, GitTagForce, GitTagDelete,
    GitClean, GitStashDrop, GitStashPop, GitStashUntracked, GitCheckoutDiscard,
    GitRestore, GitReflogDestroy, GitSwitchDiscard, GitGcPrune, GitWorktreeRemove,
    GitConfigUnset, GitRm, GitUpdateRef, GitRemoteRemove, GitSubmoduleDeinit,
    GitSymbolicRefDel, GitRerere, GitNotes, GitReplace,
  ],
  "secret": @[SecretReaderPath],
  "truncation": @[PipeTruncate],
}.toTable

proc rulesFor*(guard: string): seq[string] =
  ## Rule set for a named guard. Raises KeyError on an unknown guard.
  guardRules[guard]

proc combined*(guard: string): string =
  ## Join a guard's rule consts into one multi-doc YAML for a single ast-grep
  ## spawn (`firedRuleIds`).
  guardRules[guard].join("\n---\n")
