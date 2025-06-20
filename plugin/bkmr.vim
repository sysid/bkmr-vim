" plugin/bkmr.vim
" bkmr.vim: Direct bkmr snippet integration for vim
" Author: sysid
" Version: 1.0.1
" License: MIT

if exists('g:loaded_bkmr') || &compatible
  finish
endif
let g:loaded_bkmr = 1

" Configuration
let g:bkmr_binary = get(g:, 'bkmr_binary', 'bkmr')
let g:bkmr_enabled = get(g:, 'bkmr_enabled', 1)
let g:bkmr_max_completions = get(g:, 'bkmr_max_completions', 50)
let g:bkmr_trigger_char = get(g:, 'bkmr_trigger_char', ':')
let g:bkmr_debug = get(g:, 'bkmr_debug', 0)

" Internal state
let s:bkmr_cache = {}
let s:cache_timeout = 300  " 5 minutes

" Check if bkmr is available
function! s:check_bkmr_available() abort
  if !executable(g:bkmr_binary)
    if g:bkmr_debug
      echom 'bkmr binary not found: ' . g:bkmr_binary
    endif
    return 0
  endif
  return 1
endfunction

" Extract snippet query from current line
function! s:extract_snippet_query() abort
  let line = getline('.')
  let col = col('.') - 1

  " Get text before cursor
  let before_cursor = line[:col-1]

  " Find last trigger character
  let trigger_pos = strridx(before_cursor, g:bkmr_trigger_char)
  if trigger_pos == -1
    return ''
  endif

  " Check if it's a valid snippet context (not URL, time, etc.)
  if trigger_pos > 0
    let char_before = before_cursor[trigger_pos-1]
    if char_before =~# '[a-zA-Z0-9pt]'
      return ''
    endif
  endif

  " Extract query after trigger
  let after_trigger = before_cursor[trigger_pos+1:]

  " Only proceed if no whitespace and valid identifier chars
  if after_trigger =~# '^\w*$'
    return after_trigger
  endif

  return ''
endfunction

" Fetch snippets from bkmr
function! s:fetch_snippets(query) abort
  let cmd = [g:bkmr_binary, 'search', '--json', '--interpolate', '-t', '_snip_', '--limit', string(g:bkmr_max_completions)]

  " Add search term if query is not empty
  if !empty(a:query)
    call add(cmd, 'metadata:' . a:query . '*')
  endif

  if g:bkmr_debug
    echom 'Executing: ' . join(cmd, ' ')
  endif

  try
    let output = system(join(cmd, ' '))
    if v:shell_error != 0
      if g:bkmr_debug
        echom 'bkmr command failed: ' . output
      endif
      return []
    endif

    if empty(trim(output))
      return []
    endif

    return json_decode(output)
  catch
    if g:bkmr_debug
      echom 'Failed to parse bkmr output: ' . v:exception
    endif
    return []
  endtry
endfunction

" Convert snippets to vim completion format
function! s:snippets_to_completions(snippets, query) abort
  let completions = []

  for snippet in a:snippets
    let item = {
      \ 'word': snippet.url,
      \ 'abbr': snippet.title,
      \ 'menu': 'bkmr #' . snippet.id,
      \ 'info': len(snippet.url) > 500 ? snippet.url[:500] . '...' : snippet.url,
      \ 'kind': 's',
      \ 'dup': 1
      \ }

    " If snippet content doesn't start with query, prefix it for better matching
    if !empty(a:query) && snippet.url !~? '^' . escape(a:query, '.*[]^$\\')
      let item.word = a:query . ' ' . snippet.url
    endif

    call add(completions, item)
  endfor

  return completions
endfunction

" Main completion function
function! bkmr#complete(findstart, base) abort
  if !g:bkmr_enabled || !s:check_bkmr_available()
    return a:findstart ? -1 : []
  endif

  if a:findstart
    " Find start of completion
    let line = getline('.')
    let col = col('.') - 1
    let before_cursor = line[:col-1]

    let trigger_pos = strridx(before_cursor, g:bkmr_trigger_char)
    if trigger_pos == -1
      return -1
    endif

    " Check if it's a valid snippet context
    if trigger_pos > 0
      let char_before = before_cursor[trigger_pos-1]
      if char_before =~# '[a-zA-Z0-9pt]'
        return -1
      endif
    endif

    " Return position after trigger character
    return trigger_pos + 1
  else
    " Return completions
    let query = a:base

    if g:bkmr_debug
      echom 'Completion query: ' . query
    endif

    " Check cache first
    let cache_key = 'query:' . query
    let now = localtime()

    if has_key(s:bkmr_cache, cache_key) &&
     \ (now - s:bkmr_cache[cache_key].timestamp) < s:cache_timeout
      if g:bkmr_debug
        echom 'Using cached results'
      endif
      return s:bkmr_cache[cache_key].data
    endif

    " Fetch fresh results
    let snippets = s:fetch_snippets(query)
    let completions = s:snippets_to_completions(snippets, query)

    " Cache results
    let s:bkmr_cache[cache_key] = {
      \ 'data': completions,
      \ 'timestamp': now
      \ }

    if g:bkmr_debug
      echom 'Returning ' . len(completions) . ' completions'
    endif

    return completions
  endif
endfunction

" Auto-completion setup
function! s:setup_completion() abort
  if !g:bkmr_enabled
    return
  endif

  setlocal omnifunc=bkmr#complete
  setlocal completeopt+=menuone,noinsert

  " Set up trigger-based completion
  if !empty(g:bkmr_trigger_char)
    execute 'inoremap <buffer> ' . g:bkmr_trigger_char . ' ' . g:bkmr_trigger_char . '<C-x><C-o>'
  endif
endfunction

" Manual completion trigger
function! bkmr#trigger_completion() abort
  if !g:bkmr_enabled || !s:check_bkmr_available()
    return ''
  endif

  let query = s:extract_snippet_query()
  if empty(query)
    " Not in snippet context, just insert trigger char
    return g:bkmr_trigger_char
  endif

  " Trigger completion
  return "\<C-x>\<C-o>"
endfunction

" Open snippet by ID
function! bkmr#open_snippet(id) abort
  if !s:check_bkmr_available()
    echohl ErrorMsg | echo 'bkmr binary not available' | echohl None
    return
  endif

  let cmd = g:bkmr_binary . ' open ' . a:id
  let output = system(cmd)

  if v:shell_error == 0
    echo 'Opened snippet #' . a:id
  else
    echohl ErrorMsg | echo 'Failed to open snippet: ' . output | echohl None
  endif
endfunction

" Clear cache
function! bkmr#clear_cache() abort
  let s:bkmr_cache = {}
  echo 'bkmr cache cleared'
endfunction

" Status function
function! bkmr#status() abort
  echo 'bkmr.vim status:'
  echo '  Enabled: ' . g:bkmr_enabled
  echo '  Binary: ' . g:bkmr_binary . (executable(g:bkmr_binary) ? ' (found)' : ' (NOT FOUND)')
  echo '  Trigger: ' . g:bkmr_trigger_char
  echo '  Cache entries: ' . len(s:bkmr_cache)
  echo '  Max completions: ' . g:bkmr_max_completions
endfunction

" Search and select snippet
function! bkmr#search_snippets() abort
  if !s:check_bkmr_available()
    echohl ErrorMsg | echo 'bkmr binary not available' | echohl None
    return
  endif

  let query = input('Search snippets: ')
  if empty(query)
    return
  endif

  let snippets = s:fetch_snippets(query)
  if empty(snippets)
    echo 'No snippets found'
    return
  endif

  " Create selection list
  let choices = ['Select snippet:']
  let index = 1
  for snippet in snippets
    call add(choices, index . '. ' . snippet.title . ' (#' . snippet.id . ')')
    let index += 1
  endfor

  let choice = inputlist(choices)
  if choice > 0 && choice <= len(snippets)
    let selected = snippets[choice - 1]

    " Insert snippet content at cursor
    let lines = split(selected.url, '\n')
    if len(lines) == 1
      execute 'normal! a' . selected.url
    else
      call append(line('.'), lines[1:])
      call setline(line('.'), getline('.') . lines[0])
    endif
  endif
endfunction

" Commands
command! BkmrStatus call bkmr#status()
command! BkmrClearCache call bkmr#clear_cache()
command! BkmrSearch call bkmr#search_snippets()
command! -nargs=1 BkmrOpen call bkmr#open_snippet(<args>)

" Default key mappings (can be overridden by user)
if !exists('g:bkmr_no_default_mappings') || !g:bkmr_no_default_mappings
  " Insert mode: trigger completion with :
  execute 'inoremap <expr> ' . g:bkmr_trigger_char . ' bkmr#trigger_completion()'

  " Normal mode mappings
  nnoremap <silent> <leader>bs :BkmrSearch<CR>
  nnoremap <silent> <leader>bc :call bkmr#clear_cache()<CR>
  nnoremap <silent> <leader>bst :BkmrStatus<CR>

  " Insert mode manual trigger (alternative to <C-x><C-o>)
  inoremap <silent> <leader><C-o> <C-x><C-o>
endif

" Auto-setup for all buffers
augroup bkmr_setup
  autocmd!
  autocmd BufEnter * call s:setup_completion()
augroup END

" Plugin loaded message
if g:bkmr_debug
  echom 'bkmr.vim loaded with trigger: ' . g:bkmr_trigger_char
endif
