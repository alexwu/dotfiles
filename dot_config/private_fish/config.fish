# ~/.config/fish/config.fish
# ============================================================
# Ported from zsh (zshrc + zim modules) -> fish
#
# What you DON'T need anymore (fish has these built-in):
#   - fast-syntax-highlighting  -> fish has native syntax highlighting
#   - zsh-autosuggestions       -> fish has native autosuggestions
#   - zsh-completions           -> fish has extensive built-in completions
#   - fzf-tab                   -> fish's tab completion is already great
#                                  (but see: https://github.com/PatrickF1/fzf.fish for fzf integration)
#   - fancy-ctrl-z              -> fish doesn't background the same way; see note below
#   - zim / oh-my-zsh framework -> not needed, fish plugin managers are lighter (fisher)
#   - environment module        -> fish handles this natively
#   - input module              -> fish handles key bindings natively
#   - termtitle module          -> fish sets terminal title by default
#   - completion module         -> fish handles completions natively
#
# Plugin manager recommendation: fisher (https://github.com/jorgebucaran/fisher)
#   curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher
#
# Recommended fisher plugins:
#   fisher install PatrickF1/fzf.fish          # fzf integration (keybindings, file/dir/history search)
#   fisher install jorgebucaran/autopair.fish  # auto-close brackets/quotes
#   fisher install jethrokuan/z                # alternative to zoxide if you want pure fish (optional since you use zoxide)
#   fisher install oh-my-fish/plugin-git       # git abbreviations (similar to oh-my-zsh git plugin)
# ============================================================

if status is-interactive

    # ----------------------------
    # Greeting (replaces fish's default greeting)
    # ----------------------------
    # Pokemon colorscripts on startup (replaces fish_greeting)
    if command -q pokemon-colorscripts
        function fish_greeting
            pokemon-colorscripts -r --no-title
        end
    else
        set -g fish_greeting # disable default greeting
    end

    # ----------------------------
    # Environment
    # ----------------------------
    set -gx OS (uname -s)
    set -gx HISTORY_IGNORE "(fg|ls|exit)"

    if command -q nvim
        set -gx VISUAL nvim
        set -gx EDITOR nvim
    else
        set -gx VISUAL vim
        set -gx EDITOR vim
    end

    # ----------------------------
    # PATH additions
    # Use fish_add_path — it deduplicates and persists automatically
    # ----------------------------
    fish_add_path $HOME/.bin
    fish_add_path $HOME/.cargo/bin
    fish_add_path $HOME/.bun/bin
    fish_add_path $HOME/.local/bin

    if test "$OS" = Darwin
        # macOS-specific paths
        fish_add_path $HOME/Library/pnpm            # pnpm
        set -gx PNPM_HOME "$HOME/Library/pnpm"

        fish_add_path $HOME/.cache/lm-studio/bin    # LM Studio
        fish_add_path $HOME/.lmstudio/bin            # LM Studio CLI
    else
        # Linux-specific
        fish_add_path $HOME/bin
    end

    if command -q go
        fish_add_path $HOME/go/bin
    end

    if command -q luarocks
        fish_add_path $HOME/.luarocks/bin
    end

    # ----------------------------
    # LS Colors (for completions)
    # ----------------------------
    # fish respects LS_COLORS natively in completions
    # If using eza (formerly exa), set up abbreviations:
    if command -q eza
        abbr -a ls  'eza'
        abbr -a ll  'eza -la'
        abbr -a la  'eza -a'
        abbr -a lt  'eza --tree'
    end

    # ----------------------------
    # Key bindings
    # ----------------------------
    bind \t complete-and-search

    # ----------------------------
    # Tool integrations
    # ----------------------------

    # Zoxide (replaces cd with z)
    if command -q zoxide
        zoxide init fish | source
        # Override default completion: always show frecency-ranked zoxide results on tab
        complete --erase --command z
        complete --command z --no-files --arguments '(zoxide query -l -- (commandline -opc)[2..] 2>/dev/null | string replace $HOME "~")'
    end

    # Atuin (shell history)
    if command -q atuin
        atuin init fish | source
        # If you prefer atuin only on ctrl-r (not up arrow), uncomment:
        # set -gx ATUIN_NOBIND true
        # atuin init fish | source
        # bind \cr _atuin_search
    end

    # Mise (version manager — replaces fnm/nvm/rbenv etc.)
    if command -q mise
        mise activate fish | source
        abbr -a must 'mise run'
    end

    # Skim (sk) — Rust fuzzy finder, replacing fzf
    # Plugin: fisher install mnacamura/skim.fish  (or triarius/sk-fish)
    if command -q sk
        set -gx SKIM_DEFAULT_COMMAND "fd --type f --strip-cwd-prefix --hidden --follow"
        set -gx SKIM_CTRL_T_COMMAND "fd --type f --strip-cwd-prefix --hidden --follow --exclude .git --exclude .DS_Store"
        set -gx SKIM_ALT_C_COMMAND "fd --type d --strip-cwd-prefix --hidden --follow --exclude .git"
    end

    # Fallback: source fzf keybindings if sk plugin isn't installed and fzf is present
    if not command -q sk; and command -q fzf; and not functions -q _fzf_search_directory
        fzf --fish | source
    end

    # ----------------------------
    # Chezmoi (dotfiles)
    # ----------------------------
    if command -q chezmoi
        function dot
            cd "$HOME/.local/share/chezmoi/"
        end
        abbr -a config 'dot'
    end

    # ----------------------------
    # Neovim helpers
    # ----------------------------
    if command -q nvim
        function vimrc
            cd (chezmoi source-path ~/.config/nvim)
        end
        function nvimrc
            cd (chezmoi source-path ~/.config/nvim)
            nvim .
        end
        abbr -a envim 'NVIM_APPNAME=pack-nvim nvim'
    end

    # ----------------------------
    # Delta (better diff)
    # ----------------------------
    if command -q delta
        abbr -a diff 'delta'
    end

    # ----------------------------
    # Just (command runner)
    # ----------------------------
    if command -q just
        abbr -a J 'just -g'
    end

    # ----------------------------
    # Petname (name generator)
    # ----------------------------
    if command -q petname
        abbr -a dbzname 'petname -d ~/.config/petname-dbz'
    end

    # ----------------------------
    # Yazi (file manager with cwd tracking)
    # ----------------------------
    if command -q yazi
        function y
            set -l tmp (mktemp -t "yazi-cwd.XXXXXX")
            yazi $argv --cwd-file="$tmp"
            set -l cwd (command cat -- "$tmp")
            if test -n "$cwd" -a "$cwd" != "$PWD"
                builtin cd -- "$cwd"
            end
            rm -f -- "$tmp"
        end
    end

    # ----------------------------
    # Zellij
    # ----------------------------
    if command -q zellij
        if command -q petname
            abbr -a zjn 'zellij a -c (petname -d ~/.config/petname-dbz)'
        end
    end

    # ----------------------------
    # zmx (terminal multiplexer)
    # ----------------------------
    if command -q zmx
        if command -q petname
            abbr -a zn 'zmx attach (petname -d ~/.config/petname-dbz)'
        end

        function zmx-select
            set -l display (zmx list 2>/dev/null | while read -l line
                # parse tab-separated fields
                set -l parts (string split \t $line)
                set -l name (string replace 'name=' '' $parts[1])
                set -l pid (string replace 'pid=' '' $parts[2])
                set -l clients (string replace 'clients=' '' $parts[3])
                set -l dir (string replace 'start_dir=' '' $parts[5])
                printf "%-20s  pid:%-8s  clients:%-2s  %s\n" $name $pid $clients $dir
            end)

            set -l output (begin
                test -n "$display"; and echo "$display"
            end | fzf \
                --print-query \
                --height=80% \
                --reverse \
                --prompt="zmx> " \
                --header="Enter: select" \
                --preview='zmx history {1}' \
                --preview-window=right:60%:follow)
            set -l rc $status

            set -l query $output[1]
            set -l selected $output[2]

            if test $rc -eq 0 -a -n "$selected"
                set -l session_name (echo $selected | awk '{print $1}')
                zmx attach $session_name
            else if test -n "$query"
                zmx attach $query
            else
                return 130
            end
        end
    end

    # ----------------------------
    # fnox
    # ----------------------------
    if command -q fnox
        fnox activate fish | source
    end

    # ----------------------------
    # tv (television fuzzy finder)
    # ----------------------------
    # if command -q tv
    #     tv init fish | source
    # end

    # ----------------------------
    # ngrok completions
    # ----------------------------
    # if command -q ngrok
    #     ngrok completion fish | source
    # end

    # ----------------------------
    # wt (Windsurf/other CLI)
    # ----------------------------
    if command -q wt
        wt config shell init fish | source
    end

    # ----------------------------
    # Git (oh-my-zsh git plugin equivalent)
    # ----------------------------
    abbr -a g    'git'
    abbr -a ga   'git add'
    abbr -a gaa  'git add --all'
    abbr -a gb   'git branch'
    abbr -a gbd  'git branch -d'
    abbr -a gc   'git commit'
    abbr -a 'gc!' 'git commit --amend'
    abbr -a gcb  'git checkout -b'
    abbr -a gcm  'git checkout main'
    abbr -a gco  'git checkout'
    abbr -a gcp  'git cherry-pick'
    abbr -a gd   'git diff'
    abbr -a gds  'git diff --staged'
    abbr -a gf   'git fetch'
    abbr -a gl   'git pull'
    abbr -a glog 'git log --oneline --decorate --graph'
    abbr -a gm   'git merge'
    abbr -a gp   'git push'
    abbr -a gpf  'git push --force-with-lease'
    abbr -a grb  'git rebase'
    abbr -a grbi 'git rebase -i'
    abbr -a grs  'git restore'
    abbr -a grss 'git restore --staged'
    abbr -a gst  'git status'
    abbr -a gsta 'git stash'
    abbr -a gstp 'git stash pop'
    abbr -a gsts 'git stash show --text'
    abbr -a gsw  'git switch'
    abbr -a gswc 'git switch -c'
    abbr -a co   'git checkout'

    # ----------------------------
    # Bundler (oh-my-zsh bundler plugin equivalent)
    # Fish abbreviations for common bundler commands
    # ----------------------------
    abbr -a be  'bundle exec'
    abbr -a bl  'bundle list'
    abbr -a bo  'bundle open'
    abbr -a bu  'bundle update'
    abbr -a bi  'bundle install'

    # ----------------------------
    # Prompt: Starship
    # Since you're moving to fish, Starship makes sense as a universal prompt.
    # Your existing starship.toml will work as-is!
    # ----------------------------
    if command -q starship
        starship init fish | source
    end

end # end of `if status is-interactive`
