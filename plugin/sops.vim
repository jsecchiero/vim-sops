" sops.vim - Vim plugin for Mozilla sops
" Maintainer:	Jacopo Secchiero

if exists("g:loaded_sops")
  finish
endif
let g:loaded_sops = 1

let s:save_cpo = &cpo
set cpo&vim

let g:sops_files_match = "{sops-*,*.sops,*secret*}"
let g:sops_messages = []
let g:sops_decrypted_pid = {}
let g:sops_decrypted_source = {}
let g:sops_previous_line = {}

function SopsSource()
  let current_file = @%
  if (has_key(g:sops_decrypted_source, current_file) == 1)
    echom g:sops_decrypted_source[current_file]
  endif
endfunction

function s:decrypt(filepath)
  " try to decrypt the file
  " if not possible open it normally
  call add(g:sops_messages, a:filepath . " start decrypt")

  let cmd_decrypt = "sops -d " . a:filepath
  let cmd_decrypt_output = system(cmd_decrypt)
  if (v:shell_error)
    call add(g:sops_messages, a:filepath . " is not decryptable, open it normally")
    exe "0read " . a:filepath

    " recover line if file was previously closed
    let sops_original_file = s:get_sops_source_file(a:filepath)
    let g:sops_decrypted_source[a:filepath] = sops_original_file
    if (has_key(g:sops_previous_line, sops_original_file) == 1)
      call add(g:sops_messages, a:filepath . " restore line to " .
             \ g:sops_previous_line[sops_original_file])
      exe g:sops_previous_line[sops_original_file]
    endif

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

    return
  endif

  " start a vim server in this session
  " will be used by sops to connect to it
  " NOTE: at the time of this writing, there
  "       is not a method to stop the server
  if v:servername == ""
    call remote_startserver('VIM')
    let g:sops_debug = "server started"
  endif

  call add(g:sops_messages, a:filepath . " start open")

  " sops will use current vim server as a editor
  " print pid
  let cmd_open = 'EDITOR=''vi --servername ' . v:servername    .
               \ ' --remote-wait'' sops ' . a:filepath . ' & ' .
               \ ' echo -n $!'
  let cmd_open_pid = system(cmd_open)
  call add(g:sops_messages,a:filepath . " sops pid " . cmd_open_pid)
  let g:sops_decrypted_pid[a:filepath] = cmd_open_pid

  " delete current buffer since will be opened a new one
  if bufexists(a:filepath) > 0
    " switch to previous buffer before deleting it
    " this helps to preserve the current window number and position
    exe "bp"
    " delete the current buffer since a new one will be opened
    exe "bw " . a:filepath
  endif
endfunction

" search filepath in any sops filedescriptor
" and if is found get the original encrypted file
function s:get_sops_source_file(filepath)
  let sops_original_file = ""
  for [key, value] in items(g:sops_decrypted_pid)
    let cmd_get_file_descriptors = "for s in $(ls /proc/" . value . "/fd/*); do " .
                                 \ "  readlink $s; " .
                                 \ "done"

    let cmd_get_file_descriptors_output = system(cmd_get_file_descriptors)
    for f in split(cmd_get_file_descriptors_output, "\n", 1)
      if f == a:filepath
        let sops_original_file = key
      endif
    endfor
  endfor
  return sops_original_file
endfunction

function s:update(filepath)
  call add(g:sops_messages, a:filepath + " start update")

  let sops_original_file = s:get_sops_source_file(a:filepath)

  " if filepath is not found in any sops fd,
  " treat it as a normal file: do nothing
  if sops_original_file == ""
    call add(g:sops_messages, a:filepath + " no file found")
    return
  endif

  " save the line position
  let line_position = line(".")
  let g:sops_previous_line[sops_original_file] = line_position

  " close the client
  " TODO: what in case of more clients?
  call server2client(expand("<client>"), '<Esc>:q!<CR>')
  " switch to previous buffer before deleting it
  " this helps to preserve the current window number and position
  exe "bp"
  " delete the current buffer since a new one will be opened
  exe "bw " a:filepath

  " reopen the updated file
  call s:decrypt(sops_original_file)
endfunction

augroup Sops
  autocmd!

  exe "autocmd BufReadCmd "   . g:sops_files_match . " " .
    \ "call s:decrypt(resolve(expand(\"<afile>\")))"

  " if i'm writing on a sops managed file, consolidate each write
  " on the encrypted file, this helps to mantain a normal vi workflow
  " otherwise the file is saved only when the buffer is closed
  exe "autocmd BufWritePost " . g:sops_files_match . " " .
    \ "call s:update(resolve(expand(\"<afile>\")))"

augroup END

command SopsSource call SopsSource()

let &cpo = s:save_cpo
unlet s:save_cpo
