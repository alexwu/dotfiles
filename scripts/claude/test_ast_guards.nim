## Corpus / regression suite for the ast-grep (tree-sitter-bash) guard rules.
##
## Each case is a (name, command, expected-fire) triple. `fires` is true when
## the guard SHOULD trip on that command. Cases are grouped:
##   * positives — real risky commands the guard must catch
##   * decoys    — string-literal / safe look-alikes it must ignore
##   * gaps      — KNOWN LIMITATIONS. The assertion captures AST's *actual*
##                 behavior (which may be a miss or a false-positive) so the
##                 suite documents the boundary and goes red if it ever shifts.
##
## Run: nim c -r scripts/claude/test_ast_guards.nim   (needs ast-grep on PATH)

import std/[unittest, sequtils, tables]
import ../lib/ast_bash
import ast_guard_rules

type Case = object
  name: string
  cmd: string
  fires: bool

proc guardFires(guard, cmd: string): bool =
  anyFires(rulesFor(guard), cmd)

proc firedCatastrophic(cmd: string): bool =
  ## Does any AST rule that fires on `cmd` map to a catastrophic ruleMeta entry?
  ## This is the AST side of the never-allow contract used by the parity test.
  firedRuleIds(combined("git-confirm"), cmd).anyIt(
    ruleMeta.getOrDefault(it).catastrophic
  )

template runCases(guard: string, cases: openArray[Case]) =
  for c in cases:
    checkpoint(guard & " :: " & c.name & " :: <" & c.cmd & ">")
    check guardFires(guard, c.cmd) == c.fires

# ── wezterm-guard ──────────────────────────────────────────────────────────
suite "wezterm-kill":
  test "positives":
    runCases(
      "wezterm",
      [
        Case(name: "bare kill-pane", cmd: "wezterm cli kill-pane", fires: true),
        Case(
          name: "with pane-id", cmd: "wezterm cli kill-pane --pane-id 3", fires: true
        ),
        Case(name: "future kill-tab", cmd: "wezterm cli kill-tab", fires: true),
        Case(
          name: "env-prefixed (AST: no strip needed)",
          cmd: "FOO=bar wezterm cli kill-pane",
          fires: true,
        ),
        Case(
          name: "chained after &&", cmd: "true && wezterm cli kill-pane", fires: true
        ),
        Case(
          name: "chained after ;", cmd: "echo hi; wezterm cli kill-pane", fires: true
        ),
        Case(
          name: "nested in substitution",
          cmd: "echo $(wezterm cli kill-pane)",
          fires: true,
        ),
      ],
    )

  test "decoys (must NOT fire)":
    runCases(
      "wezterm",
      [
        Case(
          name: "send-text dq string",
          cmd: "wezterm cli send-text \"kill-pane is text\"",
          fires: false,
        ),
        Case(
          name: "send-text sq string",
          cmd: "wezterm cli send-text 'run kill-pane'",
          fires: false,
        ),
        Case(name: "list subcommand", cmd: "wezterm cli list", fires: false),
        Case(name: "spawn subcommand", cmd: "wezterm cli spawn -- htop", fires: false),
        Case(
          name: "whole command echoed",
          cmd: "echo \"wezterm cli kill-pane\"",
          fires: false,
        ),
        Case(name: "missing cli word", cmd: "wezterm kill-pane", fires: false),
      ],
    )

  test "known gaps (AST shares these with regex)":
    runCases(
      "wezterm",
      [
        # embedded shell in a quoted arg — opaque string_content, no recursion.
        Case(
          name: "GAP embedded bash -c",
          cmd: "bash -c \"wezterm cli kill-pane\"",
          fires: false,
        ),
        # variable-indirect program name.
        Case(name: "GAP var-indirect", cmd: "W=wezterm; $W cli kill-pane", fires: false),
      ],
    )

# ── git-add-guard ──────────────────────────────────────────────────────────
suite "git-add-bulk":
  test "positives":
    runCases(
      "git-add",
      [
        Case(name: "-A", cmd: "git add -A", fires: true),
        Case(name: "--all", cmd: "git add --all", fires: true),
        Case(name: "bare dot", cmd: "git add .", fires: true),
        Case(name: "-u", cmd: "git add -u", fires: true),
        Case(name: "--update", cmd: "git add --update", fires: true),
        Case(name: "-A with path", cmd: "git add -A src/", fires: true),
        Case(name: "chained", cmd: "cd repo && git add .", fires: true),
      ],
    )

  test "decoys (must NOT fire)":
    runCases(
      "git-add",
      [
        Case(name: "explicit file", cmd: "git add file.txt", fires: false),
        Case(name: "explicit dir", cmd: "git add src/", fires: false),
        Case(name: "patch mode", cmd: "git add -p", fires: false),
        Case(name: "long patch", cmd: "git add --patch", fires: false),
        Case(name: "dotfile not dot", cmd: "git add .gitignore", fires: false),
        Case(name: "dot-slash path", cmd: "git add ./src", fires: false),
        Case(name: "string decoy", cmd: "echo \"git add .\"", fires: false),
        Case(name: "not git add", cmd: "git commit -m \"add --all\"", fires: false),
      ],
    )

# ── git-confirm-guard ──────────────────────────────────────────────────────
suite "git-confirm":
  test "positives — rewrite / publish":
    runCases(
      "git-confirm",
      [
        Case(name: "rebase -i", cmd: "git rebase -i HEAD~3", fires: true),
        Case(
          name: "filter-branch", cmd: "git filter-branch --tree-filter x", fires: true
        ),
        Case(name: "commit", cmd: "git commit -m x", fires: true),
        Case(name: "plain push", cmd: "git push", fires: true),
        Case(name: "push remote/branch", cmd: "git push origin main", fires: true),
      ],
    )

  test "positives — force / destructive flags":
    runCases(
      "git-confirm",
      [
        Case(name: "push --force", cmd: "git push --force", fires: true),
        Case(name: "push -f first", cmd: "git push -f origin main", fires: true),
        Case(name: "push +refspec", cmd: "git push origin +master", fires: true),
        Case(name: "push :delete-ref", cmd: "git push origin :oldbranch", fires: true),
        Case(name: "push --mirror", cmd: "git push --mirror backup", fires: true),
        Case(name: "reset --hard", cmd: "git reset --hard", fires: true),
        Case(name: "reset --hard ref", cmd: "git reset --hard HEAD~1", fires: true),
        Case(name: "branch -D", cmd: "git branch -D feature", fires: true),
        Case(name: "branch -M", cmd: "git branch -M main", fires: true),
        Case(name: "tag -d", cmd: "git tag -d v1", fires: true),
        Case(name: "clean -fd", cmd: "git clean -fd", fires: true),
        Case(name: "clean bare", cmd: "git clean", fires: true),
        Case(name: "stash drop", cmd: "git stash drop", fires: true),
        Case(name: "checkout -- file", cmd: "git checkout -- file.txt", fires: true),
        Case(name: "checkout .", cmd: "git checkout .", fires: true),
        Case(name: "restore", cmd: "git restore file.txt", fires: true),
        Case(name: "reflog expire", cmd: "git reflog expire --all", fires: true),
        Case(
          name: "switch --discard",
          cmd: "git switch --discard-changes main",
          fires: true,
        ),
        Case(name: "worktree remove", cmd: "git worktree remove wt", fires: true),
        Case(name: "config --unset", cmd: "git config --unset user.name", fires: true),
        Case(name: "rm", cmd: "git rm file.txt", fires: true),
      ],
    )

  test "positives — AST wins (global opts / env / nesting / quoting)":
    runCases(
      "git-confirm",
      [
        # `git -C <dir>` global opt before verb — free in AST, no re-anchor regex.
        Case(name: "git -C reset --hard", cmd: "git -C /repo reset --hard", fires: true),
        Case(
          name: "git -c reset --hard", cmd: "git -c core.x=1 reset --hard", fires: true
        ),
        # env-prefix — variable_assignment sibling, name still git.
        Case(
          name: "env-prefix rebase",
          cmd: "GIT_SEQUENCE_EDITOR=x git rebase -i HEAD~3",
          fires: true,
        ),
        # quoted flag — string_content arm catches it.
        Case(name: "quoted --force", cmd: "git push \"--force\"", fires: true),
        # nested in command substitution.
        Case(name: "nested push --force", cmd: "echo $(git push --force)", fires: true),
        # chained.
        Case(name: "chained reset --hard", cmd: "true && git reset --hard", fires: true),
      ],
    )

  test "decoys (must NOT fire)":
    runCases(
      "git-confirm",
      [
        Case(name: "status", cmd: "git status", fires: false),
        Case(name: "log", cmd: "git log --oneline", fires: false),
        Case(name: "diff", cmd: "git diff main..feature", fires: false),
        Case(name: "show", cmd: "git show HEAD", fires: false),
        Case(name: "fetch", cmd: "git fetch origin", fires: false),
        Case(name: "branch list", cmd: "git branch -a", fires: false),
        Case(name: "tag create", cmd: "git tag v2", fires: false),
        Case(name: "tag annotated", cmd: "git tag -a v2 -m note", fires: false),
        Case(name: "clean dry-run", cmd: "git clean -n", fires: false),
        Case(name: "clean --dry-run", cmd: "git clean --dry-run", fires: false),
        Case(name: "checkout branch", cmd: "git checkout main", fires: false),
        Case(name: "checkout -b", cmd: "git checkout -b feature", fires: false),
        Case(name: "stash list", cmd: "git stash list", fires: false),
        # destructive words live INSIDE a string arg — not real words.
        Case(
          name: "reset words in -G string",
          cmd: "git diff -G \"reset --hard\"",
          fires: false,
        ),
        Case(
          name: "whole command echoed", cmd: "echo \"git push --force\"", fires: false
        ),
      ],
    )

  test "known gaps":
    runCases(
      "git-confirm",
      [
        # embedded shell — opaque string body.
        Case(name: "GAP bash -c", cmd: "bash -c \"git push --force\"", fires: false),
        Case(name: "GAP eval", cmd: "eval \"git reset --hard\"", fires: false),
        # loose verb matching: `reset`+`--hard` appear as args to `git log`.
        # The regex guard anchors the verb position and would NOT fire here;
        # the current AST rule matches the words anywhere and over-fires.
        # Tradeoff: this same looseness is what makes `git -C … reset --hard`
        # work for free. Closing it needs first-arg (verb-position) anchoring.
        Case(
          name: "GAP verb-position over-match", cmd: "git log reset --hard", fires: true
        ),
      ],
    )

# ── secret-guard (reader + sensitive path) ─────────────────────────────────
suite "secret-reader-path":
  test "positives":
    runCases(
      "secret",
      [
        Case(name: "cat ssh key", cmd: "cat ~/.ssh/id_rsa", fires: true),
        Case(name: "bat env", cmd: "bat .env", fires: true),
        Case(name: "rg aws creds", cmd: "rg key ~/.aws/credentials", fires: true),
        Case(name: "cp ed25519", cmd: "cp ~/.ssh/id_ed25519 /tmp/", fires: true),
        Case(
          name: "base64 rclone", cmd: "base64 ~/.config/rclone/rclone.conf", fires: true
        ),
        Case(name: "absolute ssh path", cmd: "cat /home/u/.ssh/id_rsa", fires: true),
      ],
    )

  test "decoys (must NOT fire)":
    runCases(
      "secret",
      [
        Case(name: "ls not a reader", cmd: "ls ~/.ssh/", fires: false),
        Case(name: "eza not a reader", cmd: "eza ~/.ssh/", fires: false),
        Case(name: "stat not a reader", cmd: "stat ~/.ssh/id_rsa", fires: false),
        Case(
          name: "git commit msg",
          cmd: "git commit -m \"about .env files\"",
          fires: false,
        ),
        Case(name: "whole cmd echoed", cmd: "echo \"cat ~/.ssh/id_rsa\"", fires: false),
        Case(name: "no sensitive path", cmd: "cat README.md", fires: false),
        Case(name: ".env.example allowed", cmd: "cat .env.example", fires: false),
        # THE headline FP fix: id_rsa is the search PATTERN (a string), the real
        # path arg is README — substring-regex would deny, AST does not.
        Case(
          name: "id_rsa in rg pattern string",
          cmd: "rg \"search id_rsa\" README.md",
          fires: false,
        ),
      ],
    )

  test "known gaps (secret-guard is the weakest AST candidate)":
    runCases(
      "secret",
      [
        # Quoted real path: AST sees a string, not a path word → MISS. The
        # current substring-regex catches this. Direct AST regression.
        Case(name: "GAP quoted real path", cmd: "cat \"~/.ssh/id_rsa\"", fires: false),
        # Unquoted pattern that equals a secret name → FALSE POSITIVE. Neither
        # AST nor the current regex can tell pattern-arg from path-arg.
        Case(name: "GAP unquoted pattern == secret", cmd: "rg id_rsa .", fires: true),
        # Cross-command dataflow — both commands parse, correlation is semantic.
        Case(name: "GAP xargs correlation", cmd: "ls ~/.ssh/ | xargs cat", fires: false),
      ],
    )

# ── git-confirm: branch/tag force-vs-delete split + tier-2 parity ───────────
suite "git-confirm tier-2 + split":
  test "branch/tag split — force AND delete both fire":
    runCases(
      "git-confirm",
      [
        Case(name: "branch -D", cmd: "git branch -D feature", fires: true),
        Case(name: "branch -f", cmd: "git branch -f main other", fires: true),
        Case(name: "branch -M", cmd: "git branch -M main", fires: true),
        Case(name: "tag -d", cmd: "git tag -d v1", fires: true),
        Case(name: "tag -f", cmd: "git tag -f v1", fires: true),
        Case(name: "branch list -a stays quiet", cmd: "git branch -a", fires: false),
        Case(
          name: "tag annotated stays quiet", cmd: "git tag -a v2 -m note", fires: false
        ),
      ],
    )

  test "tier-2 parity rules fire":
    runCases(
      "git-confirm",
      [
        Case(name: "stash pop", cmd: "git stash pop", fires: true),
        Case(name: "stash push -u", cmd: "git stash push -u -m wip", fires: true),
        Case(name: "stash save --all", cmd: "git stash save --all", fires: true),
        Case(name: "gc --prune=now", cmd: "git gc --prune=now", fires: true),
        Case(name: "update-ref -d", cmd: "git update-ref -d refs/heads/x", fires: true),
        Case(name: "update-ref --stdin", cmd: "git update-ref --stdin", fires: true),
        Case(name: "remote remove", cmd: "git remote remove origin", fires: true),
        Case(name: "remote rm", cmd: "git remote rm origin", fires: true),
        Case(name: "submodule deinit", cmd: "git submodule deinit lib", fires: true),
        Case(name: "symbolic-ref -d", cmd: "git symbolic-ref -d HEAD", fires: true),
        Case(name: "rerere forget", cmd: "git rerere forget path", fires: true),
        Case(name: "notes remove", cmd: "git notes remove", fires: true),
        Case(name: "replace", cmd: "git replace a b", fires: true),
      ],
    )

  test "tier-2 decoys stay quiet":
    runCases(
      "git-confirm",
      [
        Case(name: "stash plain", cmd: "git stash", fires: false),
        Case(name: "stash show", cmd: "git stash show", fires: false),
        Case(name: "remote -v", cmd: "git remote -v", fires: false),
        Case(name: "notes list", cmd: "git notes list", fires: false),
        Case(name: "gc plain", cmd: "git gc", fires: false),
        Case(name: "submodule update", cmd: "git submodule update --init", fires: false),
      ],
    )

# ── git-confirm: catastrophic parity (REQUIRED — gates ship) ────────────────
# Asserts the AST catastrophic classification (firedCatastrophic, via ruleMeta)
# never UNDER-marks vs the regex never-allow contract. Each command below maps
# to a catastrophicPatterns entry (git_confirm_guard.nim:249-253) or the
# cleanAny special case (:288). A red here = ruleMeta drifted; do not ship.
const catastrophicCorpus = [
  "git rebase -i HEAD~3", # tier1Verbs
  "git filter-branch --tree-filter x HEAD", # tier1Verbs
  "git filter-repo --path x", # tier1Verbs
  "git push --force", # forceFlag / pushForceFlags
  "git push -f origin main", # pushForceFlags
  "git push --force-with-lease origin", # pushForceFlags
  "git push origin +master", # pushPlusRefspec
  "git push origin :oldbranch", # pushColonRef
  "git push --delete origin x", # pushDelete
  "git push -d origin x", # pushDelete
  "git push --mirror backup", # pushMirror
  "git reset --hard", # resetHard
  "git reset --hard HEAD~1", # resetHard
  "git checkout -- file.txt", # checkoutDiscard
  "git checkout .", # checkoutDiscard
  "git checkout -f", # checkoutForce
  "git restore file.txt", # restoreAny
  "git switch --discard-changes main", # switchDiscard
  "git stash drop", # stashDropClear
  "git stash clear", # stashDropClear
  "git reflog expire --all", # reflogDestroy
  "git gc --prune=now", # gcPrune
  "git branch -f main other", # branchForce
  "git branch -M main", # branchForce
  "git tag -f v1", # tagForce
  "git clean -fd", # cleanAny
  "git clean", # cleanAny
  "git -C /repo reset --hard", # global-opt + resetHard (AST free)
  "echo $(git push --force)", # nested — regex misses, AST must still mark catastrophic
]

suite "git-confirm catastrophic parity":
  test "AST never under-marks the never-allow tier":
    for cmd in catastrophicCorpus:
      checkpoint("parity :: " & cmd)
      check firedCatastrophic(cmd)

  test "ask-tier commands are NOT marked catastrophic":
    # Inverse spot-check: publish/delete-tier ops fire but must stay auto-allowable.
    for cmd in [
      "git commit -m x", "git push", "git push origin main", "git branch -D feature",
      "git tag -d v1", "git stash pop", "git rm file.txt",
      "git config --unset user.name",
    ]:
      checkpoint("non-catastrophic :: " & cmd)
      check not firedCatastrophic(cmd)
