# Luna persona injection for Claude Code.
#
# Appends the persona file to the system prompt (operator tier) so Opus 5.5
# treats it as authoritative rather than user-preference. Without this, 5.5
# reads CLAUDE.md as user-tier instructions and randomly decides to skip the
# persona — tested 2026-09-22, 100% compliance at operator tier vs ~67% at
# user tier in heavy-context repos.
#
# Skips injection for subcommands (mcp, doctor, auth, …), --bare, and when
# the user provides their own --system-prompt / --system-prompt-file.

if (( $+commands[claude] )); then
  function claude() {
    local persona="$HOME/Code/lulu-prompts/Prompts/Agents/CLAUDE_CODE.md"
    local real_claude="${commands[claude]}"

    # Subcommands that aren't sessions — pass through untouched
    local -a subcommands=(
      agents attach auth auto-mode doctor gateway import install
      logs mcp plugin plugins project respawn rm setup-token
      stop kill ultrareview update upgrade
    )

    local inject=true

    # Check first non-flag arg for subcommands
    local arg
    for arg in "$@"; do
      [[ "$arg" == -* ]] && continue
      local sub
      for sub in "${subcommands[@]}"; do
        if [[ "$arg" == "$sub" ]]; then
          inject=false
          break 2
        fi
      done
      break
    done

    # Skip injection when user controls the system prompt or wants bare mode
    if $inject; then
      for arg in "$@"; do
        case "$arg" in
          --bare|--system-prompt|--system-prompt-file)
            inject=false
            break
            ;;
        esac
      done
    fi

    # Skip if the persona file doesn't exist
    [[ ! -f "$persona" ]] && inject=false

    if $inject; then
      command "$real_claude" --append-system-prompt-file "$persona" "$@"
    else
      command "$real_claude" "$@"
    fi
  }
fi
