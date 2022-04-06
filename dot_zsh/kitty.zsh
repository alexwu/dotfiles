alias ssh="kitty +kitten ssh"
export NVIM_SERVER="$HOME/.cache/nvim/server_$KITTY_WINDOW_ID.pipe"


if (( $+commands[chezmoi] ))
then
  function dot() {
    kitty @ set-tab-title "Dotfiles"
    chezmoi cd
  }
  alias config="dot"
fi

if (( $+commands[nvim] ))
then
  if [[ -a "$NVIM_SERVER" ]]; then
    function nvim_remote() {
      nvim --server "$NVIM_SERVER" --remote-send "<C-\><C-n>:ToggleTerm<CR>"
      nvim --server "$NVIM_SERVER" --remote "$@"
    }

    alias nvim=nvim_remote
    export VISUAL=nvim_remote
    export EDITOR=nvim_remote
  else
    alias nvim="nvim --listen $NVIM_SERVER"
    export VISUAL=nvim
    export EDITOR=nvim
  fi
fi

start_zenlocator () {
  cd ~/Work/cleverific/zenlocator
  kitty @ set-tab-title "ZenLocator"
  concurrently "npm --prefix sdk start" "npm --prefix api start" "npm --prefix api run start:queue:short" "npm --prefix api run start:queue:long" "npm --prefix dash start" --kill-others
}

