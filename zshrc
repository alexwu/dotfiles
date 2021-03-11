typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

OS="$(uname -s)"

if [ "$OS" = "Darwin" ]; then
  if [ $(arch) = "arm64" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ $(arch) = "i386" ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi

  export FZF_BASE=$(brew --prefix)/bin/fzf
  export RUBY_CONFIGURE_OPTS="--with-openssl-dir=$(brew --prefix openssl@1.1)"
  export SSH_AUTH_SOCK=/Users/$(whoami)/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh
fi

export PATH="$HOME/.bin:$PATH"
export NVM_COMPLETION=true

autoload -U colors && colors

## VI Mode
bindkey -v

export FZF_DEFAULT_COMMAND='fd --type f --hidden --no-ignore-vcs --follow'
export FZF_CTRL_T_COMMAND="fd --type f --hidden --follow"
export FZF_CTRL_T_OPTS="--color 'fg:#f9f9ff,bg+:#3a3d4d,spinner:#5af78e,pointer:#ff6ac1,info:#f3f99d,prompt:#9aedfe,gutter:#3a3d4d'"
export BUNDLED_COMMANDS=(srb)

zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'exa -1 --color=always $realpath'

if ! command -v nvim &> /dev/null
then
  export EDITOR="vim"
else
  export EDITOR="nvim"
fi

if [[ $TERM = "xterm-kitty" ]]
then
  alias ssh="kitty +kitten ssh"
fi

alias zshconfig="$EDITOR ~/.dotfiles/zshrc"
alias nvimrc="$EDITOR ~/.dotfiles/config/nvim"
alias ls="exa"

### Added by Zinit's installer
if [[ ! -f $HOME/.zinit/bin/zinit.zsh ]]; then
  print -P "%F{33}▓▒░ %F{220}Installing %F{33}DHARMA%F{220} Initiative Plugin Manager (%F{33}zdharma/zinit%F{220})…%f"
  command mkdir -p "$HOME/.zinit" && command chmod g-rwX "$HOME/.zinit"
  command git clone https://github.com/zdharma/zinit "$HOME/.zinit/bin" && \
    print -P "%F{33}▓▒░ %F{34}Installation successful.%f%b" || \
    print -P "%F{160}▓▒░ The clone has failed.%f%b"
fi

source "$HOME/.zinit/bin/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

# Load a few important annexes, without Turbo
# (this is currently required for annexes)
zinit light-mode for \
  zinit-zsh/z-a-rust \
  zinit-zsh/z-a-as-monitor \
  zinit-zsh/z-a-patch-dl \
  zinit-zsh/z-a-bin-gem-node

### End of Zinit's installer chunk

zinit wait lucid for \
  OMZL::git.zsh \
  OMZP::git \

### THEME
zinit ice depth=1; zinit light romkatv/powerlevel10k
zinit wait lucid for \
  atinit"zicompinit; zicdreplay"  \
  zdharma/fast-syntax-highlighting

zinit wait lucid atload'_zsh_autosuggest_start' for \
  zsh-users/zsh-autosuggestions

zinit wait lucid for \
  OMZL::history.zsh \
  atload"bindkey '^[[A' history-substring-search-up; bindkey '^[[B' history-substring-search-down;" zsh-users/zsh-history-substring-search


zinit wait blockf lucid for \
  OMZP::bundler \
  OMZP::rbenv \
  OMZP::heroku \
  OMZP::iterm2 \
  OMZP::gem \
  OMZP::fzf \
  atload"zpcdreplay" atclone'./zplug.zsh' g-plane/zsh-yarn-autocompletions \
  lukechilds/zsh-nvm

zinit wait lucid for \
  Aloxaf/fzf-tab

zinit wait lucid as"completion" for \
  https://github.com/sharkdp/fd/blob/master/contrib/completion/_fd \
  https://github.com/asdf-vm/asdf/blob/master/completions/_asdf \
  https://github.com/ggreer/the_silver_searcher/blob/master/_the_silver_searcher

eval "$(zoxide init zsh --no-aliases)"
function z() {
  __zoxide_z "$@"
}

# ASDF plugin setup
. $HOME/.asdf/asdf.sh

(( ! ${+functions[p10k-instant-prompt-finalize]} )) || p10k-instant-prompt-finalize
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
