# Setup fzf
# ---------
if [[ ! "$PATH" == */opt/homebrew/opt/fzf/bin* ]]; then
  export PATH="${PATH:+${PATH}:}/opt/homebrew/opt/fzf/bin"
  export FZF_CTRL_T_COMMAND="fd -c always -tf -td -uu --follow --exclude .git --exclude node_modules --exclude coverage --exclude .DS_Store --exclude tmp --exclude target --strip-cwd-prefix"
  export FZF_CTRL_T_OPTS="--color 'fg:#f9f9ff,fg+:#f3f99d,hl:#5af78e,hl+:#5af78e,spinner:#5af78e,pointer:#ff6ac1,info:#5af78e,prompt:#9aedfe,gutter:#282a36' --border"
fi

# Auto-completion
# ---------------
[[ $- == *i* ]] && source "/opt/homebrew/opt/fzf/shell/completion.zsh" 2> /dev/null

# Key bindings
# ------------
source "/opt/homebrew/opt/fzf/shell/key-bindings.zsh"
