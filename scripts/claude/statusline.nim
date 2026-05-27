## Claude Code status line - two-line, capsule-styled status bar.
##
## Reads JSON from stdin per https://code.claude.com/docs/en/statusline.md
## and emits ANSI-colored UTF-8 to stdout. Powerline rounded caps and
## nerd-font icons assume a nerd-font terminal.
##
## Layout
##   Line 1: [vim mode] [git branch+dirty] [cwd] [repo owner/name] [worktree] [PR]
##   Line 2: [model] [context bar %] [5h:N% 7d:N% | $cost] [duration] [effort/thinking] [agent]
##
## Each segment is independently optional - absent JSON fields hide the
## capsule rather than render a stub.
##
## Vim mode colors mirror dot_config/nvim/lua/plugins/ui.lua (snazzy
## palette) so the leftmost capsule matches Neovim. Pair with
## `hideVimModeIndicator: true` in claude-settings.json so the built-in
## indicator does not double-render.
##
## Cost vs rate_limits: mutually exclusive. `rate_limits` is only
## populated for Claude.ai Pro/Max subscribers after the first API
## response. When present, show 5h/7d percentages and hide cost. When
## absent (API billing or pre-first-response), fall back to
## `cost.total_cost_usd`.
##
## Caching
##   Git status is cached to /tmp/claude-statusline-<session_id>.json with
##   a 5s TTL. `session_id` from the JSON input is the cache key - stable
##   for the session, unique across concurrent sessions.
##
## Performance
##   Compiled with `-d:release --opt:size`, cold-starts in ~1-2 ms. One
##   `git status --porcelain -b` call when the cache misses; zero
##   subprocess work on cache hits.

import std/[options, os, osproc, strformat, strutils, terminal, times, unicode]
import std/json as stdjson
import json_serialization
import json_serialization/std/options as jsOptions

# ===========================================================================
# GLYPH CUSTOMIZATION
#
# All non-ASCII glyphs live here as named constants using \uXXXX escape
# sequences. If a glyph renders as a box, '?', or the wrong shape in your
# terminal, look up the right codepoint on the Nerd Fonts cheat sheet
# (https://www.nerdfonts.com/cheat-sheet) and replace the hex digits below.
# The slug in the comment is what to search for on the cheat sheet.
#
# Powerline glyphs require the powerline-extra-symbols subset of Nerd
# Fonts. \uXXXX = 4-hex BMP codepoint, \UXXXXXXXX = 8-hex SMP codepoint.
# ===========================================================================

const
  # --- Capsule caps (Powerline Extra Symbols) ------------------------------
  # These are the rounded pill caps that bookend each segment. The lualine
  # config in dot_config/nvim/lua/plugins/ui.lua uses these same glyphs in
  # `section_separators = { left, right }`.
  capLeft  = ""   # nf-pl-left_soft_divider   (filled rounded left)
  capRight = ""   # nf-pl-right_soft_divider  (filled rounded right)
  # Thin variants (swap in if you prefer hairline caps):
  #   capLeft  = ""   # nf-pl-left_soft_divider_thin
  #   capRight = ""   # nf-pl-right_soft_divider_thin

  # --- Section icons (Nerd Font glyphs - private use area) -----------------
  iconBranch   = ""   # nf-pl-branch
  iconFolder   = ""   # nf-fa-folder
  iconGitHub   = ""   # nf-fa-github
  iconPR       = ""   # nf-oct-git_pull_request
  iconCheck    = ""   # nf-fa-check               (PR approved)
  iconCross    = ""   # nf-fa-times               (PR changes_requested)
  iconWarn     = ""   # nf-fa-warning             (PR pending)
  iconDraft    = ""   # nf-fa-circle              (PR draft)
  iconWorktree = ""   # nf-dev-git_branch         (worktree marker)

  # --- Section icons (standard Unicode - work in any UTF-8 terminal) -------
  iconClock = "⏱"       # STOPWATCH                  (duration)
  iconBolt  = "⚡"       # HIGH VOLTAGE SIGN          (effort level)
  # Nim's string literals support \uHHHH (BMP up to U+FFFF) only — SMP
  # codepoints are written as their UTF-8 byte sequence using \xHH escapes.
  iconBrain = "\xF0\x9F\xA7\xA0"  # U+1F9E0 BRAIN              (thinking enabled)
  iconFlame = "\xF0\x9F\x94\xA5"  # U+1F525 FIRE               (>200k tokens warning)
  iconBot   = "\xF0\x9F\xA4\x96"  # U+1F916 ROBOT FACE         (agent name)

  # --- Dirty-state markers -------------------------------------------------
  markStaged    = "↑"   # UPWARDS ARROW              (staged file count)
  markModified  = "~"        # ASCII tilde                (modified file count)
  markUntracked = "?"        # ASCII question mark        (untracked count)

  # --- Bar glyphs ----------------------------------------------------------
  barFilled = "█"       # FULL BLOCK
  barEmpty  = "░"       # LIGHT SHADE

# ===========================================================================
# SNAZZY PALETTE
# Truecolor "R;G;B" strings - splice directly into SGR sequences. Mirrors
# the `colors` table in dot_config/nvim/lua/plugins/ui.lua.
# ===========================================================================

const
  cBlack     = "40;42;54"     # #282a36
  cRed       = "255;92;87"    # #ff5c57
  cGreen     = "90;247;142"   # #5af78e
  cYellow    = "243;249;157"  # #f3f99d
  cBlue      = "87;199;255"   # #57c7ff
  cPurple    = "255;106;193"  # #ff6ac1
  cCyan      = "154;237;254"  # #9aedfe
  cWhite     = "241;241;240"  # #f1f1f0
  cLightGray = "177;177;177"  # #b1b1b1
  cDarkGray  = "58;61;77"     # #3a3d4d

# ANSI SGR primitives.
const
  sgrReset = "\e[0m"
  sgrBold  = "\e[1m"

proc fg(c: string): string = "\e[38;2;" & c & "m"
proc bg(c: string): string = "\e[48;2;" & c & "m"

# ===========================================================================
# JSON SCHEMA
# Every field is Option[T] - absent JSON fields decode as None, present-
# but-null fields also decode as None (see json_serialization/std/options).
# `allowUnknownFields = true` so future Claude Code releases adding fields
# do not break decoding.
# ===========================================================================

type
  Model* = object
    id*: Option[string]
    display_name*: Option[string]

  Repo* = object
    host*: Option[string]
    owner*: Option[string]
    name*: Option[string]

  Workspace* = object
    current_dir*: Option[string]
    project_dir*: Option[string]
    git_worktree*: Option[string]
    repo*: Option[Repo]

  Cost* = object
    total_cost_usd*: Option[float]
    total_duration_ms*: Option[int]
    total_api_duration_ms*: Option[int]
    total_lines_added*: Option[int]
    total_lines_removed*: Option[int]

  ContextWindow* = object
    total_input_tokens*: Option[int]
    total_output_tokens*: Option[int]
    context_window_size*: Option[int]
    used_percentage*: Option[float]
    remaining_percentage*: Option[float]

  RateLimit* = object
    used_percentage*: Option[float]
    resets_at*: Option[int]

  RateLimits* = object
    five_hour*: Option[RateLimit]
    seven_day*: Option[RateLimit]

  PR* = object
    number*: Option[int]
    url*: Option[string]
    review_state*: Option[string]

  Worktree* = object
    name*: Option[string]
    path*: Option[string]
    branch*: Option[string]
    original_cwd*: Option[string]
    original_branch*: Option[string]

  VimInfo* = object
    mode*: Option[string]

  Effort* = object
    level*: Option[string]

  Thinking* = object
    enabled*: Option[bool]

  Agent* = object
    name*: Option[string]

  OutputStyle* = object
    name*: Option[string]

  StatuslineInput* = object
    session_id*: Option[string]
    session_name*: Option[string]
    cwd*: Option[string]
    transcript_path*: Option[string]
    version*: Option[string]
    model*: Option[Model]
    workspace*: Option[Workspace]
    cost*: Option[Cost]
    context_window*: Option[ContextWindow]
    exceeds_200k_tokens*: Option[bool]
    rate_limits*: Option[RateLimits]
    pr*: Option[PR]
    worktree*: Option[Worktree]
    vim*: Option[VimInfo]
    effort*: Option[Effort]
    thinking*: Option[Thinking]
    agent*: Option[Agent]
    output_style*: Option[OutputStyle]

proc parseInput(raw: string): StatuslineInput =
  if raw.len == 0:
    return StatuslineInput()
  try:
    Json.decode(raw, StatuslineInput, allowUnknownFields = true)
  except SerializationError, IOError:
    StatuslineInput()

# Small helper: Option[T].orElse(default) without the .isSome ladder at
# every call site.
proc orElse[T](o: Option[T], d: T): T =
  if o.isSome: o.get else: d

# ===========================================================================
# Capsule rendering
# Each capsule is self-contained: fg-colored left/right caps on the
# terminal's default background, with a bg-colored padded body. Adjacent
# capsules touch tip-to-tip; absent ones disappear without leaving a gap.
# ===========================================================================

proc capsule(bgColor, fgColor, text: string, bold = false): string =
  let boldSeq = if bold: sgrBold else: ""
  result = fg(bgColor) & capLeft
  result.add bg(bgColor) & fg(fgColor) & boldSeq & " " & text & " " & sgrReset
  result.add fg(bgColor) & capRight & sgrReset

# Plain colored text — fg only, no background, no caps. Used for the
# "content" segments that don't benefit from being anchored as capsules.
proc plain(fgColor, text: string, bold = false): string =
  let boldSeq = if bold: sgrBold else: ""
  fg(fgColor) & boldSeq & text & sgrReset

proc osc8Wrap(url, body: string): string =
  "\e]8;;" & url & "\x07" & body & "\e]8;;\x07"

# Separator between sibling segments. Three spaces matches the yazi
# reference statusline — quiet, no glyph dependency.
const segSep = "   "

# Reserve this many columns on the far right for Claude Code's own
# notifications (MCP errors, auto-update banners, "context low" warning).
# Tune this default here, or override at runtime with the
# CLAUDE_STATUSLINE_RIGHT_BUFFER env var.
const rightBufferDefault = 10

proc rightBuffer(): int =
  let raw = getEnv("CLAUDE_STATUSLINE_RIGHT_BUFFER", "")
  if raw.len > 0:
    try:
      let n = parseInt(raw)
      if n >= 0: return n
    except ValueError: discard
  rightBufferDefault

# Fallback terminal width when both $COLUMNS and ioctl detection fail.
const widthFallback = 120

# ===========================================================================
# Width helpers — strip ANSI/OSC, measure visible width with a coarse
# wide-char approximation, right-align by padding.
# ===========================================================================

proc stripAnsi(s: string): string =
  ## Remove SGR (\e[...m) and OSC 8 hyperlink (\e]8;;...\x07) sequences so
  ## the remainder can be width-measured.
  result = newStringOfCap(s.len)
  var i = 0
  while i < s.len:
    if s[i] == '\e' and i + 1 < s.len:
      case s[i + 1]
      of '[':
        # SGR — scan to terminating 'm' (or any final byte 0x40..0x7E).
        var j = i + 2
        while j < s.len and (s[j] < '\x40' or s[j] > '\x7E'): inc j
        i = j + 1
      of ']':
        # OSC — scan to BEL (\x07) or ST (\e\\).
        var j = i + 2
        while j < s.len:
          if s[j] == '\x07':
            inc j; break
          if s[j] == '\e' and j + 1 < s.len and s[j + 1] == '\\':
            j += 2; break
          inc j
        i = j
      else:
        inc i
    else:
      result.add s[i]
      inc i

proc runeWidth(cp: int32): int =
  ## Coarse East-Asian / emoji width approximation. Most terminals render
  ## these ranges as 2 columns; PUA Nerd Font glyphs render as 1.
  if cp < 0x80: return 1                          # ASCII fast path
  if cp >= 0x1F000 and cp <= 0x1FFFF: return 2    # SMP emoji
  if cp >= 0x2300 and cp <= 0x23FF: return 2      # Misc technical (⏱)
  if cp >= 0x2600 and cp <= 0x27BF: return 2      # Misc symbols/dingbats (⚡)
  if cp >= 0x3000 and cp <= 0x9FFF: return 2      # CJK
  if cp >= 0xFF00 and cp <= 0xFFEF: return 2      # Halfwidth/Fullwidth forms
  1                                               # everything else: 1 col

proc visualWidth(s: string): int =
  for r in stripAnsi(s).runes:
    result += runeWidth(int32(r))

proc detectWidthViaWezterm(): int =
  ## Query the WezTerm GUI directly via `wezterm cli list --format json`,
  ## matching $WEZTERM_PANE against the pane_id field. Works regardless of
  ## stdin/stdout piping because we ask the mux, not the local TTY.
  ## ~8 ms shellout; acceptable for 1 Hz refresh.
  let paneId = getEnv("WEZTERM_PANE", "")
  if paneId.len == 0: return 0
  let targetPid =
    try: parseInt(paneId)
    except ValueError: return 0
  try:
    let (output, code) = execCmdEx("wezterm cli list --format json 2>/dev/null")
    if code != 0: return 0
    let j = stdjson.parseJson(output)
    if j.kind == JArray:
      for entry in j:
        if entry{"pane_id"}.getInt(-1) == targetPid:
          let cols = entry{"size"}{"cols"}.getInt(0)
          if cols > 0: return cols
  except CatchableError: discard
  0

proc detectWidth(): int =
  ## Sources, in priority order:
  ##   1. CLAUDE_STATUSLINE_WIDTH env var — explicit user override
  ##   2. wezterm cli (when $WEZTERM_PANE is set) — most reliable inside
  ##      WezTerm since it queries the mux directly, bypassing TTY issues
  ##   3. `stty size </dev/tty` — works when controlling terminal survives
  ##   4. $COLUMNS env var — often 0 or absent in piped contexts
  ##   5. terminalWidth() (ioctl on stdout) — usually fails when piped
  ##   6. widthFallback constant
  let override = getEnv("CLAUDE_STATUSLINE_WIDTH", "")
  if override.len > 0:
    try:
      let n = parseInt(override)
      if n > 0: return n
    except ValueError: discard
  let wezW = detectWidthViaWezterm()
  if wezW > 0: return wezW
  try:
    let (output, code) = execCmdEx("stty size </dev/tty 2>/dev/null")
    if code == 0:
      let parts = output.strip().split(' ')
      if parts.len >= 2:
        try:
          let cols = parseInt(parts[1])
          if cols > 0: return cols
        except ValueError: discard
  except CatchableError: discard
  let envCols = getEnv("COLUMNS", "")
  if envCols.len > 0:
    try:
      let n = parseInt(envCols)
      if n > 0: return n
    except ValueError: discard
  try:
    let w = terminalWidth()
    if w > 0: return w
  except CatchableError: discard
  widthFallback

proc joinLine(leftSegs, rightSegs: seq[string], termWidth: int): string =
  ## Combine left and right segment groups into one line. Pads the gap
  ## between them so the right group lands at `termWidth - rightBuffer()`.
  ## Falls back to a single flowing left line when there is not enough
  ## room to separate the two groups.
  let left = leftSegs.join(segSep)
  let right = rightSegs.join(segSep)
  if right.len == 0: return left
  if left.len == 0:
    # Nothing on the left — pad to push the right group all the way over.
    let pad = max(termWidth - rightBuffer() - visualWidth(right), 0)
    return " ".repeat(pad) & right
  let leftW = visualWidth(left)
  let rightW = visualWidth(right)
  let usable = termWidth - rightBuffer()
  let pad = usable - leftW - rightW
  if pad < 3:
    return left & segSep & right        # not enough room — flow left
  return left & " ".repeat(pad) & right

# ===========================================================================
# Helpers
# ===========================================================================

proc shortenPath(path: string): string =
  if path.len == 0: return ""
  let home = getHomeDir()                       # has trailing slash
  let homeNoSlash = home[0 ..< home.len - 1]
  if path == homeNoSlash or path == home: return "~"
  if path.startsWith(home): return "~/" & path[home.len .. ^1]
  path

proc formatDuration(ms: int): string =
  let totalSec = ms div 1000
  let h = totalSec div 3600
  let m = (totalSec mod 3600) div 60
  let s = totalSec mod 60
  if h > 0:   fmt"{h}h {m}m"
  elif m > 0: fmt"{m}m {s}s"
  else:       fmt"{s}s"

proc humanTokens(n: int): string =
  ## Compact token-count formatter: 260000 -> "260K", 1000000 -> "1M".
  ## Matches the unit suffixes ccstatusline / claude-pace use.
  if n >= 1_000_000:
    let m = n.float / 1_000_000.0
    if m - m.int.float < 0.05: $m.int & "M" else: fmt"{m:.1f}M"
  elif n >= 1000:
    let k = n.float / 1000.0
    if k - k.int.float < 0.5: $k.int & "K" else: fmt"{k:.1f}K"
  else:
    $n

proc vimModeColor(mode: string): string =
  case mode.toUpperAscii
  of "NORMAL": cBlue
  of "INSERT": cGreen
  of "VISUAL", "VISUAL LINE", "VISUAL BLOCK", "V-LINE", "V-BLOCK": cPurple
  of "REPLACE": cRed
  of "COMMAND": cYellow
  else: cBlue

proc reviewStateColor(state: string): string =
  case state
  of "approved": cGreen
  of "changes_requested": cRed
  of "draft": cLightGray
  else: cYellow                                 # pending / unknown

proc reviewStateIcon(state: string): string =
  case state
  of "approved": iconCheck
  of "changes_requested": iconCross
  of "draft": iconDraft
  else: iconWarn                                # pending

# ===========================================================================
# Git cache - /tmp/claude-statusline-<sid>.json, 5 s TTL
# Internal state file -> std/json is fine here; the typed schema above is
# reserved for the external Claude Code input.
# ===========================================================================

const cacheTTL = 5

type GitState = object
  inRepo: bool
  branch: string
  staged: int
  modified: int
  untracked: int

proc cachePath(sessionId: string): string =
  "/tmp/claude-statusline-" & sessionId & ".json"

proc loadCache(sessionId: string): (bool, GitState) =
  let path = cachePath(sessionId)
  if not fileExists(path): return (false, GitState())
  try:
    let info = getFileInfo(path)
    if (getTime() - info.lastWriteTime).inSeconds > cacheTTL:
      return (false, GitState())
    let j = stdjson.parseJson(readFile(path))
    var s: GitState
    s.inRepo    = j{"in_repo"}.getBool(false)
    s.branch    = j{"branch"}.getStr("")
    s.staged    = j{"staged"}.getInt(0)
    s.modified  = j{"modified"}.getInt(0)
    s.untracked = j{"untracked"}.getInt(0)
    (true, s)
  except CatchableError:
    (false, GitState())

proc saveCache(sessionId: string, s: GitState) =
  try:
    writeFile(cachePath(sessionId), $(%*{
      "in_repo": s.inRepo, "branch": s.branch,
      "staged": s.staged, "modified": s.modified, "untracked": s.untracked,
    }))
  except CatchableError:
    discard

# ===========================================================================
# Git inspection - one porcelain call when the cache misses
# ===========================================================================

proc gatherGit(cwd: string): GitState =
  # GIT_OPTIONAL_LOCKS=0 — read-only status; never acquire .git/index.lock.
  # Statusline gets SIGKILLed mid-render on session shutdown; without this,
  # killed git-status invocations leave 0-byte index.lock orphans that block
  # subsequent commits across the repo (and into submodules via recursion).
  let q = quoteShell(cwd)
  let (output, code) = execCmdEx(
    "GIT_OPTIONAL_LOCKS=0 git -C " & q & " status --porcelain=v1 -b 2>/dev/null"
  )
  if code != 0: return GitState(inRepo: false)
  result.inRepo = true
  let lines = output.splitLines()
  for i, line in lines:
    if i == 0:
      # First line: "## branch...upstream [ahead/behind]" or "## HEAD (no branch)"
      if line.startsWith("## "):
        let rest = line[3 .. ^1]
        let dots = rest.find("...")
        result.branch =
          if dots > 0: rest[0 ..< dots]
          else: rest.split(' ')[0]
      continue
    if line.len < 2: continue
    let x = line[0]
    let y = line[1]
    if x == '?' and y == '?':
      inc result.untracked
    else:
      if x != ' ' and x != '?': inc result.staged
      if y != ' ' and y != '?': inc result.modified

proc git(sessionId, cwd: string): GitState =
  let (hit, cached) = loadCache(sessionId)
  if hit: return cached
  result = gatherGit(cwd)
  saveCache(sessionId, result)

# ===========================================================================
# Line 1 - identity row
# ===========================================================================

proc renderLine1(input: StatuslineInput, g: GitState):
                tuple[left, right: seq[string]] =
  # --- LEFT GROUP -----------------------------------------------------------

  # Vim mode — capsule (anchor indicator)
  if input.vim.isSome:
    let mode = input.vim.get.mode.orElse("")
    if mode.len > 0:
      result.left.add capsule(vimModeColor(mode), cBlack, mode, bold = true)

  # Git branch + dirty counts — plain colored text.
  if g.inRepo and g.branch.len > 0:
    var parts = @[plain(cLightGray, iconBranch & " " & g.branch)]
    if g.staged > 0:    parts.add plain(cGreen,  markStaged & $g.staged)
    if g.modified > 0:  parts.add plain(cYellow, markModified & $g.modified)
    if g.untracked > 0: parts.add plain(cBlue,   markUntracked & $g.untracked)
    result.left.add parts.join(" ")

  # CWD (~-shortened) — plain white text
  let cwdRaw =
    if input.workspace.isSome and input.workspace.get.current_dir.isSome:
      input.workspace.get.current_dir.get
    else:
      input.cwd.orElse("")
  if cwdRaw.len > 0:
    result.left.add plain(cWhite, iconFolder & " " & shortenPath(cwdRaw))

  # --- RIGHT GROUP ----------------------------------------------------------

  # Worktree — plain cyan text
  let wtName =
    if input.worktree.isSome and input.worktree.get.name.isSome:
      input.worktree.get.name.get
    elif input.workspace.isSome and input.workspace.get.git_worktree.isSome:
      input.workspace.get.git_worktree.get
    else: ""
  if wtName.len > 0:
    result.right.add plain(cCyan, iconWorktree & " " & wtName)

  # Repo identity — plain purple text
  if input.workspace.isSome and input.workspace.get.repo.isSome:
    let repo = input.workspace.get.repo.get
    let owner = repo.owner.orElse("")
    let name = repo.name.orElse("")
    if owner.len > 0 and name.len > 0:
      result.right.add plain(cPurple, iconGitHub & " " & owner & "/" & name)

  # PR badge — capsule (state-color anchor, OSC 8 clickable)
  if input.pr.isSome:
    let pr = input.pr.get
    let num = pr.number.orElse(0)
    if num > 0:
      let state = pr.review_state.orElse("pending")
      let label = iconPR & " #" & $num & " " & reviewStateIcon(state)
      let pill = capsule(reviewStateColor(state), cBlack, label)
      let url = pr.url.orElse("")
      result.right.add (if url.len > 0: osc8Wrap(url, pill) else: pill)

# ===========================================================================
# Line 2 - metrics row
# ===========================================================================

const contextBarWidth = 10

proc thresholdColor(pct: int): string =
  if pct >= 90: cRed
  elif pct >= 70: cYellow
  else: cGreen

proc contextBarSegment(pct, usedTok, maxTok: int): string =
  ## Render the context bar inline (no capsule): the filled portion of the
  ## bar IS the threshold color, the empty portion is muted gray, and the
  ## token-count / percentage tail picks up the same threshold color so the
  ## whole segment reads as a single visual indicator.
  let color = thresholdColor(pct)
  let filled = (pct * contextBarWidth) div 100
  result  = fg(color) & sgrBold & barFilled.repeat(filled) & sgrReset
  result.add fg(cLightGray) & barEmpty.repeat(contextBarWidth - filled) & sgrReset
  result.add " "
  if maxTok > 0:
    result.add fg(color) & sgrBold &
               humanTokens(usedTok) & "/" & humanTokens(maxTok) & " " & sgrReset
  result.add fg(color) & sgrBold & "(" & $pct & "%)" & sgrReset

proc renderLine2(input: StatuslineInput):
                tuple[left, right: seq[string]] =
  # --- LEFT GROUP -----------------------------------------------------------

  # Model — plain cyan bold text. `display_name` typically carries any
  # context-size hint already (e.g. "Opus 4.7 (1M context)").
  if input.model.isSome:
    let m = input.model.get.display_name.orElse("")
    if m.len > 0:
      result.left.add plain(cCyan, m, bold = true)

  # Context bar — plain inline segment, no capsule. The filled portion IS
  # the threshold color; the empty portion is muted gray. Token count +
  # percentage trail in the same threshold color so the whole segment reads
  # as one visual indicator. `exceeds_200k_tokens` is intentionally NOT
  # rendered: it fires permanently on extended-context models and the
  # community surveys flag it as noise.
  var pct = 0
  var usedTok = 0
  var maxTok = 0
  if input.context_window.isSome:
    let cw = input.context_window.get
    pct = int(cw.used_percentage.orElse(0.0))
    usedTok = cw.total_input_tokens.orElse(0)
    maxTok = cw.context_window_size.orElse(0)
  result.left.add contextBarSegment(pct, usedTok, maxTok)

  # 7-day rate limit — plain yellow text. 5-hour intentionally omitted per
  # user preference (community convention reverses this; user prefers the
  # weekly strategic-reserve view over the daily pacing view).
  if input.rate_limits.isSome:
    let rl = input.rate_limits.get
    if rl.seven_day.isSome:
      let v = rl.seven_day.get.used_percentage
      if v.isSome:
        result.left.add plain(cYellow, "7d: " & $int(v.get) & "%")
  # Cost (renders alongside rate_limits if also present — both can be useful)
  if input.cost.isSome:
    let c = input.cost.get.total_cost_usd.orElse(0.0)
    if c > 0.0:
      result.left.add plain(cYellow, fmt"${c:.2f}")

  # --- RIGHT GROUP ----------------------------------------------------------

  # Duration — plain lightgray text, hidden until there's meaningful data
  # (Gordon Beeming pattern: "showing 0s before you've even sent a message
  # just adds noise"). Threshold: 60 seconds.
  if input.cost.isSome:
    let ms = input.cost.get.total_duration_ms.orElse(0)
    if ms >= 60_000:
      result.right.add plain(cLightGray, iconClock & " " & formatDuration(ms))

  # Effort level — plain green text, only when non-default (community pattern:
  # show when set to "high"/"xhigh"/"max", omit when "medium"/"low"/absent).
  # `thinking.enabled` intentionally dropped — too cryptic, virtually no
  # community config renders it.
  let effortLvl =
    if input.effort.isSome: input.effort.get.level.orElse("") else: ""
  if effortLvl in ["high", "xhigh", "max"]:
    result.right.add plain(cGreen, iconBolt & " " & effortLvl)

  # Agent name — plain red text, far right (only present in --agent sessions)
  if input.agent.isSome:
    let a = input.agent.get.name.orElse("")
    if a.len > 0:
      result.right.add plain(cRed, iconBot & " " & a)

# ===========================================================================
# Entry
# ===========================================================================

when isMainModule:
  let raw = try: stdin.readAll() except IOError: ""
  let input = parseInput(raw)
  let sessionId = input.session_id.orElse("default")
  let cwd =
    if input.workspace.isSome and input.workspace.get.current_dir.isSome:
      input.workspace.get.current_dir.get
    else:
      input.cwd.orElse(getCurrentDir())
  let g = git(sessionId, cwd)
  let termW = detectWidth()

  let (l1Left, l1Right) = renderLine1(input, g)
  let (l2Left, l2Right) = renderLine2(input)
  let line1 = joinLine(l1Left, l1Right, termW)
  let line2 = joinLine(l2Left, l2Right, termW)
  if line1.len > 0: echo line1
  if line2.len > 0: echo line2
