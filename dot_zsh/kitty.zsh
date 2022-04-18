alias ssh="kitty +kitten ssh"
export NVIM_SERVER="$HOME/.cache/nvim/server_$KITTY_WINDOW_ID.pipe"

start_zenlocator () {
  cd ~/Work/cleverific/zenlocator
  kitty @ set-tab-title "ZenLocator"
  concurrently "npm --prefix sdk start" "npm --prefix api start" "npm --prefix api run start:queue:short" "npm --prefix api run start:queue:long" "npm --prefix dash start" --kill-others
}
