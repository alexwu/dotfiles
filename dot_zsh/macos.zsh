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

if (( $+commands[rtx] ))
then
  eval "$(rtx activate zsh)"
fi


export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
export NEOVIDE_MULTIGRID=true
# export XDG_CONFIG_HOME=$HOME/.config/
export LS_COLORS="$(vivid generate snazzy)"
export POWERLEVEL9K_TERM_SHELL_INTEGRATION=true
export HOMEBREW_NO_ENV_HINTS=true
# path=(/Applications/Postgres.app/Contents/Versions/13/bin $path)
export OP_BIOMETRIC_UNLOCK_ENABLED=true
export SSH_AUTH_SOCK=~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock
export LDFLAGS="-L/opt/homebrew/opt/llvm@14/lib"
export CPPFLAGS="-I/opt/homebrew/opt/llvm@14/include"
export PATH="/opt/homebrew/opt/llvm@14/bin:$PATH"
export PATH="~/.bin/neovim/bin:$PATH"
