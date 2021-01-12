" prevent loading file twice
if exists("g:loaded_nredir")
  finish
endif

command! -nargs=1 -complete=command Nredir lua require'nredir'.nredir(<q-args>)

let g:loaded_nredir = 1
