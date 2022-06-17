" be iMproved, required
set nocompatible	

"source plugins file			
so ~/bin/vim/plugins.vim

"----Visuals-----"
colorscheme atom-dark
syntax enable

"macvim-specifit line height
set linespace=17

"activate line numbers.
set number
set relativenumber

"set font and line height
set guifont=Operator_Mono_Lig:h16

set guioptions-=l
set guioptions-=L
set guioptions-=r
set guioptions-=R



"-----General Settings-----"
"make backspace behave like normal text editors.
set backspace=indent,eol,start



"-----Mappings-----"
"the default leader is \, but a comma is much better.
let mapleader = ','

"Make NerdTree toogle easier
nmap <D-S-e> :NERDTreeToggle<cr>



"---------Plugins---------"
let g:NERDTreeWinPos = "right"

nmap <C-T> :CtrlPBufTag<cr>

nmap <C-R> :CtrlPMRUFiles<cr>

nmap <D-p> :CtrlP<cr>


"---------Searching---------"
"highlight search
set hlsearch

"highlight incrementaly
set incsearch



"--------Mappings---------"
"make .vimrc easy to edit
nmap <Leader>ev :tabedit $MYVIMRC<cr>

"Add simple highlight removal.
nmap <Leader><space> :nohlsearch<cr>



"-------------Split Management-----
set splitbelow
set splitright

nmap <C-J> <C-W><C-J>
nmap <C-K> <C-W><C-K>
nmap <C-H> <C-W><C-H>
nmap <C-L> <C-W><C-L>



"---------Auto-Commands---------"
"automatically source the vimrc file on save.
augroup autosourcing
	autocmd!
	autocmd BufWritePost .vimrc source %
augroup END
