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

if (( $+commands[mise] ))
then
  eval "$(mise activate zsh)"
fi


export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
export NEOVIDE_MULTIGRID=true
export LS_COLORS="$(vivid generate snazzy)"
export POWERLEVEL9K_TERM_SHELL_INTEGRATION=true
export HOMEBREW_NO_ENV_HINTS=true
export OP_BIOMETRIC_UNLOCK_ENABLED=true
path=(/Applications/Postgres.app/Contents/Versions/latest/bin $path)
path=($HOME/.bin/nvim/bin $path)
