set updatetime=300                      " Faster completion
set scroll=15
set timeoutlen=100                      " By default timeoutlen is 1000 ms
set number relativenumber
inoremap jk <Esc>
inoremap kj <Esc>
nmap R <c-n>:%s///g<left><left>
" WSL yank support
let s:clip = 'C:\Windows\System32\clip.exe'  " change this path according to your mount point
if executable(s:clip)
    augroup WSLYank
        autocmd!
        autocmd TextYankPost * if v:event.operator ==# 'y' | call system(s:clip, @0) | endif
    augroup END
endif
nnoremap <C-w> <Cmd>call VSCodeNotify('workbench.action.closeActiveEditor')<CR>
