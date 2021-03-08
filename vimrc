set nocompatible
setglobal path=.,,
if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin('~/.vim/plugged')

let g:SnazzyTransparent = 1
let g:ale_set_balloons = 1

" Essentials
"
Plug 'connorholyday/vim-snazzy'
Plug 'itchyny/lightline.vim'
Plug 'janko/vim-test'
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'voldikss/vim-floaterm'
Plug 'w0rp/ale'
Plug 'sheerun/vim-polyglot'


Plug 'Yggdroot/indentLine'
Plug 'chaoren/vim-wordmotion'
Plug 'maximbaz/lightline-ale'
Plug 'tpope/vim-abolish'
Plug 'tpope/vim-bundler'
Plug 'tpope/vim-commentary'
Plug 'tpope/vim-dispatch'
Plug 'tpope/vim-eunuch'
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-projectionist'
Plug 'tpope/vim-rails'
Plug 'tpope/vim-repeat'
Plug 'tpope/vim-sensible'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-vinegar'

call plug#end()

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
set t_Co=256
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

"Use <c-space> to trigger completion.
inoremap <silent><expr> <c-@> coc#refresh()


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
autocmd CursorHold * silent call CocActionAsync('highlight')

nmap <leader>rn <Plug>(coc-rename)

augroup mygroup
  autocmd!
  " Setup :gq for to use coc
  autocmd FileType typescript,typescriptreact,javascript,javascriptreact,json setl indentexpr=CocAction('formatSelected')
  autocmd User CocJumpPlaceholder call CocActionAsync('showSignatureHelp')
augroup end

xmap <leader>a  <Plug>(coc-codeaction-selected)
nmap <leader>a  <Plug>(coc-codeaction-selected)
nmap <leader>ac  <Plug>(coc-codeaction)
nmap <leader>qf  <Plug>(coc-fix-current)

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

nnoremap <silent> <C-p> :Files<CR>

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

"""""""""""""""" TESTING
silent! helptags ALL

nmap <c-s><c-a> :w<cr>
imap <c-s><c-a> <esc>:w<cr>

"""""""""""""""" FZF
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

let g:fzf_history_dir = '~/.local/share/fzf-history'
