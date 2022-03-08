" sops.vim - Vim plugin for Mozilla sops
" Maintainer:	Jacopo Secchiero

if exists("g:loaded_sops")
  finish
endif
let g:loaded_sops = 1

let s:save_cpo = &cpo
set cpo&vim

let g:sops_decrypted_files = {}

function s:decrypt(filepath)
  echom "decrypt start"
  let cmd = "sops -d " . a:filepath
  let output = system(cmd)
  if (v:shell_error)
    exe "0read " . a:filepath
    echom cmd
    echom output
    return
  endif
  " save encrypted file content as a backup
  let g:sops_decrypted_files[a:filepath] = readfile(a:filepath)

  echom cmd
  0put = output

  " highlight supported sops files
  if a:filepath =~ '.*.yaml' || a:filepath =~ '.*.yml'
    set filetype=yaml
  endif
  if a:filepath =~ '.*.json'
    set filetype=json
  endif
  if a:filepath =~ '.*.env'
    set filetype=env
  endif
  if a:filepath =~ '.*.ini'
    set filetype=ini
  endif
endfunction

function s:encrypt(filepath, filename, dirpath) abort
  if (has_key(g:sops_decrypted_files, a:filepath) == 0)
    return
  endif
  let cmd = "cd " . a:dirpath . " && sops -e " . a:filename
  let output = system(cmd)
  if (v:shell_error)
    echom cmd
    echom output
    let encrypted_backup = g:sops_decrypted_files[a:filepath]
    call writefile(encrypted_backup, glob("./" . a:filepath), 'b')
    return
  endif
  call writefile(split(output, "\n", 1), glob("./" . a:filepath), 'b')
  unlet g:sops_decrypted_files[a:filepath]
endfunction

autocmd BufReadCmd   sops-*,*.sops,*secret* call s:decrypt(resolve(expand("<afile>")))
autocmd BufWritePost sops-*,*.sops,*secret* call s:encrypt(
                                                \  resolve(expand("<afile>")),
                                                \  resolve(expand("<afile>:t")),
                                                \  resolve(expand("<afile>:p:h"))
                                                \)

let &cpo = s:save_cpo
unlet s:save_cpo
