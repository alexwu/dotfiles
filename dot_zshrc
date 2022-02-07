typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

OS="$(uname -s)"

if [ "$OS" = "Darwin" ]; then
  source $HOME/.zsh/macos.zsh
fi

export PATH="$HOME/.bin:$PATH"
export PATH="$HOME/go/bin:$PATH"
export PATH="/usr/local/opt/v8@3.15/bin:$PATH"
export LESS="-XFR"

export FZF_DEFAULT_COMMAND="fd --type f -uu --follow --exclude .git --exclude node_modules --exclude coverage --exclude .DS_Store --strip-cwd-prefix"
export FZF_CTRL_T_COMMAND="fd --type f -uu --follow --exclude .git --exclude node_modules --exclude coverage --exclude .DS_Store --exclude tmp --exclude target --strip-cwd-prefix"
export FZF_CTRL_T_OPTS="--color 'fg:#f9f9ff,fg+:#f3f99d,hl:#5af78e,hl+:#5af78e,spinner:#5af78e,pointer:#ff6ac1,info:#5af78e,prompt:#9aedfe,gutter:#282a36' --border"

zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'exa -1 --color=always $realpath'

if ! command -v nvim &> /dev/null
then
  export EDITOR="vim"
else
  if [ -n "$NVIM_LISTEN_ADDRESS" ]; then
    alias nvim=nvr -cc split --remote-wait +'set bufhidden=wipe'
  fi

  if [ -n "$NVIM_LISTEN_ADDRESS" ]; then
    export VISUAL="nvr -cc split --remote-wait +'set bufhidden=wipe'"
    export EDITOR="nvr -cc split --remote-wait +'set bufhidden=wipe'"
  else
    export VISUAL="nvim"
    export EDITOR="nvim"
  fi
fi

if [[ $TERM = "xterm-kitty" ]]
then
  alias ssh="kitty +kitten ssh"
fi

if command -v exa &> /dev/null
then
  alias ls="exa --sort type --ignore-glob='.DS_Store'"
fi

if command -v zoxide &> /dev/null
then
  eval "$(zoxide init zsh --no-aliases)"
  function z() {
    __zoxide_z "$@"
  }
fi

### Added by Zinit's installer
if [[ ! -f $HOME/.local/share/zinit/zinit.git/zinit.zsh ]]; then
    print -P "%F{33} %F{220}Installing %F{33}ZDHARMA-CONTINUUM%F{220} Initiative Plugin Manager (%F{33}zdharma-continuum/zinit%F{220})…%f"
    command mkdir -p "$HOME/.local/share/zinit" && command chmod g-rwX "$HOME/.local/share/zinit"
    command git clone https://github.com/zdharma-continuum/zinit "$HOME/.local/share/zinit/zinit.git" && \
        print -P "%F{33} %F{34}Installation successful.%f%b" || \
        print -P "%F{160} The clone has failed.%f%b"
fi

source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

zinit ice depth=1; zinit light romkatv/powerlevel10k

zinit light-mode for \
    zdharma-continuum/zinit-annex-as-monitor \
    zdharma-continuum/zinit-annex-bin-gem-node \
    zdharma-continuum/zinit-annex-patch-dl \
    zdharma-continuum/zinit-annex-rust

zinit wait lucid for \
 atinit"ZINIT[COMPINIT_OPTS]=-C; zicompinit; zicdreplay" \
    zdharma-continuum/fast-syntax-highlighting \
 blockf \
    zsh-users/zsh-completions \
 atload"!_zsh_autosuggest_start" \
    zsh-users/zsh-autosuggestions

zinit wait lucid for \
  OMZL::git.zsh \
  OMZP::git

zinit wait blockf lucid for \
  OMZP::bundler \
  OMZP::fzf \
  Aloxaf/fzf-tab \
  atload"zpcdreplay" atclone'./zplug.zsh' g-plane/zsh-yarn-autocompletions

zinit wait lucid as"completion" for \
  https://github.com/sharkdp/fd/blob/master/contrib/completion/_fd \
  https://github.com/asdf-vm/asdf/blob/master/completions/_asdf \
  https://github.com/ggreer/the_silver_searcher/blob/master/_the_silver_searcher

### End of Zinit's installer chunk

if (( $+commands[diesel] ))
then
  # source $HOME/.zsh/diesel.zsh
fi

(( ! ${+functions[p10k-instant-prompt-finalize]} )) || p10k-instant-prompt-finalize
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
