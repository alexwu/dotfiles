if [ $(arch) = "arm64" ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
  alias ibrew="arch -x86_64 /usr/local/bin/brew"
elif [ $(arch) = "i386" ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

export POWERLEVEL9K_TERM_SHELL_INTEGRATION=true
export HOMEBREW_NO_ENV_HINTS=true
export FZF_BASE=$(brew --prefix)/bin/fzf
export SSH_AUTH_SOCK=/Users/jamesbombeelu/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh
export PATH="/Applications/Postgres.app/Contents/Versions/latest/bin:$PATH"
# . $HOME/.asdf/asdf.sh
