" Run from the plugin root: nvim --headless -u NONE -i NONE -S this-file
set noswapfile completeopt=menuone,noselect
set lines=40 columns=120
execute 'set runtimepath^=' . fnameescape(getcwd())
let g:lsp_completion_documentation_enabled = 0
runtime plugin/lsp.vim
call assert_equal(0, get(g:, 'lsp_completion_documentation_snippet_enabled', -1), 'snippet preview defaults off')
runtime autoload/lsp/internal/completion/documentation.vim
let s:scripts = filter(split(execute('scriptnames'), "\n"),
    \ 'v:val =~# "completion/documentation.vim$"')
let s:sid = matchstr(s:scripts[0], '\d\+')
let s:Show = function('<SNR>' . s:sid . '_show_floating_window')
let s:GetWindow = function('<SNR>' . s:sid . '_get_doc_win')
let s:event = {}
autocmd CompleteChanged * let s:event = copy(v:event)
function! PreviewComplete() abort
    call complete(1, [{'word': 'example', 'empty': 1}])
    return ''
endfunction
let s:ticks = 0
function! s:tick(timer) abort
    let s:ticks += 1
    if !pumvisible() && s:ticks < 100 | return | endif
    try
        call assert_true(pumvisible(), 'completion menu must be visible')
        let l:snippet = "\"key\": {\n\t\"value\": ${1:42}\n}$0"
        let l:before = getline(1, '$')
        call s:Show(s:event, {'completion_item': {'label': 'example', 'insertTextFormat': 2,
            \ 'insertText': l:snippet, 'documentation': 'Existing documentation'}})
        call assert_equal(['Existing documentation'], getbufline(s:GetWindow().get_bufnr(), 1, '$'), 'default preserves documentation')
        let g:lsp_completion_documentation_snippet_enabled = 1
        for l:field in ['insertText', 'textEdit', 'label']
            let l:item = {'label': l:snippet, 'insertTextFormat': 2,
                \ 'detail': 'Existing detail', 'documentation': 'Existing documentation'}
            if l:field ==# 'textEdit'
                let l:item.textEdit = {'newText': l:snippet}
                let l:item.insertText = 'wrong fallback'
            elseif l:field ==# 'insertText'
                let l:item.insertText = l:snippet
                let l:item.textEdit = v:null
            endif
            call s:Show(s:event, {'completion_item': l:item})
            let l:window = s:GetWindow()
            let l:contents = join(getbufline(l:window.get_bufnr(), 1, '$'), "\n")
            call assert_true(l:window.is_visible(), l:field . ': preview visible')
            call assert_true(stridx(l:contents, l:snippet) >= 0, l:field . ': full snippet')
            call assert_true(stridx(l:contents, 'Existing detail') >= 0, 'detail retained')
            call assert_true(stridx(l:contents, 'Existing documentation') >= 0, 'documentation retained')
            call assert_equal(l:before, getline(1, '$'), 'preview must not edit the buffer')
        endfor
        let g:lsp_completion_documentation_snippet_enabled = 0
        call s:Show(s:event, {'completion_item': {'label': 'example', 'insertTextFormat': 2,
            \ 'insertText': l:snippet, 'documentation': 'Existing documentation'}})
        call assert_equal(['Existing documentation'], getbufline(s:GetWindow().get_bufnr(), 1, '$'), 'explicitly disabling restores documentation')
        let g:lsp_completion_documentation_snippet_enabled = 1
        call s:Show(s:event, {'completion_item': {'label': 'plain', 'insertText': 'hidden text', 'documentation': 'Ordinary docs'}})
        let l:contents = join(getbufline(s:GetWindow().get_bufnr(), 1, '$'), "\n")
        call assert_equal('Ordinary docs', l:contents, 'ordinary completion unchanged')
    catch
        call add(v:errors, v:exception . ' at ' . v:throwpoint)
    endtry
    call timer_stop(a:timer)
    if $PREVIEW_RESULT !=# '' | call writefile(v:errors, $PREVIEW_RESULT) | endif
    if !empty(v:errors)
        for error in v:errors | echomsg error | endfor
        cquit
    endif
    qa!
endfunction
call timer_start(20, function('s:tick'), {'repeat': -1})
call feedkeys("i\<C-r>=PreviewComplete()\<CR>", 't')
