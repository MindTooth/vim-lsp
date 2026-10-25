" Run from the plugin root: nvim --headless -u NONE -i NONE -S this-file
set noswapfile completeopt=menuone,noselect
execute 'set runtimepath^=' . fnameescape(getcwd())
let g:lsp_completion_documentation_enabled = 0
runtime plugin/lsp.vim
call lsp#ui#vim#completion#_setup()
let s:text = "\"key\": {\n\"value\": 42\n}"
function! CompleteMultilineSnippet() abort
    let l:result = lsp#omni#get_vim_completion_items({
        \ 'server': {'name': ''},
        \ 'position': {'line': 0, 'character': 0},
        \ 'response': {'result': [{'label': 'example', 'insertTextFormat': 2, 'insertText': s:text}]},
        \ })
    call complete(l:result.startcol, l:result.items)
    return ''
endfunction
let s:phase = 0
let s:ticks = 0
function! s:tick(timer) abort
    let s:ticks += 1
    if s:phase == 0 && pumvisible()
        call feedkeys("\<C-n>\<C-y>", 't')
        let s:phase = 1
        let s:ticks = 0
        return
    elseif s:phase == 1 && s:ticks > 5
        call assert_equal(split(s:text, "\n"), getline(1, '$'), 'accept the entire multiline snippet once')
    elseif s:ticks < 100
        return
    else
        call add(v:errors, 'completion did not finish')
    endif
    call timer_stop(a:timer)
    if $COMPLETION_RESULT !=# '' | call writefile(v:errors, $COMPLETION_RESULT) | endif
    if !empty(v:errors)
        for error in v:errors | echomsg error | endfor
        cquit
    endif
    qa!
endfunction
call timer_start(20, function('s:tick'), {'repeat': -1})
call feedkeys("i\<C-r>=CompleteMultilineSnippet()\<CR>", 't')
