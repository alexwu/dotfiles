if [ $(arch) = "arm64" ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
  alias ibrew="arch -x86_64 /usr/local/bin/brew"
elif [ $(arch) = "i386" ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

export FZF_BASE=$(brew --prefix)/bin/fzf
# export RUBY_CONFIGURE_OPTS="--with-openssl-dir=$(brew --prefix openssl@1.1)"
export SSH_AUTH_SOCK=/Users/jamesbombeelu/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh
export PATH="/Applications/Postgres.app/Contents/Versions/latest/bin:$PATH"
. $HOME/.asdf/asdf.sh

alias yoink=“open -a Yoink”
