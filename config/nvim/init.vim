set nocompatible

let autoload_plug_path = stdpath('data') . '/site/autoload/plug.vim'
if !filereadable(autoload_plug_path)
  silent execute '!curl -fLo ' . autoload_plug_path . '  --create-dirs
      \ "https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim"'
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif
unlet autoload_plug_path

let g:ale_set_balloons = 1

let pluginsPath = stdpath('data') . '/plugged'
call plug#begin(pluginsPath)

let g:polyglot_disabled = ['javascript.plugin', 'typescript.plugin', 'graphql']

" Essentials
"
Plug 'connorholyday/vim-snazzy'
Plug 'janko/vim-test'
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'tpope/vim-commentary'
Plug 'voldikss/vim-floaterm'
Plug 'sheerun/vim-polyglot'

Plug 'w0rp/ale'
Plug 'itchyny/lightline.vim'
Plug 'tpope/vim-repeat'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-vinegar'
Plug 'tpope/vim-projectionist'
Plug 'tpope/vim-abolish'
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}

Plug 'tpope/vim-bundler'
Plug 'tpope/vim-dispatch'
Plug 'tpope/vim-eunuch'
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-rails'
Plug 'Yggdroot/indentLine'
Plug 'maximbaz/lightline-ale'
Plug 'chaoren/vim-wordmotion'
Plug 'jparise/vim-graphql'

call plug#end()
unlet pluginsPath

:lua require("treesitter")

" SETTINGS
"
set autoindent
set backspace=indent,eol,start
set ch=2
set cmdheight=1
set confirm
set cursorline
set directory=~/.vim-tmp/,~/.tmp/,~/tmp/,/var/tmp/,/tmp
set encoding=utf-8
set expandtab
set hidden
set history=50
set hlsearch
set ignorecase
set incsearch
set laststatus=2
set lazyredraw
set linebreak
set listchars=tab:▶\ ,eol:¬
set loadplugins
set modelines=1
set nobackup
set nojoinspaces
set noshowmode
set nowrap
set number
set numberwidth=5
set ruler
set scrolloff=5
set shell=/bin/zsh
set shiftwidth=2
set shortmess+=c
set showcmd
set signcolumn=yes
set smartcase
set smarttab
set softtabstop=2
set tabstop=2
set tags=./TAGS,TAGS
set textwidth=0
set timeoutlen=250
set updatetime=300
set wildignore=*.swp,.git,.svn,*.log,*.gif,*.jpeg,*.jpg,*.png,*.pdf,tmp/**,.DS_STORE,.DS_Store

syntax on
set termguicolors
colorscheme snazzy

" Slower but more accurate syntax highlighting for javascript/typescript files
autocmd BufEnter *.{js,jsx,ts,tsx} :syntax sync fromstart
autocmd BufLeave *.{js,jsx,ts,tsx} :syntax sync clear

if executable("ag")
  set grepprg=ag\ --nogroup\ --nocolor
else
  set grepprg=grep\ -nH\ $*
endif

if has("mouse")
  set mouse=a
endif

"Allows remapping of Ctrl-j
let g:BASH_Ctrl_j = "off"

" Move up and down over screen lines instead of file lines
nnoremap j gj
nnoremap k gk
nnoremap <c-j> 5gj
nnoremap <c-k> 5gk
nnoremap <c-h> 5h
nnoremap <c-l> 5l

inoremap <c-j> <Down>
inoremap <c-k> <Up>
inoremap <c-h> <Left>
inoremap <c-l> <Right>

vnoremap <c-j> 5gj
vnoremap <c-k> 5gk
vnoremap <c-h> 5h
vnoremap <c-l> 5l

command! W :w
command! Q :q
command! QW :wq
command! Qw :wq
command! WQ :wq
command! Wq :wq

map <space> <leader>

"""""""""""""""" COC

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
if has('nvim')
  inoremap <silent><expr> <c-space> coc#refresh()
else
  inoremap <silent><expr> <c-@> coc#refresh()
endif

" Make <CR> auto-select the first completion item and notify coc.nvim to
" format on enter, <cr> could be remapped by other vim plugin
inoremap <silent><expr> <cr> pumvisible() ? coc#_select_confirm()
                              \: "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"

nmap <silent> [g <Plug>(coc-diagnostic-prev)
nmap <silent> ]g <Plug>(coc-diagnostic-next)

nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

nnoremap <silent> K :call <SID>show_documentation()<CR>

function! s:show_documentation()
  if (index(['vim','help'], &filetype) >= 0)
    execute 'h '.expand('<cword>')
  elseif (coc#rpc#ready())
    call CocActionAsync('doHover')
  else
    execute '!' . &keywordprg . " " . expand('<cword>')
  endif
endfunction

" Highlight symbol under cursor on CursorHold
" Coc seems to not like graphql files for this
let blacklist = ['graphql']
autocmd CursorHold * if index(blacklist, &ft) < 0 | silent call CocActionAsync('highlight')

nmap <leader>rn <Plug>(coc-rename)

augroup mygroup
  autocmd!
  " Setup :gq for to use coc
  autocmd FileType typescript,typescriptreact,javascript,javascriptreact,json setl indentexpr=CocAction('formatSelected')
  autocmd User CocJumpPlaceholder call CocActionAsync('showSignatureHelp')
augroup end

" Remap for do codeAction of selected region, ex: `<leader>aap` for current paragraph
xmap <leader>a  <Plug>(coc-codeaction-selected)
nmap <leader>a  <Plug>(coc-codeaction-selected)

" Remap for do codeAction of current line
nmap <leader>ac  <Plug>(coc-codeaction)
" Fix autofix problem of current line
nmap <leader>qf  <Plug>(coc-fix-current)

" Map function and class text objects
xmap if <Plug>(coc-funcobj-i)
omap if <Plug>(coc-funcobj-i)
xmap af <Plug>(coc-funcobj-a)
omap af <Plug>(coc-funcobj-a)
xmap ic <Plug>(coc-classobj-i)
omap ic <Plug>(coc-classobj-i)
xmap ac <Plug>(coc-classobj-a)
omap ac <Plug>(coc-classobj-a)

" Remap <C-f> and <C-b> for scroll float windows/popups.
if has('nvim-0.4.0') || has('patch-8.2.0750')
  nnoremap <silent><nowait><expr> <C-f> coc#float#has_scroll() ? coc#float#scroll(1) : "\<C-f>"
  nnoremap <silent><nowait><expr> <C-b> coc#float#has_scroll() ? coc#float#scroll(0) : "\<C-b>"
  inoremap <silent><nowait><expr> <C-f> coc#float#has_scroll() ? "\<c-r>=coc#float#scroll(1)\<cr>" : "\<Right>"
  inoremap <silent><nowait><expr> <C-b> coc#float#has_scroll() ? "\<c-r>=coc#float#scroll(0)\<cr>" : "\<Left>"
  vnoremap <silent><nowait><expr> <C-f> coc#float#has_scroll() ? coc#float#scroll(1) : "\<C-f>"
  vnoremap <silent><nowait><expr> <C-b> coc#float#has_scroll() ? coc#float#scroll(0) : "\<C-b>"
endif

" Use CTRL-S for selections ranges.
nmap <silent> <C-s> <Plug>(coc-range-select)
xmap <silent> <C-s> <Plug>(coc-range-select)

command! -nargs=0 Format :call CocAction('format')
command! -nargs=? Fold :call CocAction('fold', <f-args>)
command! -nargs=0 OR   :call     CocAction('runCommand', 'editor.action.organizeImport')

nmap <leader>y :Format<CR>
command! -nargs=0 Prettier :CocCommand prettier.formatFile
command! -nargs=0 EslintFix :CocCommand eslint.executeAutofix
nmap <leader>f :EslintFix<CR>

let g:coc_status_error_sign = '✘'

" Enable per-command history.
" CTRL-N and CTRL-P will be automatically bound to next-history and
" previous-history instead of down and up. If you don't like the change,
" explicitly bind the keys to down and up in your $FZF_DEFAULT_OPTS.
let g:fzf_history_dir = '~/.local/share/fzf-history'

nnoremap <silent> <C-p> :Files<CR>
" nnoremap <silent> <Bslash>[ :GFiles<CR>
" nnoremap <silent> <Bslash>] :Ag<CR>
" nnoremap <silent> <Bslash>o :Ag<CR>

"""""""""""""""" ALE
let g:ale_enabled = 1
let g:ale_fix_on_save = 1
let g:ale_fixers = { '*': ['remove_trailing_lines', 'trim_whitespace'] }
let g:ale_lint_delay = 300
let g:ale_linters_explicit = 1
let g:ale_set_highlights = 1
let g:ale_sign_error = '✘'
let g:ale_sign_warning = '>>'
let g:ale_sign_info= '♦'
let g:ale_use_global_executables = 0

"""""""""""""""" COMMENTARY
xmap <C-_> <Plug>Commentary
omap <C-_> <Plug>Commentary
nmap <C-_> <Plug>CommentaryLine

"""""""""""""""" TEST
nmap <silent> <Leader>n :TestNearest<CR>
nmap <silent> <Leader>t :TestFile<CR>
nmap <silent> <Leader>s :TestSuite<CR>

let test#strategy = "floaterm"
let test#ruby#rspec#executable = 'bundle exec rspec'
let g:test#javascript#jest#executable = 'yarn run jest --coverage=true'
let g:test#ruby#rspec#options = {
      \ 'file':    '--format documentation',
      \ 'suite':   '--format documentation',
      \ 'nearest': '--format documentation',
      \}

"""""""""""""""" NETRW
let g:netrw_banner = 0
let g:netrw_winsize = 25
let g:netrw_list_hide= '*.DS_Store'

"""""""""""""""" LIGHTLINE
let g:lightline = {
      \ 'colorscheme': 'snazzy',
      \ 'active': {
      \   'left': [
      \     [ 'mode', 'paste' ],
      \     [ 'git', 'filename', 'diagnostic', 'readonly', 'modified' ],
      \     ['gitbranch', 'cocstatus'],
      \
      \   ],
      \   'right': [
      \     [ 'linter_checking', 'linter_errors', 'linter_warnings', 'linter_infos', 'linter_ok' ],
      \     [ 'filetype', 'fileencoding', 'lineinfo', ],
      \     [ 'blame' ],
      \   ],
      \ },
      \  'component_function': {
      \     'gitbranch': 'fugitive#head',
      \     'cocstatus': 'coc#status',
      \     'filename': 'LightlineFilename',
      \  },
      \}
let g:lightline.component_expand = {
      \  'linter_checking': 'lightline#ale#checking',
      \  'linter_infos': 'lightline#ale#infos',
      \  'linter_warnings': 'lightline#ale#warnings',
      \  'linter_errors': 'lightline#ale#errors',
      \  'linter_ok': 'lightline#ale#ok',
      \ }
let g:lightline.component_type = {
      \  'linter_checking': 'left',
      \  'linter_infos': 'right',
      \  'linter_warnings': 'warning',
      \  'linter_errors': 'error',
      \  'linter_ok': 'left',
      \ }

function! LightlineFilename()
  let root = fnamemodify(get(b:, 'git_dir'), ':h')
  let path = expand('%:p')
  if path[:len(root)-1] ==# root
    return path[len(root)+1:]
  endif
  return expand('%')
endfunction

let g:lightline#ale#indicator_errors= '✘'
let g:lightline#ale#indicator_warnings = '♦'

"""""""""""""""" BUFFERS
nmap <space><space> <C-^>

"""""""""""""""" FLOATERM
let g:floaterm_keymap_new    = '<F7>'
let g:floaterm_keymap_prev   = '<F8>'
let g:floaterm_keymap_next   = '<F9>'
let g:floaterm_keymap_toggle = '<F10>'
let g:floaterm_borderchars = "─│─│╭╮╯╰"

"""""""""""""""" TESTING
silent! helptags ALL

" Remap terminal normal mode to C-d
tnoremap <C-d> <C-\><C-n>

nmap <c-s><c-a> :w<cr>
imap <c-s><c-a> <esc>:w<cr>
" DEBUG COC
" let g:node_client_debug = 1
" :call coc#client#open_log()
"
" PROFILE VIM
" :profile start profile.log
" :profile func *
" :profile file *
