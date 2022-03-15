# vim-sops

Vim plugin for encrypt/decrypt sops files on the fly without leaving your vi session

## prerequisite

require `+clientserver` in your vim (check it with `vi --version`)


take care that wildignore doesn't have /tmp otherwise this will not work  
sops use tmp to store temporary decrypted files. check with  

```
set wildignore?
```

## install

```
git clone https://github.com/jsecchiero/vim-sops.git ~/.vim/pack/plugins/start/vim-sops
```

## configure

sops files can vary in extension and filename, the default file are `"{sops-*,*.sops,*secret*}"`  

```
let g:sops_files_match = "{sops-*,*.sops,*secret*}"
```

## tips

you can specify a env at runtime in vim with:  

```
let $AWS_PROFILE="admin-prod"
```
