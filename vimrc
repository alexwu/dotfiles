" Use Vim settings, rather then Vi settings (much better!).
" This must be first, because it changes other options as a side effect.
set nocompatible              " be iMproved, required
setglobal path=.,,
" runtime path includes fuzzy finding plugin
set rtp+=/usr/local/opt/fzf

" vim-plug Package Manager
"
" install vim-plug if not found
if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin('~/.vim/plugged')

" Functionality
Plug 'bkad/CamelCaseMotion'
Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }                   " Fuzzy finding functionality
Plug 'junegunn/fzf.vim'
Plug 'itchyny/lightline.vim'
Plug 'tpope/vim-rails'                                                " Ruby on Rails functionality
Plug 'tpope/vim-bundler'                                              " Bundler usable from Vim
Plug 'tpope/vim-dispatch'
Plug 'tpope/vim-eunuch'
Plug 'tpope/vim-fugitive'                                             " Git functionality in Vim
Plug 'machakann/vim-sandwich'
Plug 'janko/vim-test'
Plug 'mhinz/vim-startify'

" Formatting
Plug 'junegunn/vim-easy-align'
Plug 'tomtom/tcomment_vim'
Plug 'Yggdroot/indentLine'
Plug 'prettier/vim-prettier', {
  \ 'do': 'yarn install',
  \ 'for': ['javascript', 'typescript', 'css', 'less', 'scss', 'json', 'graphql', 'markdown', 'vue', 'yaml', 'html', 'ruby'] }

" Syntax Highlighting
Plug 'HerringtonDarkholme/yats.vim'
Plug 'sheerun/vim-polyglot'           " Extra syntax features for various languages

" Ale
Plug 'w0rp/ale'
Plug 'maximbaz/lightline-ale'

" Theming
Plug 'connorholyday/vim-snazzy'       " Snazzy theme for Vim
Plug 'tpope/vim-projectionist'

" All of your Plugins must be added before the following line
call plug#end()

filetype plugin indent on    " required
" see :h vundle for more details or wiki for FAQ
" Put your non-Plugin stuff after this line

" When started as "evim", evim.vim will already have done these settings.
if v:progname =~? "evim"
  finish
endif

if has('path_extra')
  setglobal tags-=./tags tags-=./tags; tags^=./tags;
endif

" SETTINGS
"
set loadplugins
set shell=/bin/zsh
set encoding=utf-8
set smarttab
set softtabstop=2
set shiftwidth=2
set expandtab
set tabstop=2
set ignorecase
set smartcase
set nowrap
set textwidth=0
set autoindent
set linebreak
set number
set cursorline
set listchars=tab:▶\ ,eol:¬
set wildignore=*.swp,.git,.svn,*.log,*.gif,*.jpeg,*.jpg,*.png,*.pdf,tmp/**

set hidden                      " Be more liberal about hidden buffers
set backspace=indent,eol,start  " backspace over everything
set numberwidth=5               " Sets the gutter width for line numbers
set nobackup                    " do not keep a backup file, use an SCM instead
set history=50                  " keep 50 lines of command line history
set ruler                       " show the cursor position all the time
set incsearch                   " do incremental searching
set hlsearch                    " Highlight all search matches
set lazyredraw                  " Don't update the display while executing macros
set ch=2                        " Make command line two lines high
set laststatus=2                " Always show the status line
set showcmd                     " Show the current command in the lower right corner
set cmdheight=2
set noshowmode                  " Show the current mode
set timeoutlen=250              " Short map keys timeout keeps the ui feeling snappy
set tags=./TAGS,TAGS            " Use Emacs tagfile naming convention
set modelines=1
" Insert only one space when joining lines that contain sentence-terminating
" punctuation like `.`.
set nojoinspaces

set grepprg=grep\ -nH\ $*

" Starting with Vim 7, the filetype of empty .tex files defaults to
" 'plaintex' instead of 'tex', which results in vim-latex not being loaded.
"  The following changes the default filetype back to 'tex':
"" let g:tex_flavor='latex'

" Keep more context when scrolling off the end of a buffer
set scrolloff=10

" Store temporary files in a central spot
set directory=~/.vim-tmp/,~/.tmp/,~/tmp/,/var/tmp/,/tmp

syntax on
if has("gui_running")
else
  colorscheme snazzy
endif

" In many terminal emulators the mouse works just fine, thus enable it.
if has('mouse')
  set mouse=a
endif

"Allows remapping of Ctrl-j
let g:BASH_Ctrl_j = 'off'

" Move up and down over screen lines instead of file lines
nnoremap j gj
nnoremap k gk
nnoremap <c-j> 5gj
nnoremap <c-k> 5gk
nnoremap <c-h> 5h
nnoremap <c-l> 5l

" Move between splits with CTRL+Arrow Keys
nnoremap <C-Down> <C-W><C-J>
nnoremap <C-Up> <C-W><C-K>
nnoremap <C-Right> <C-W><C-L>
nnoremap <C-Left> <C-W><C-H>

"Allows remapping of Ctrl-j because of latex-suite
nnoremap <SID>I_won’t_ever_type_this <Plug>IMAP_JumpForward
inoremap <SID>I_won’t_ever_type_this <Plug>IMAP_JumpForward

inoremap <c-j> <Down>
inoremap <c-k> <Up>
inoremap <c-h> <Left>
inoremap <c-l> <Right>

vnoremap <c-j> 5gj
vnoremap <c-k> 5gk
vnoremap <c-h> 5h
vnoremap <c-l> 5l


" Start interactive EasyAlign in visual mode (e.g. vipga)
xmap ga <Plug>(EasyAlign)

" Start interactive EasyAlign for a motion/text object (e.g. gaip)
nmap ga <Plug>(EasyAlign)

" COMMAND MODE KEY MAPPINGS
"
" Map :W to :w so vim stops complaining about W
command! W :w
command! Q :q
command! QW :wq
command! Qw :wq
command! WQ :wq
command! Wq :wq

"Use 24-bit (true-color) mode in Vim/Neovim when outside tmux.
"If you're using tmux version 2.2 or later, you can remove the outermost $TMUX check and use tmux's 24-bit color support
"(see < http://sunaku.github.io/tmux-24bit-color.html#usage > for more information.)

if exists('+termguicolors')
  let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"
  let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"
  set termguicolors
endif
if (empty($TMUX))
  if (has("nvim"))
    "For Neovim 0.1.3 and 0.1.4 < https://github.com/neovim/neovim/pull/2198 >
    let $NVIM_TUI_ENABLE_TRUE_COLOR=1
  endif
  "For Neovim > 0.1.5 and Vim > patch 7.4.1799 < https://github.com/vim/vim/commit/61be73bb0f965a895bfb064ea3e55476ac175162 >
  "Based on Vim patch 7.4.1770 (`guicolors` option) < https://github.com/vim/vim/commit/8a633e3427b47286869aa4b96f2bfc1fe65b25cd >
  " < https://github.com/neovim/neovim/wiki/Following-HEAD#20160511 >
endif


""""""""""""" POLYGLOT
let g:polyglot_disabled = ['typescript']

""""""""""""" YATS
set re=2 " Uses newer regexp engine for YATS

" coc settings
" Smaller updatetime for CursorHold & CursorHoldI
set updatetime=300

" don't give |ins-completion-menu| messages.
set shortmess+=c

" Always show the signcolumn, otherwise it would shift the text each time
" diagnostics appear/become resolved.
if has("patch-8.1.1564")
  " Recently vim can merge signcolumn and number column into one
  set signcolumn=number
else
  set signcolumn=yes
endif

" Use tab for trigger completion with characters ahead and navigate.
" Use command ':verbose imap <tab>' to make sure tab is not mapped by other plugin.pumvisible() ? "\" : "\\
inoremap <silent><expr> <TAB>
      \ pumvisible() ? "\<C-n>" :
      \ <SID>check_back_space() ? "\<TAB>" :
      \ coc#refresh()
inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"

function! s:check_back_space() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction

" Use <c-space> to trigger completion.
inoremap <silent><expr> <c-space> coc#refresh()

" Use <cr> to confirm completion, `<C-g>u` means break undo chain at current position.
" Coc only does snippet and additional edit on confirm.
inoremap <expr> <cr> pumvisible() ? "\<C-y>" : "\<C-g>u\<CR>"

" Use `[c` and `]c` to navigate diagnostics
nmap <silent> [c <Plug>(coc-diagnostic-prev)
nmap <silent> ]c <Plug>(coc-diagnostic-next)

" Remap keys for gotos
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

" Use K to show documentation in preview window
nnoremap <silent> K :call <SID>show_documentation()<CR>

function! s:show_documentation()
  if (index(['vim','help'], &filetype) >= 0)
    execute 'h '.expand('<cword>')
  else
    call CocAction('doHover')
  endif
endfunction

" Highlight symbol under cursor on CursorHold
autocmd CursorHold * silent call CocActionAsync('highlight')

map <space> <leader>
" Remap for rename current word
nmap <leader>rn <Plug>(coc-rename)

command! -nargs=0 Prettier :CocCommand prettier.formatFile

" Remap for format selected region
xmap <leader>f  <Plug>(coc-format-selected)
nmap <leader>f  <Plug>(coc-format-selected)
let g:coc_status_error_sign = '✘'

augroup mygroup
  autocmd!
  " Setup formatexpr specified filetype(s).
  autocmd FileType typescript,javascript,json setl formatexpr=CocAction('formatSelected')
  " Update signature help on jump placeholder
  autocmd User CocJumpPlaceholder call CocActionAsync('showSignatureHelp')
augroup end

" Remap for do codeAction of selected region, ex: `<leader>aap` for current paragraph
xmap <leader>a  <Plug>(coc-codeaction-selected)
nmap <leader>a  <Plug>(coc-codeaction-selected)

" Remap for do codeAction of current line
nmap <leader>ac  <Plug>(coc-codeaction)
" Fix autofix problem of current line
nmap <leader>qf  <Plug>(coc-fix-current)

" Use `:Format` to format current buffer
command! -nargs=0 Format :call CocAction('format')

" Use `:Fold` to fold current buffer
command! -nargs=? Fold :call     CocAction('fold', <f-args>)

"""""""""""""""" LIGHTLINE
" Add diagnostic info for https://github.com/itchyny/lightline.vim

function! CocCurrentFunction()
  return get(b:, 'coc_current_function', '')
endfunction


function! CocGitBlame () abort
  let blame = get(b:, 'coc_git_blame', '')
  return blame
endfunction


let g:lightline = {
      \ 'colorscheme': 'snazzy',
      \ 'active': {
      \   'left': [
      \     [ 'mode', 'paste' ],
      \     [ 'git', 'diagnostic', 'readonly', 'filename', 'modified' ],
      \     [ 'gitbranch', 'cocstatus', 'currentfunction' ],
      \   ],
      \   'right': [
      \     [ 'linter_checking', 'linter_errors', 'linter_warnings', 'linter_infos', 'linter_ok' ],
      \     [ 'filetype', 'fileencoding', 'lineinfo', ],
      \     [ 'blame' ],
      \   ],
      \ },
      \ 'component_function': {
      \   'cocstatus': 'coc#status',
      \   'blame': 'CocGitBlame',
      \   'gitbranch': 'fugitive#head',
      \   'currentfunction': 'CocCurrentFunction',
      \ },
      \ }
let g:lightline.component_expand = {
      \  'linter_checking': 'lightline#ale#checking',
      \  'linter_infos': 'lightline#ale#infos',
      \  'linter_warnings': 'lightline#ale#warnings',
      \  'linter_errors': 'lightline#ale#errors',
      \  'linter_ok': 'lightline#ale#ok',
      \ }
let g:lightline.component_type = {
      \   'linter_checking': 'left',
      \    'linter_infos': 'right',
      \   'linter_warnings': 'warning',
      \   'linter_errors': 'error',
      \   'linter_ok': 'left',
      \ }

"""""""""""""""" COC
" Using CocList
" Show all diagnostics
nnoremap <silent> <space>a  :<C-u>CocList diagnostics<cr>
" Manage extensions
nnoremap <silent> <space>e  :<C-u>CocList extensions<cr>
" Show commands
nnoremap <silent> <space>c  :<C-u>CocList commands<cr>
" Find symbol of current document
nnoremap <silent> <space>o  :<C-u>CocList outline<cr>
" Search workspace symbols
nnoremap <silent> <space>s  :<C-u>CocList -I symbols<cr>
" Do default action for next item.
nnoremap <silent> <space>j  :<C-u>CocNext<CR>
" Do default action for previous item.
nnoremap <silent> <space>k  :<C-u>CocPrev<CR>
" Resume latest coc list
nnoremap <silent> <space>p  :<C-u>CocListResume<CR>

"""""""""""""""" FZF

" Disable preview menu for FZF
let g:fzf_preview_window = ''

" You can set up fzf window using a Vim command (Neovim or latest Vim 8 required)
let g:fzf_layout = { 'window': 'enew' }
let g:fzf_layout = { 'window': '-tabnew' }
let g:fzf_layout = { 'window': '10new' }

" Customize fzf colors to match your color scheme
let g:fzf_colors =
\ { 'fg':      ['fg', 'Normal'],
  \ 'bg':      ['bg', 'Normal'],
  \ 'hl':      ['fg', 'Comment'],
  \ 'fg+':     ['fg', 'CursorLine', 'CursorColumn', 'Normal'],
  \ 'bg+':     ['bg', 'CursorLine', 'CursorColumn'],
  \ 'hl+':     ['fg', 'Statement'],
  \ 'info':    ['fg', 'PreProc'],
  \ 'border':  ['fg', 'Ignore'],
  \ 'prompt':  ['fg', 'Conditional'],
  \ 'pointer': ['fg', 'Exception'],
  \ 'marker':  ['fg', 'Keyword'],
  \ 'spinner': ['fg', 'Label'],
  \ 'header':  ['fg', 'Comment'] }

" Enable per-command history.
" CTRL-N and CTRL-P will be automatically bound to next-history and
" previous-history instead of down and up. If you don't like the change,
" explicitly bind the keys to down and up in your $FZF_DEFAULT_OPTS.
let g:fzf_history_dir = '~/.local/share/fzf-history'

nnoremap <silent> <C-p> :Files<CR>


"""""""""""""""" ALE
let g:ale_lint_delay = 400
let g:ale_fixers = {
\   '*': ['remove_trailing_lines', 'trim_whitespace'],
\}

let g:lightline#ale#indicator_errors= '✘'
let g:lightline#ale#indicator_warnings = '♦'

let g:ale_enabled = 1
let g:ale_fix_on_save = 1
let g:ale_sign_error = '✘'
let g:ale_sign_warning = '>>'
let g:ale_sign_info= '--'
highlight ALEErrorSign ctermbg=NONE ctermfg=red
highlight ALEError ctermbg=NONE ctermfg=red cterm=underline
highlight ALEWarning ctermbg=NONE ctermfg=yellow cterm=underline
highlight ALEInfo ctermbg=NONE ctermfg=blue cterm=underline

"""""""""""""""" PRETTIER
nmap <silent> <Leader>y :PrettierAsync<CR>
xmap <silent> <Leader>y :PrettierPartial<CR>
let g:prettier#config#single_quote = 'false'
let g:prettier#config#semi = 'always'

"""""""""""""""" COMMENTARY
xmap <C-_>      :TComment <CR>
omap <C-_>      :TComment <CR>

"""""""""""""""" TEST
nmap <silent> <Leader>s :TestNearest<CR>
nmap <silent> <Leader>t :TestFile<CR>
nmap <silent> <Leader>s :TestSuite<CR>
nmap <silent> <Leader>l :TestLast<CR>
nmap <silent> <Leader>a :TestVisit<CR>

"""""""""""""""" DISPATCH
let test#strategy = "vimterminal"
let test#vim#term_position = "below"


"""""""""""""""" NETRW
let g:netrw_banner = 0
let g:netrw_winsize = 25

"""""""""""""""" NETRW
" vim-surround config for vim-sandwich
runtime macros/sandwich/keymap/surround.vim
