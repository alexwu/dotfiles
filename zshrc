typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export PATH="$HOME/.bin:$PATH"
# x86_64 Homebrew paths
export PATH="/usr/local/bin:$PATH"

autoload -U colors && colors

export SSH_AUTH_SOCK=/Users/$(whoami)/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh
export FZF_BASE=$(brew --prefix)/bin/fzf
export FZF_DEFAULT_COMMAND='fd --type f --no-ignore --follow'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_CTRL_T_OPTS="--color 'fg:#f9f9ff,bg+:#282a36,spinner:#5af78e,pointer:#ff6ac1,info:#f3f99d,prompt:#9aedfe'"
export BUNDLED_COMMANDS=(srb)

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
  OMZP::heroku \
  OMZP::iterm2 \
  OMZP::gem \
  OMZP::fzf \
  atload"zpcdreplay" atclone'./zplug.zsh' g-plane/zsh-yarn-autocompletions

zinit wait lucid for \
  Aloxaf/fzf-tab

zinit wait lucid as"snippet" for \
  https://github.com/asdf-vm/asdf/blob/master/completions/_asdf \
  https://github.com/sharkdp/fd/blob/master/contrib/completion/_fd \
  https://github.com/ggreer/the_silver_searcher/blob/master/_the_silver_searcher

eval "$(zoxide init zsh --no-aliases)"
function z() {
  __zoxide_z "$@"
}

# ASDF plugin setup
. $HOME/.asdf/asdf.sh

(( ! ${+functions[p10k-instant-prompt-finalize]} )) || p10k-instant-prompt-finalize
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
