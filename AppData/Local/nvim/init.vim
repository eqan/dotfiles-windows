set updatetime=300                      " Faster completion
set scroll=15
set timeoutlen=100                      " By default timeoutlen is 1000 ms
set number relativenumber
imap [] <Esc>
imap kj <Esc>
nmap R <c-n>:%s///g<left><left>
" Native Windows clipboard integration.
" clip.exe handles copy; PowerShell provides raw text for paste.
let g:clipboard = {
      \ 'name': 'windows-clipboard',
      \ 'copy': {
      \   '+': ['clip.exe'],
      \   '*': ['clip.exe'],
      \ },
      \ 'paste': {
      \   '+': ['powershell.exe', '-NoProfile', '-Command', '[Console]::Out.Write((Get-Clipboard -Raw))'],
      \   '*': ['powershell.exe', '-NoProfile', '-Command', '[Console]::Out.Write((Get-Clipboard -Raw))'],
      \ },
      \ 'cache_enabled': 0,
      \ }
set clipboard=unnamedplus
nnoremap <C-w> <Cmd>call VSCodeNotify('workbench.action.closeActiveEditor')<CR>
