if [ $(arch) = "arm64" ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
  alias ibrew="arch -x86_64 /usr/local/bin/brew"
elif [ $(arch) = "i386" ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

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

export POWERLEVEL9K_TERM_SHELL_INTEGRATION=true
export HOMEBREW_NO_ENV_HINTS=true
# export FZF_BASE=$(brew --prefix)/bin/fzf
# export FZF_DEFAULT_COMMAND="fd --type f -uu --follow --exclude .git --exclude node_modules --exclude coverage --exclude .DS_Store --strip-cwd-prefix"
# export FZF_CTRL_T_COMMAND="fd --type f -uu --follow --exclude .git --exclude node_modules --exclude coverage --exclude .DS_Store --exclude tmp --exclude target --strip-cwd-prefix"
# export FZF_CTRL_T_OPTS="--color 'fg:#f9f9ff,fg+:#f3f99d,hl:#5af78e,hl+:#5af78e,spinner:#5af78e,pointer:#ff6ac1,info:#5af78e,prompt:#9aedfe,gutter:#282a36' --border"
export SSH_AUTH_SOCK=/Users/jamesbombeelu/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh
export PATH="/Applications/Postgres.app/Contents/Versions/latest/bin:$PATH"
