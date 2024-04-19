if [ $(arch) = "arm64" ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
  alias ibrew="arch -x86_64 /usr/local/bin/brew"
elif [ $(arch) = "i386" ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

fpath+=~/.zfunc

if type brew &>/dev/null
then
  FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"

  autoload -Uz compinit
  compinit
fi

if (( $+commands[fzf] ))
then
  source ~/.zsh/fzf.zsh
fi

alias co="git checkout"

# if (( $+commands[mise] ))
# then
  eval "$(mise activate zsh)"
# fi

alias tailscale="/Applications/Tailscale.app/Contents/MacOS/Tailscale"

source ~/.zsh/wezterm.sh

export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
export NEOVIDE_MULTIGRID=true
export LS_COLORS="$(vivid generate snazzy)"
export POWERLEVEL9K_TERM_SHELL_INTEGRATION=true
export HOMEBREW_NO_ENV_HINTS=true
export OP_BIOMETRIC_UNLOCK_ENABLED=true
path=(/Applications/Postgres.app/Contents/Versions/latest/bin $path)
path=($HOME/.bin/nvim/bin $path)
export SSH_AUTH_SOCK=""~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock


if (( $+commands[wezterm] ))
then
  # This script will open a new terminal for the selected project.
  # Terminal used: wezterm

# hacky way to switch workspace via the wezterm cli
# source: https://github.com/wez/wezterm/issues/2979#issuecomment-1447519267
# watch discussion: https://github.com/wez/wezterm/discussions/3534
# watch issue: https://github.com/wez/wezterm/issues/3542
wezterm-switch-workspace() {
  args=$(jq -n --arg workspace "$1" --arg cwd "$2" '{"workspace":$workspace,"cwd":$cwd}' | base64)
  printf "\033]1337;SetUserVar=%s=%s\007" switch-workspace $args
}

# List of project roots, all are assumed to be below $HOME
# project_roots=(
#   "$HOME/Source"
#   "$XDG_CONFIG_HOME"
# )

# 1. Get all project folders without trailing slash
# project_folders=$(fd --min-depth 1 --max-depth 1 -t directory . ${project_roots[@]} | xargs realpath)

# 2. Select a project using fzf (all paths are relative to $HOME)
# selected_folder=$(printf '%s\n' "${project_folders[@]}" | sed "s|$HOME/||" | fzf)

# 3. Switch to the workspace by communicating with wezterm
# wezterm-switch-workspace $selected_folder $HOME/$selected_folder
fi
