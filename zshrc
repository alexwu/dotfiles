export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES

export PATH="$HOME/.bin:$PATH"
export PATH="/usr/local/bin:$PATH"

export ZSH=$HOME/.oh-my-zsh

export FZF_BASE="/usr/local/bin/fzf"
export FZF_DEFAULT_COMMAND='ag --hidden --ignore .git -g ""'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

# Enable Powerlevel10k instant prompt. Should stay at the top of ~/.zshrc.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export SSH_AUTH_SOCK=/Users/jamesbombeelu/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh

ZSH_THEME="powerlevel10k/powerlevel10k"
ZSH_DISABLE_COMPFIX="true"
DISABLE_UPDATE_PROMPT="false"

DISABLE_UNTRACKED_FILES_DIRTY="true"

plugins=(
  asdf
  bundler
  cargo
  fzf
  gem
  git
  iterm2
  jsontools
  fast-syntax-highlighting
  heroku
  osx
  vscode
  zsh-autosuggestions
  zsh-completions
)

source $ZSH/oh-my-zsh.sh

# User configuration
 if [[ -n $SSH_CONNECTION ]]; then
   export EDITOR='vim'
 else
   export EDITOR='nvim'
 fi

alias vim="nvim"
alias zshconfig="vim ~/.zshrc"
alias ohmyzsh="vim ~/.oh-my-zsh"
alias ls="exa"
alias cat="bat"

(( ! ${+functions[p10k-instant-prompt-finalize]} )) || p10k-instant-prompt-finalize
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
