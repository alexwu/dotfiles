# zmx — refresh this shell's terminal metadata from the attached client.
#
# A session shell outlives the terminal it started in. zmx records the tracked
# variables (ZMX_TRACK_ENV, set in .zshenv) of the client that leads the
# session, and `zmx print-env -s .` prints them as export/unset lines. Running
# that before each prompt keeps WEZTERM_PANE, BTTY_PANE, SSH_AUTH_SOCK and the
# rest pointing at the terminal that is attached now.
#
# This updates the shell and the processes it starts afterwards. A process that
# is already running (a long-lived claude, nvim) keeps the env it was exec'd
# with; it has to ask for the live value: `zmx print-env . WEZTERM_PANE`.
if [[ -n $ZMX_SESSION ]] && (($+commands[zmx])); then
  autoload -Uz add-zsh-hook

  _zmx_refresh_env() {
    # Later precmd hooks (p10k's status segment) read $?, so hand it back.
    local rc=$? out
    out=$(zmx print-env -s . 2>/dev/null) && [[ -n $out ]] && eval "$out"
    return $rc
  }
  add-zsh-hook precmd _zmx_refresh_env
fi
