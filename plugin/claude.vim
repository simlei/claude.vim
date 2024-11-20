" File: plugin/claude.vim

" ============================================================================
" Changes history
" ============================================================================

" Change History functionality
if !exists('g:claude_change_history')
  let g:claude_change_history = []
  let g:claude_change_history_pos = -1
endif

function! s:RecordChanges(changes)
  if empty(a:changes)
    return
  endif
  
  call add(g:claude_change_history, a:changes)
endfunction

function! s:ReplayLastChanges()
  if len(g:claude_change_history) == 0
    echom "No changes to replay"
    return
  endif
  
  let l:last_changes = g:claude_change_history[-1]
  call s:ApplyChanges(l:last_changes)
endfunction

nnoremap <F10>sR :call <SID>ReplayLastChanges()<CR>
nnoremap <F10>sP :call g:Claude__ApplyChangesFromResponse()<CR>


function! g:Claude__ApplyChangesFromResponse() abort
  APIClaudeWithChatWindowActive call s:ApplyChangesFromResponse()
endfun

" ============================================================================

command! -nargs=1 APIClaudeWithChatWindowActive call <SID>WithChatWindowActive(<f-args>)

" Winfocus-preserving go-to-claude function
function! s:WithChatWindowActive(expression) abort
  let l:result = "EMPTY"
  let [l:chat_bufnr, l:chat_winid, l:current_winid] = s:GetOrCreateChatWindow()
  try
    if win_gotoid(l:chat_winid) != 1
      throw "Failed to switch to chat window"
    endif
    let l:result = eval(a:expression)
  finally
    if win_gotoid(l:current_winid) != 1
      throw "Failed to restore original window focus"
    endif
  endtry

  return l:result
endfun



" ============================================================================
" Message History
" ============================================================================

if !exists('g:claude_message_history')
  let g:claude_message_history = []
endif

if !exists('g:claude_message_history_pos')
  let g:claude_message_history_pos = -1
endif

function! s:AddToMessageHistory(message)
  if empty(a:message)
    return
  endif
  
  call add(g:claude_message_history, a:message) 
  let g:claude_message_history_pos = len(g:claude_message_history) - 1
endfunction

function! s:RecallMessage(direction)
  if bufname('%') != 'Claude Chat'
    return ''
  endif

  let l:history_len = len(g:claude_message_history)
  if l:history_len == 0
    return ''
  endif

  let l:new_pos = g:claude_message_history_pos + a:direction
  
  if l:new_pos < 0 
    echom "Reached start of message history"
    return ''
  elseif l:new_pos >= l:history_len
    echom "Reached end of message history"
    return ''
  endif

  let g:claude_message_history_pos = l:new_pos
  let l:message = g:claude_message_history[g:claude_message_history_pos]
  
  " use V selection
  call setreg("z", l:message, "V")
  normal! G
  normal! "zp
  " call append('.', 'You: ' . l:message)
  normal! j$
endfunction

nnoremap <F9><Up> :call <SID>RecallMessage(-1)<CR>
inoremap <F9><Up> <C-o>:call <SID>RecallMessage(-1)<CR>
nnoremap <F9><Down> :call <SID>RecallMessage(1)<CR>
inoremap <F9><Down> <C-o>:call <SID>RecallMessage(1)<CR>

command! -nargs=1 SilentEchoMessage call s:SilentEchoMessage(eval(<q-args>))
function! s:SilentEchoMessage(message)
  echomsg a:message
  redraw
endfunction

command! -nargs=1 SilentEchoDebug call s:SilentEchoDebug(eval(<q-args>))
function! s:SilentEchoDebug(message)
  if g:claude_debug_enabled
    echomsg "DBG: " . a:message
    redraw
  endif
endfunction

" Configuration variables
if !exists('g:claude_debug_enabled')
  let g:claude_debug_enabled = 1
endif

if !exists('g:claude_api_key')
  let g:claude_api_key = ''
endif

if !exists('g:claude_api_url')
  let g:claude_api_url = 'https://api.anthropic.com/v1/messages'
endif

if !exists('g:claude_model')
  let g:claude_model = 'claude-3-5-sonnet-20241022'
endif

if !exists('g:claude_use_bedrock')
  let g:claude_use_bedrock = 0
endif

if !exists('g:claude_bedrock_region')
  let g:claude_bedrock_region = 'us-east-1'
endif

if !exists('g:claude_bedrock_model_id')
  let g:claude_bedrock_model_id = 'anthropic.claude-3-5-sonnet-20241022-v2:0'
endif
	
if !exists('g:claude_aws_profile')
  let g:claude_aws_profile = ''
endif

if !exists('g:claude_map_implement')
  let g:claude_map_implement = '<leader>ci'
endif

if !exists('g:claude_map_open_chat')
  let g:claude_map_open_chat = '<leader>cc'
endif

if !exists('g:claude_map_send_chat_message')
  let g:claude_map_send_chat_message = '<C-]>'
endif

if !exists('g:claude_map_cancel_response')
  let g:claude_map_cancel_response = '<leader>cx'
endif

" ============================================================================
" Keybindings setup
" ============================================================================

function! s:SetupClaudeKeybindings()

  command! -range -nargs=1 ClaudeImplement <line1>,<line2>call s:ClaudeImplement(<line1>, <line2>, <q-args>)
  execute "vnoremap " . g:claude_map_implement . " :ClaudeImplement<Space>"

  command! ClaudeChat call s:OpenClaudeChat()
  execute "nnoremap " . g:claude_map_open_chat . " :ClaudeChat<CR>"

  command! ClaudeCancel call s:CancelClaudeResponse()
  execute "nnoremap " . g:claude_map_cancel_response . " :ClaudeCancel<CR>"
endfunction

augroup ClaudeKeybindings
  autocmd!
  autocmd VimEnter * call s:SetupClaudeKeybindings()
augroup END

"""""""""""""""""""""""""""""""""""""

let s:plugin_dir = expand('<sfile>:p:h')

function! s:ClaudeLoadPrompt(prompt_type)
  let l:prompts_file = s:plugin_dir . '/claude_' . a:prompt_type . '_prompt.md'
  return readfile(l:prompts_file)
endfunction


function! s:ClaudeGetSystemPrompt() abort
  " I want it loaded everytime fresh
  let l:content = s:ClaudeLoadPrompt('system')
  return l:content
endf

" Add this near the top of the file, after other configuration variables
if !exists('g:claude_implement_prompt')
  let g:claude_implement_prompt = s:ClaudeLoadPrompt('implement')
endif



" ============================================================================
" Claude API
" ============================================================================

function! s:ClaudeQueryInternal(messages, system_prompt, tools, stream_callback, final_callback)
  " Prepare the API request
  let l:data = {}
  let l:headers = []
  let l:url = ''

  if g:claude_use_bedrock
    let l:python_script = s:plugin_dir . '/claude_bedrock_helper.py'
    let l:cmd = ['python3', l:python_script,
          \ '--region', g:claude_bedrock_region,
          \ '--model-id', g:claude_bedrock_model_id,
          \ '--messages', json_encode(a:messages),
          \ '--system-prompt', a:system_prompt]

    if !empty(g:claude_aws_profile)
      call extend(l:cmd, ['--profile', g:claude_aws_profile])
    endif

    if !empty(a:tools)
      call extend(l:cmd, ['--tools', json_encode(a:tools)])
    endif
  else
    let l:temp_base = tempname()
    let l:headers_file = fnamemodify(l:temp_base, ':r') . '.log'
    echom "LOG: exporting response headers to " . l:headers_file
    redraw
    let l:url = g:claude_api_url
    let l:data = {
      \ 'model': g:claude_model,
      \ 'max_tokens': 2048,
      \ 'messages': a:messages,
      \ 'stream': v:true
      \ }
    if !empty(a:system_prompt)
      let l:data['system'] = a:system_prompt
    endif
    if !empty(a:tools)
      let l:data['tools'] = a:tools
    endif
    call extend(l:headers, ['-H', 'Content-Type: application/json'])
    call extend(l:headers, ['-H', 'x-api-key: ' . g:claude_api_key])
    call extend(l:headers, ['-H', 'anthropic-version: 2023-06-01'])

    " Convert data to JSON
    let l:json_data = json_encode(l:data)
    let l:cmd = ['curl', '-s', '-N', '-X', 'POST', '-D', l:headers_file]
    call extend(l:cmd, l:headers)
    call extend(l:cmd, ['-d', l:json_data, l:url])
  endif

  " Start the job
  if has('nvim')
    let l:job = jobstart(l:cmd, {
      \ 'on_stdout': function('s:HandleStreamOutputNvim', [a:stream_callback, a:final_callback]),
      \ 'on_stderr': function('s:HandleJobErrorNvim', [a:stream_callback, a:final_callback]),
      \ 'on_exit': function('s:HandleJobExitNvim', [a:stream_callback, a:final_callback])
      \ })
  else
    let l:job = job_start(l:cmd, {
      \ 'out_cb': function('s:HandleStreamOutput', [a:stream_callback, a:final_callback]),
      \ 'err_cb': function('s:HandleJobError', [a:stream_callback, a:final_callback]),
      \ 'exit_cb': function('s:HandleJobExit', [a:stream_callback, a:final_callback])
      \ })
  endif

  return l:job
endfunction

function! s:DisplayTokenUsageAndCost(json_data)
  let l:data = json_decode(a:json_data)
  if has_key(l:data, 'usage')
    let l:usage = l:data.usage
    let l:input_tokens = exists('s:stored_input_tokens') ? s:stored_input_tokens : get(l:usage, 'input_tokens', 0)
    let l:output_tokens = get(l:usage, 'output_tokens', 0)

    let l:input_cost = (l:input_tokens / 1000000.0) * 3.0
    let l:output_cost = (l:output_tokens / 1000000.0) * 15.0

    echom printf("Token usage - Input: %d ($%.4f), Output: %d ($%.4f)", l:input_tokens, l:input_cost, l:output_tokens, l:output_cost)

    if exists('s:stored_input_tokens')
      unlet s:stored_input_tokens
    endif
  else
    echom "Error: Invalid JSON data format"
  endif
endfunction

function! s:HandleStreamOutput(stream_callback, final_callback, channel, msg)
  " Split the message into lines
  let l:lines = split(a:msg, "\n")
  for l:line in l:lines
    " Check if the line starts with 'data:'
    if l:line =~# '^data:'
      " Extract the JSON data
      let l:json_str = substitute(l:line, '^data:\s*', '', '')
      let l:response = json_decode(l:json_str)

      if l:response.type == 'content_block_start' && l:response.content_block.type == 'tool_use'
        let s:current_tool_call = {
              \ 'id': l:response.content_block.id,
              \ 'name': l:response.content_block.name,
              \ 'input': ''
              \ }
      elseif l:response.type == 'content_block_delta' && has_key(l:response.delta, 'type') && l:response.delta.type == 'input_json_delta'
        if exists('s:current_tool_call')
          let s:current_tool_call.input .= l:response.delta.partial_json
        endif
      elseif l:response.type == 'content_block_stop'
        if exists('s:current_tool_call')
          let l:tool_input = json_decode(s:current_tool_call.input)
          " XXX this is a bit weird layering violation, we should probably call the callback instead
          call s:AppendToolUse(s:current_tool_call.id, s:current_tool_call.name, l:tool_input)
          unlet s:current_tool_call
        endif
      elseif has_key(l:response, 'delta') && has_key(l:response.delta, 'text')
        let l:delta = l:response.delta.text
        call a:stream_callback(l:delta)
      elseif l:response.type == 'message_start' && has_key(l:response, 'message') && has_key(l:response.message, 'usage')
        let s:stored_input_tokens = get(l:response.message.usage, 'input_tokens', 0)
      elseif l:response.type == 'message_delta' && has_key(l:response, 'usage')
        call s:DisplayTokenUsageAndCost(l:json_str)
      elseif l:response.type != 'message_stop' && l:response.type != 'message_start' && l:response.type != 'content_block_start' && l:response.type != 'ping'
        if l:line =~# 'exceeded'
          let l:msg = substitute(a:msg, '\n', ' ', 'g')
          echom 'Error(exceeded): ' . l:msg
        endif
        call a:stream_callback('Unknown Claude protocol output: "' . l:line . "\"\n")
        " check for "exceeded" in the first line. if found, print as much of
        " the incoming message as possible using "echom".
      endif
    elseif l:line ==# 'event: ping'
      " Ignore ping events
    elseif l:line ==# 'event: error'
      call a:stream_callback('Error: Server sent an error event')
      call a:final_callback()
    elseif l:line ==# 'event: message_stop'
      call a:final_callback()
    elseif l:line !=# 'event: message_start' && l:line !=# 'event: message_delta' && l:line !=# 'event: content_block_start' && l:line !=# 'event: content_block_delta' && l:line !=# 'event: content_block_stop'
      if l:line =~# 'exceeded'
        let l:msg = substitute(a:msg, '\n', ' ', 'g')
        echom 'Error(exceeded): ' . l:msg
      endif
      call a:stream_callback('Unknown Claude protocol output: "' . l:line . "\"\n")
    endif
  endfor
endfunction

function! s:HandleJobError(stream_callback, final_callback, channel, msg)
  call a:stream_callback('Error: ' . a:msg)
  call a:final_callback()
endfunction

function! s:HandleJobExit(stream_callback, final_callback, job, status)
  if a:status != 0
    call a:stream_callback('Error: Job exited with status ' . a:status)
    call a:final_callback()
  endif
endfunction

function! s:HandleStreamOutputNvim(stream_callback, final_callback, job_id, data, event) dict
  for l:msg in a:data
    call s:HandleStreamOutput(a:stream_callback, a:final_callback, 0, l:msg)
  endfor
endfunction

function! s:HandleJobErrorNvim(stream_callback, final_callback, job_id, data, event) dict
  for l:msg in a:data
    if l:msg != ''
      call s:HandleJobError(a:stream_callback, a:final_callback, 0, l:msg)
    endif
  endfor
endfunction

function! s:HandleJobExitNvim(stream_callback, final_callback, job_id, exit_code, event) dict
  call s:HandleJobExit(a:stream_callback, a:final_callback, 0, a:exit_code)
endfunction



" ============================================================================
" Diff View
" ============================================================================

function! s:ApplyChange(normal_command, content)
  SilentEchoDebug "ApplyChange:0: start normal_command=" . a:normal_command . " content=" . a:content
  let l:view = winsaveview()
  SilentEchoDebug "ApplyChange:0.1"
  let l:paste_option = &paste
  SilentEchoDebug "ApplyChange:0.2"

  set paste

  SilentEchoDebug "ApplyChange:1:"
  let l:execute_payload = a:normal_command . '=a:content'
  let l:execute_payload = substitute(l:execute_payload, '<CR>', '', 'g')

  SilentEchoDebug "ApplyChange:2: executing; execute_payload=" . l:execute_payload
  SilentEchoDebug "ApplyChange:3: a:content=" . a:content[0:100]
  execute printf('normal %s', l:execute_payload)

  let &paste = l:paste_option
  call winrestview(l:view)
endfunction

function! s:ApplyVimexec(commands)
  SilentEchoDebug "ApplyVimexec:0: winid = " . win_getid()
  " let l:view = winsaveview()

  let l:paste_option = &paste
  set paste

  for cmd in a:commands
    SilentEchoDebug "ApplyVimexec:1: executing command=" . cmd . "  | win_getid=" . win_getid()
	silent! :w
	let l:bufnr=bufnr('%')
    " SilentEchoDebug "ApplyVimexec:1.1: executing command=" . cmd . "  | win_getid=" . win_getid() . " | bufnr=" . l:bufnr
    " call feedkeys(cmd . ':e')
    " SilentEchoDebug "ApplyVimexec:1.2: executing command=" . cmd . "  | win_getid=" . win_getid() . " | bufnr=" . l:bufnr
    " call feedkeys(cmd . '', 't')
	exec "normal! " . cmd . ''
	" execute printf('normal %s', cmd)
  endfor

	
  let &paste = l:paste_option

  " call winrestview(l:view)
endfunction

function! s:CleanUpHiddenCodeChangeBuffers(target_bufnr) abort
  " Get target buffer's file path
  let l:target_path = expand('#' . a:target_bufnr . ':p')

  " Get only hidden buffers
  let l:buffer_list = filter(getbufinfo(), 'v:val.hidden')
  
  " Iterate through hidden buffers only
  for buf in l:buffer_list
    " Check if buffer is not a real file, is our diff buffer, and matches target path
    if empty(buf.name) 
          \ && getbufvar(buf.bufnr, 'code_change_diff', 0)
          \ && getbufvar(buf.bufnr, 'code_change_orig_path', '') ==# l:target_path

      " Check if buffer can be safely deleted
      if !getbufvar(buf.bufnr, '&modified')
        SilentEchoDebug "CleanUpHiddenCodeChangeBuffers: deleting hidden buffer bufnr=" . buf.bufnr
        execute 'bdelete ' . buf.bufnr
      else
        SilentEchoDebug "CleanUpHiddenCodeChangeBuffers: skipping modified buffer bufnr=" . buf.bufnr
      endif
    endif
  endfor
endfunction

function! s:EnsureBufferFocus(bufnr) abort
  let l:bufwinid = bufwinid(a:bufnr)
  if l:bufwinid == -1
    rightbelow vnew
    exec printf('buffer%d', a:bufnr)
    let l:bufwinid = bufwinid(a:bufnr)
  endif
  call win_gotoid(l:bufwinid)
  return l:bufwinid
endfunction


function! s:EnsureWindowFocus(winid) abort
  if win_id2win(a:winid) == 0
    throw "window to be focused not in the current tabpage"
  endif
  call win_gotoid(a:winid)
  return a:winid
endfunction

function! s:ApplyCodeChangesDiff(bufnr, changes) abort
  let l:original_winid = win_getid()
  let l:target_winid = -1
  let l:diff_winid = -1
  let l:failed_edits = []
  let l:error_msg = ''
  let l:success = 0

  try
    SilentEchoDebug "ApplyCodeChangesDiff:1: start with bufnr=" . a:bufnr . " changes=" . len(a:changes) . " orig_win=" . l:original_winid
    call s:CleanUpHiddenCodeChangeBuffers(a:bufnr)

    let l:target_winid = s:EnsureBufferFocus(a:bufnr)

    rightbelow vnew
    setlocal buftype=nofile
    let l:diff_winid = win_getid()
    
    let b:code_change_diff = 1
    let b:code_change_orig_path = expand('#' . a:bufnr . ':p')
    
    let &filetype = getbufvar(a:bufnr, '&filetype')
    SilentEchoDebug "ApplyCodeChangesDiff:4: new diff buffer created, filetype=" . &filetype . " orig_path=" . b:code_change_orig_path

    call setline(1, getbufline(a:bufnr, 1, '$'))

    SilentEchoDebug "ApplyCodeChangesDiff:5: applying changes count=" . len(a:changes) . " failed_count=" . len(l:failed_edits)
    for change in a:changes
      try
        SilentEchoDebug "ApplyCodeChangesDiff:6: processing change type=" . change.type . " target_winid=" . l:target_winid . " failed_count=" . len(l:failed_edits)
        " Ensure we're in the diff window before applying changes
        call s:EnsureWindowFocus(l:diff_winid)
        
        SilentEchoDebug printf('ApplyCodeChangesDiff:5:0: cur=%d,diff=%d', win_getid(), l:diff_winid)
        if change.type == 'content'
          SilentEchoDebug "ApplyCodeChangesDiff:6-content: applying content change normal_command=" . (change.normal_command)
          call s:ApplyChange(change.normal_command, change.content)
          SilentEchoDebug "ApplyCodeChangesDiff:6-content: applied content change"
        elseif change.type == 'vimexec'
          call s:ApplyVimexec(change.commands)
        endif
        SilentEchoDebug "ApplyCodeChangesDiff:8: change applied successfully type=" . change.type
      catch
        call add(l:failed_edits, change)
        let l:error_msg = "Failed to apply edit in buffer " . bufname(a:bufnr) . ": " . v:exception
        SilentEchoDebug "ApplyCodeChangesDiff:9: error occurred msg=" . l:error_msg . " failed_count=" . len(l:failed_edits)
        echohl WarningMsg
        echomsg l:error_msg
        echohl None
      endtry
    endfor

    SilentEchoDebug "ApplyCodeChangesDiff:10: applying diff mode target_winid=" . l:target_winid . " failed_total=" . len(l:failed_edits)
    diffthis
    call s:EnsureWindowFocus(l:target_winid)
    diffthis

    if !empty(l:failed_edits)
      let l:error_msg = "Some edits could not be applied. Check the messages for details."
      SilentEchoDebug "ApplyCodeChangesDiff:11: failed edits summary msg=" . l:error_msg . " count=" . len(l:failed_edits)
      echohl WarningMsg
      echomsg l:error_msg
      echohl None
    endif
    
    let l:success = 1
    SilentEchoDebug "ApplyCodeChangesDiff:12: completed success=" . l:success . " target_winid=" . l:target_winid . " failed_count=" . len(l:failed_edits)

  finally
    SilentEchoDebug "ApplyCodeChangesDiff:13: cleanup orig_win=" . l:original_winid . " success=" . l:success . " error=" . l:error_msg
    call s:EnsureWindowFocus(l:original_winid)
    
    if !l:success
      throw !empty(l:error_msg) ? l:error_msg : "Failed to apply code changes diff"
    endif
  endtry
endfunction



" ============================================================================
" Tool Integration
" ============================================================================

if !exists('g:claude_tools')
  let g:claude_tools = [
    \ {
    \   'name': 'python',
    \   'description': 'Execute a Python one-liner code snippet and return the standard output. NEVER just print a constant or use Python to load the file whose buffer you already see. Use the tool only in cases where a Python program will generate a reliable, precise response than you cannot realistically produce on your own.',
    \   'input_schema': {
    \     'type': 'object',
    \     'properties': {
    \       'code': {
    \         'type': 'string',
    \         'description': 'The Python one-liner code to execute. Wrap the final expression in `print` to see its result - otherwise, output will be empty.'
    \       }
    \     },
    \     'required': ['code']
    \   }
    \ },
    \ {
    \   'name': 'shell',
    \   'description': 'Execute a shell command and return both stdout and stderr. Use with caution as it can potentially run harmful commands.',
    \   'input_schema': {
    \     'type': 'object',
    \     'properties': {
    \       'command': {
    \         'type': 'string',
    \         'description': 'The shell command or a short one-line script to execute.'
    \       }
    \     },
    \     'required': ['command']
    \   }
    \ },
    \ {
    \   "name": "open",
    \   "description": "Open an existing buffer (file, directory or netrw URL) so that you get access to its content. Returns the buffer name, or 'ERROR' for non-existent paths.",
    \   "input_schema": {
    \     "type": "object",
    \     "properties": {
    \       "path": {
    \         "type": "string",
    \         "description": "The path to open, passed as an argument to the vim :edit command"
    \       }
    \     },
    \     "required": ["path"]
    \   }
    \ },
    \ {
    \   "name": "new",
    \   "description": "Create a new file, opening a buffer for it so that edits can be applied. Returns an error if the file already exists.",
    \   "input_schema": {
    \     "type": "object",
    \     "properties": {
    \       "path": {
    \         "type": "string",
    \         "description": "The path of the new file to create, passed as an argument to the vim :new command"
    \       }
    \     },
    \     "required": ["path"]
    \   }
    \ },
    \ {
    \   'name': 'open_web',
    \   'description': 'Open a new buffer with the text content of a specific webpage. Use this for accessing documentation or other search results.',
    \   'input_schema': {
    \     'type': 'object',
    \     'properties': {
    \       'url': {
    \         'type': 'string',
    \         'description': 'The URL of the webpage to read'
    \       },
    \     },
    \     'required': ['url']
    \   }
    \ },
    \ {
    \   'name': 'web_search',
    \   'description': 'Perform a web search and return the top 5 results. Use this to find information beyond your knowledge on the web (e.g. about specific APIs, new tools or to troubleshoot errors). Strongly consider using open_web next to open one or several result URLs to learn more.',
    \   'input_schema': {
    \     'type': 'object',
    \     'properties': {
    \       'query': {
    \         'type': 'string',
    \         'description': 'The search query (bunch of keywords / keyphrases)'
    \       },
    \     },
    \     'required': ['query']
    \   }
    \ }
    \ ]
endif

function! s:ExecuteTool(tool_name, arguments)
  if a:tool_name == 'python'
    return s:ExecutePythonCode(a:arguments.code)
  elseif a:tool_name == 'shell'
    return s:ExecuteShellCommand(a:arguments.command)
  elseif a:tool_name == 'open'
    return s:ExecuteOpenTool(a:arguments.path)
  elseif a:tool_name == 'new'
    return s:ExecuteNewTool(a:arguments.path)
  elseif a:tool_name == 'open_web'
    return s:ExecuteOpenWebTool(a:arguments.url)
  elseif a:tool_name == 'web_search'
    let l:escaped_query = py3eval("''.join([c if c.isalnum() or c in '-._~' else '%{:02X}'.format(ord(c)) for c in vim.eval('a:arguments.query')])")
    return s:ExecuteOpenWebTool("https://www.google.com/search?q=" . l:escaped_query)
  else
    return 'Error: Unknown tool ' . a:tool_name
  endif
endfunction

function! s:ExecutePythonCode(code)
  redraw
  let l:confirm = input("Execute this Python code? (y/n/C-C; if you C-C to stop now, you can C-] later to resume) ")
  if l:confirm =~? '^y'
    let l:result = system('python3 -c ' . shellescape(a:code))
    return l:result
  else
    return "Python code execution cancelled by user."
  endif
endfunction

function! s:ExecuteShellCommand(command)
  redraw
  let l:confirm = input("Execute this shell command? (y/n/C-C; if you C-C to stop now, you can C-] later to resume) ")
  if l:confirm =~? '^y'
    let l:output = system(a:command)
    let l:exit_status = v:shell_error
    return l:output . "\nExit status: " . l:exit_status
  else
    return "Shell command execution cancelled by user."
  endif
endfunction

function! s:ExecuteOpenTool(path)
  let l:current_winid = win_getid()

  topleft 1new

  try
    execute 'edit ' . fnameescape(a:path)
    let l:bufname = bufname('%')

    if line('$') == 1 && getline(1) == ''
      close
      call win_gotoid(l:current_winid)
      return 'ERROR: The opened buffer was empty (non-existent?)'
    else
      call win_gotoid(l:current_winid)
      return l:bufname
    endif
  catch
    close
    call win_gotoid(l:current_winid)
    return 'ERROR: ' . v:exception
  endtry
endfunction

function! s:ExecuteNewTool(path)
  if filereadable(a:path)
    return 'ERROR: File already exists: ' . a:path
  endif
  if bufexists(a:path)
    " write that buffer to the file and return an error so that the AI knows
    " that there is actually a file to be interacted with; TODO: should find a
    " way to not invoke the new tool in the first place if that's the case.
    let l:current_winid = win_getid()
    let bufnr = bufnr(a:path)
    if bufnr == -1
      topleft 1new
      exec printf(':b%s', string(bufnr))
      exec 'silent write ' . fnameescape(a:path)
      exec :q
    endif
    return 'ERROR: Buffer already exists: ' . a:path . '; I have written the buffer to the file now.'
  endif

  let l:current_winid = win_getid()

  topleft 1new
  execute 'silent write ' . fnameescape(a:path)
  let l:bufname = bufname('%')

  call win_gotoid(l:current_winid)
  return l:bufname
endfunction

function! s:ExecuteOpenWebTool(url)
  let l:current_winid = win_getid()

  topleft 1new
  setlocal buftype=nofile
  setlocal bufhidden=hide
  setlocal noswapfile

  execute ':r !elinks -dump ' . escape(shellescape(a:url), '%#!')
  if v:shell_error
    close
    call win_gotoid(l:current_winid)
    return 'ERROR: Failed to fetch content from ' . a:url . ': ' . v:shell_error
  endif

  let l:bufname = fnameescape(a:url)
  execute 'file ' . l:bufname

  call win_gotoid(l:current_winid)
  return l:bufname
endfunction


" ============================================================================
" ClaudeImplement
" ============================================================================

function! s:LogImplementInChat(instruction, implement_response, bufname, start_line, end_line)
  let [l:chat_bufnr, l:chat_winid, l:current_winid] = s:GetOrCreateChatWindow()

  let start_line_text = getline(a:start_line)
  let end_line_text = getline(a:end_line)

  if l:chat_winid != -1
    call win_gotoid(l:chat_winid)
    let l:indent = s:GetClaudeIndent()

    " Remove trailing "You:" line if it exists
    let l:last_line = line('$')
    if getline(l:last_line) =~ '^You:\s*$'
      execute l:last_line . 'delete _'
    endif

    call append('$', 'You: Implement in ' . a:bufname . ' (lines ' . a:start_line . '-' . a:end_line . '): ' . a:instruction)
    call append('$', l:indent . start_line_text)
    if a:end_line - a:start_line > 1
      call append('$', l:indent . "...")
    endif
    if a:end_line - a:start_line > 0
      call append('$', l:indent . end_line_text)
    endif
    call s:AppendResponse(a:implement_response)
    call s:ClosePreviousFold()
    call s:CloseCurrentInteractionCodeBlocks()
    call s:PrepareNextInput()

    call win_gotoid(l:current_winid)
  endif
endfunction

" Function to implement code based on instructions
function! s:ClaudeImplement(line1, line2, instruction) range
  " Get the selected code
  let l:selected_code = join(getline(a:line1, a:line2), "\n")
  let l:bufnr = bufnr('%')
  let l:bufname = bufname('%')
  let l:winid = win_getid()

  " Prepare the prompt for code implementation
  let l:prompt = "<code>\n" . l:selected_code . "\n</code>\n\n"
  let l:prompt .= join(g:claude_implement_prompt, "\n")

  " Query Claude
  let l:messages = [{'role': 'user', 'content': a:instruction}]
  call s:ClaudeQueryInternal(l:messages, l:prompt, [],
        \ function('s:StreamingImplementResponse'),
        \ function('s:FinalImplementResponse', [a:line1, a:line2, l:bufnr, l:bufname, l:winid, a:instruction]))
endfunction

function! s:ExtractCodeFromMarkdown(markdown)
  let l:lines = split(a:markdown, "\n")
  let l:in_code_block = 0
  let l:code = []
  for l:line in l:lines
    if l:line =~ '^```'
      let l:in_code_block = !l:in_code_block
    elseif l:in_code_block
      call add(l:code, l:line)
    endif
  endfor
  return join(l:code, "\n")
endfunction

function! s:StreamingImplementResponse(delta)
  if !exists("s:implement_response")
    let s:implement_response = ""
  endif

  let s:implement_response .= a:delta
endfunction

function! s:FinalImplementResponse(line1, line2, bufnr, bufname, winid, instruction)
  call win_gotoid(a:winid)

  call s:LogImplementInChat(a:instruction, s:implement_response, a:bufname, a:line1, a:line2)

  let l:implemented_code = s:ExtractCodeFromMarkdown(s:implement_response)

  let l:changes = [{
    \ 'type': 'content',
    \ 'normal_command': a:line1 . 'GV' . a:line2 . 'Gc',
    \ 'content': l:implemented_code
    \ }]
  call s:ApplyCodeChangesDiff(a:bufnr, l:changes)

  echomsg "Apply diff, see :help diffget. Close diff buffer with :q."

  unlet s:implement_response
  unlet! s:current_chat_job
endfunction



" ============================================================================
" ClaudeChat
" ============================================================================


" ----- Chat service functions

function! s:GetOrCreateChatWindow()
  let l:current_winid = win_getid()
  let l:chat_bufnr = bufnr('Claude Chat')
  if l:chat_bufnr != -1 && bufloaded(l:chat_bufnr) && bufwinnr(l:chat_bufnr) == -1
    " Open the buffer in a new window
    exec printf('topleft sbuffer %d', l:chat_bufnr)
    wincmd t
    let l:chat_bufnr = bufnr()
  elseif l:chat_bufnr == -1 || !bufloaded(l:chat_bufnr)
    call s:OpenClaudeChat()
    let l:chat_bufnr = bufnr('Claude Chat')
  endif

  let l:chat_winid = bufwinid(l:chat_bufnr)

  return [l:chat_bufnr, l:chat_winid, l:current_winid]
endfunction

function! s:GetClaudeIndent()
  if &expandtab
    return repeat(' ', &shiftwidth)
  else
    return repeat("\t", (&shiftwidth + &tabstop - 1) / &tabstop)
  endif
endfunction

function! s:AppendResponse(response)
  let l:response_lines = split(a:response, "\n")
  if len(l:response_lines) == 1
    call append('$', 'Claude: ' . l:response_lines[0])
  else
    call append('$', 'Claude:')
    let l:indent = s:GetClaudeIndent()
    call append('$', map(l:response_lines, {_, v -> v =~ '^\s*$' ? '' : l:indent . v}))
  endif
endfunction


" ----- Chat window UX

function! GetChatFold(lnum)
  let l:line = getline(a:lnum)
  let l:prev_level = foldlevel(a:lnum - 1)

  if l:line =~ '^You:' || l:line =~ '^System prompt:'
    return '>1'  " Start a new fold at level 1
  elseif l:line =~ '^\s' || l:line =~ '^$' || l:line =~ '^.*:'
    if l:line =~ '^\s*```'
      if l:prev_level == 1
        return '>2'  " Start a new fold at level 2 for code blocks
      else
        return '<2'  " End the fold for code blocks
      endif
    else
      return '='   " Use the fold level of the previous line
    fi
  else
    return '0'  " Terminate the fold
  endif
endfunction

function! s:SetupClaudeChatSyntax()
  if exists("b:current_syntax")
    return
  endif

  syntax include @markdown syntax/markdown.vim

  syntax region claudeChatSystem start=/^System prompt:/ end=/^\S/me=s-1 contains=claudeChatSystemKeyword
  syntax match claudeChatSystemKeyword /^System prompt:/ contained
  syntax match claudeChatYou /^You:/
  syntax match claudeChatClaude /^Claude\.*:/
  syntax match claudeChatToolUse /^Tool use.*:/
  syntax match claudeChatToolResult /^Tool result.*:/
  syntax region claudeChatClaudeContent start=/^Claude.*:/ end=/^\S/me=s-1 contains=claudeChatClaude,@markdown,claudeChatCodeBlock
  syntax region claudeChatToolBlock start=/^Tool.*:/ end=/^\S/me=s-1 contains=claudeChatToolUse,claudeChatToolResult
  syntax region claudeChatCodeBlock start=/^\s*```/ end=/^\s*```/ contains=@NoSpell

  " Don't make everything a code block; FIXME this works satisfactorily
  " only for inline markdown pieces
  syntax clear markdownCodeBlock

  highlight default link claudeChatSystem Comment
  highlight default link claudeChatSystemKeyword Keyword
  highlight default link claudeChatYou Keyword
  highlight default link claudeChatClaude Keyword
  highlight default link claudeChatToolUse Keyword
  highlight default link claudeChatToolResult Keyword
  highlight default link claudeChatToolBlock Comment
  highlight default link claudeChatCodeBlock Comment

  let b:current_syntax = "claudechat"
endfunction

function! s:GoToLastYouLine()
  normal! G$
endfunction

function! s:OpenClaudeChat()
  let l:claude_bufnr = bufnr('Claude Chat')

  " if the buffer exists and is loaded, but it is not in a window, open it in
  " a new window (at the top of the screen)
  if l:claude_bufnr != -1 && bufloaded(l:claude_bufnr) && bufwinnr(l:claude_bufnr) == -1
    " Open the buffer in a new window
    exec printf('topleft sbuffer %d', l:claude_bufnr)
  elseif l:claude_bufnr == -1 || !bufloaded(l:claude_bufnr)
    execute 'botright new Claude Chat'
    setlocal buftype=nofile
    setlocal bufhidden=hide
    setlocal noswapfile
    setlocal linebreak

    setlocal foldmethod=expr
    setlocal foldexpr=GetChatFold(v:lnum)
    setlocal foldlevel=1

    setlocal filetype=markdown

    call s:SetupClaudeChatSyntax()

    call setline(1, ['System prompt: ' . s:ClaudeGetSystemPrompt()[0]])
    call append('$', map(s:ClaudeGetSystemPrompt()[1:], {_, v -> "\t" . v}))
    call append('$', ['Type your messages below, press C-] to send.  (Content of all buffers is shared alongside!)', '', 'You: '])

    " Fold the system prompt
    normal! 1Gzc

    augroup ClaudeChat
      autocmd!
      autocmd BufWinEnter <buffer> call s:GoToLastYouLine()
    augroup END

    " Add mappings for this buffer
    command! -buffer -nargs=1 SendChatMessage call s:SendChatMessage(<q-args>)
    execute "inoremap <buffer> " . g:claude_map_send_chat_message . " <Esc>:call <SID>SendChatMessage('Claude:')<CR>"
    execute "nnoremap <buffer> " . g:claude_map_send_chat_message . " :call <SID>SendChatMessage('Claude:')<CR>"
  else
    let l:claude_winid = bufwinid(l:claude_bufnr)
    if l:claude_winid == -1
      execute 'botright split'
      execute 'buffer' l:claude_bufnr
    else
      call win_gotoid(l:claude_winid)
    endif
  endif
  call s:GoToLastYouLine()
endfunction


" ----- Chat parser (to messages list)

function! s:AddMessageToList(messages, message)
  " FIXME: Handle multiple tool_use, tool_result blocks at once
  if !empty(a:message.role)
    let l:message = {'role': a:message.role, 'content': join(a:message.content, "\n")}
    if !empty(a:message.tool_use)
      let l:message['content'] = [{'type': 'text', 'text': l:message.content}, a:message.tool_use]
    endif
    if !empty(a:message.tool_result)
      let l:message['content'] = [a:message.tool_result]
    endif
    call add(a:messages, l:message)
  endif
endfunction

function! s:InitMessage(role, line)
  return {
    \ 'role': a:role,
    \ 'content': [substitute(a:line, '^\S*\s*', '', '')],
    \ 'tool_use': {},
    \ 'tool_result': {}
  \ }
endfunction

function! s:ParseToolUse(line)
  let l:match = matchlist(a:line, '^Tool use (\(.*\)): \(.*\)$')
  if empty(l:match)
    return {}
  endif

  return {
    \ 'type': 'tool_use',
    \ 'id': l:match[1],
    \ 'name': l:match[2],
    \ 'input': {}
  \ }
endfunction

function! s:InitToolResult(line)
  let l:match = matchlist(a:line, '^Tool result (\(.*\)):')
  return {
    \ 'role': 'user',
    \ 'content': [],
    \ 'tool_use': {},
    \ 'tool_result': {
      \ 'type': 'tool_result',
      \ 'tool_use_id': l:match[1],
      \ 'content': ''
    \ }
  \ }
endfunction

function! s:AppendContent(message, line)
  let l:indent = s:GetClaudeIndent()
  if !empty(a:message.tool_use)
    if a:line =~ '^\s*Input:'
      let a:message.tool_use.input = json_decode(substitute(a:line, '^\s*Input:\s*', '', ''))
    elseif a:message.tool_use.name == 'python'
      if !has_key(a:message.tool_use.input, 'code')
        let a:message.tool_use.input.code = ''
      endif
      let a:message.tool_use.input.code .= (empty(a:message.tool_use.input.code) ? '' : "\n") . substitute(a:line, '^' . l:indent, '', '')
    endif
  elseif !empty(a:message.tool_result)
    let a:message.tool_result.content .= (empty(a:message.tool_result.content) ? '' : "\n") . substitute(a:line, '^' . l:indent, '', '')
  else
    call add(a:message.content, substitute(substitute(a:line, '^' . l:indent, '', ''), '\s*\[APPLIED\]$', '', ''))
  endif
endfunction

function! s:ProcessLine(line, messages, current_message)
  let l:new_message = copy(a:current_message)

  if a:line =~ '^You:'
    call s:AddMessageToList(a:messages, l:new_message)
    let l:new_message = s:InitMessage('user', a:line)
  elseif a:line =~ '^Claude'  " both Claude: and Claude...:
    call s:AddMessageToList(a:messages, l:new_message)
    let l:new_message = s:InitMessage('assistant', a:line)
  elseif a:line =~ '^Tool use ('
    let l:new_message.tool_use = s:ParseToolUse(a:line)
  elseif a:line =~ '^Tool result ('
    call s:AddMessageToList(a:messages, l:new_message)
    let l:new_message = s:InitToolResult(a:line)
  elseif !empty(l:new_message.role)
    call s:AppendContent(l:new_message, a:line)
  endif

  return l:new_message
endfunction

function! s:ParseChatBuffer()
  let l:buffer_content = getline(1, '$')
  let l:messages = []
  let l:current_message = {'role': '', 'content': [], 'tool_use': {}, 'tool_result': {}}
  let l:system_prompt = []
  let l:in_system_prompt = 0

  for line in l:buffer_content
    if line =~ '^System prompt:'
      let l:in_system_prompt = 1
      let l:system_prompt = [substitute(line, '^System prompt:\s*', '', '')]
    elseif l:in_system_prompt && line =~ '^\s'
      call add(l:system_prompt, substitute(line, '^\s*', '', ''))
    else
      let l:in_system_prompt = 0
      let l:current_message = s:ProcessLine(line, l:messages, l:current_message)
    endif
  endfor

  if !empty(l:current_message.role)
    call s:AddMessageToList(l:messages, l:current_message)
  endif

  return [filter(l:messages, {_, v -> !empty(v.content)}), join(l:system_prompt, "\n")]
endfunction


" ----- Sending messages

function! s:GetBuffersContent()
  let l:buffers = []
  for bufnr in range(1, bufnr('$'))
    if buflisted(bufnr) && bufname(bufnr) != 'Claude Chat' && !empty(win_findbuf(bufnr))
      let l:bufname = bufname(bufnr)
      let l:contents = join(getbufline(bufnr, 1, '$'), "\n")
      call add(l:buffers, {'name': l:bufname, 'contents': l:contents})
    endif
  endfor
  return l:buffers
endfunction

function! s:SendChatMessage(prefix)
  SilentEchoMessage "================= SendChatMessage:1: start with prefix=" . a:prefix . "; truncated_msg=" . strpart(getline('.'), 0, 300)

  let [l:messages, l:system_prompt] = s:ParseChatBuffer()
  let current_message_content = l:messages[-1].content
  call s:AddToMessageHistory(current_message_content)

  let l:tool_uses = s:ResponseExtractToolUses(l:messages)
  if !empty(l:tool_uses)
    for l:tool_use in l:tool_uses
      let l:tool_result = s:ExecuteTool(l:tool_use.name, l:tool_use.input)
      call s:AppendToolResult(l:tool_use.id, l:tool_result)
    endfor
    let [l:messages, l:system_prompt] = s:ParseChatBuffer()
  endif

  let l:buffer_contents = s:GetBuffersContent()
  let l:content_prompt = "# Contents of open buffers\n\n"
  for buffer in l:buffer_contents
    let l:content_prompt .= "Buffer: " . buffer.name . "\n"
    let l:content_prompt .= "<content>\n" . buffer.contents . "</content>\n\n"
    let l:content_prompt .= "============================\n\n"
  endfor

  call append('$', a:prefix . " ")
  normal! G

  let l:job = s:ClaudeQueryInternal(l:messages, l:content_prompt . l:system_prompt, g:claude_tools, function('s:StreamingChatResponse'), function('s:FinalChatResponse'))

  " Store the job ID or channel for potential cancellation
  if has('nvim')
    let s:current_chat_job = l:job
  else
    let s:current_chat_job = job_getchannel(l:job)
  endif
endfunction

" Command to send message in normal mode
command! ClaudeSend call <SID>SendChatMessage('Claude:')


" ----- Handling responses: Tool use

function! s:ResponseExtractToolUses(messages)
  if len(a:messages) == 0
    return []
  elseif type(a:messages[-1].content) == v:t_list
    return filter(copy(a:messages[-1].content), 'v:val.type == "tool_use"')
  else
    return []
  endif
endfunction

function! s:AppendToolUse(tool_call_id, tool_name, tool_input)
  let l:indent = s:GetClaudeIndent()
  call append('$', 'Tool use (' . a:tool_call_id . '): ' . a:tool_name)
  if a:tool_name == 'python'
    for line in split(a:tool_input.code, "\n")
      call append('$', l:indent . line)
    endfor
  else
    call append('$', l:indent . 'Input: ' . json_encode(a:tool_input))
  endif
  normal! G
endfunction

function! s:AppendToolResult(tool_call_id, result)
  let l:indent = s:GetClaudeIndent()
  call append('$', 'Tool result (' . a:tool_call_id . '):')
  call append('$', map(split(a:result, "\n"), {_, v -> l:indent . v}))
  normal! G
endfunction


" ----- Handling responses: Code changes

function! s:ProcessCodeBlock(block, all_changes)
  SilentEchoDebug '1 - Starting ProcessCodeBlock'
  let l:matches = matchlist(a:block.header, '^\(\S\+\)\s\+\([^:]\+\)\%(:\(.*\)\)\?$')
  let l:filetype = get(l:matches, 1, '')
  let l:buffername = get(l:matches, 2, '')
  let l:normal_command = get(l:matches, 3, '')

  SilentEchoDebug '2 - Parsed header: ft=' . l:filetype . ' buf=' . l:buffername

  if empty(l:buffername)
    echom "Warning: No buffer name specified in code block header"
    SilentEchoDebug '3 - Empty buffer name, returning'
    return
  endif

  let l:target_bufnr = bufnr(l:buffername)
  SilentEchoDebug '4 - Target buffer number: ' . l:target_bufnr

  if l:target_bufnr == -1
    echom "Warning: Buffer not found for " . l:buffername
    SilentEchoDebug '5 - Invalid buffer number, returning'
    return
  endif

  if !has_key(a:all_changes, l:target_bufnr)
    SilentEchoDebug '6 - Creating new changes array for buffer'
    let a:all_changes[l:target_bufnr] = []
  endif

  if l:filetype ==# 'vimexec'
    SilentEchoDebug '7 - Adding vimexec change'
    call add(a:all_changes[l:target_bufnr], {
          \ 'type': 'vimexec',
          \ 'commands': a:block.code
          \ })
  else
    if empty(l:normal_command)
      SilentEchoDebug '8 - No normal command, using default'
      let l:normal_command = 'Go<CR>'
    endif

    SilentEchoDebug '9 - Adding content change with normal command: ' . l:normal_command
    call add(a:all_changes[l:target_bufnr], {
          \ 'type': 'content',
          \ 'normal_command': l:normal_command,
          \ 'content': join(a:block.code, "\n")
          \ })
  endif

  let l:indent = s:GetClaudeIndent()
  call setline(a:block.start_line - 1, l:indent . '```' . a:block.header . ' [APPLIED]')
  SilentEchoDebug '10 - Process complete, marked as APPLIED'
endfunction
" At top of file

function! s:ResponseExtractChanges()
  SilentEchoDebug "ResponseExtractChanges:" . "1"  . ": Starting change extraction"
  
  let l:all_changes = {}

  " Find the start of the last Claude block
  normal! G
  let l:start_line = search('^Claude:', 'b')  " Skip over Claude...:
  SilentEchoDebug "ResponseExtractChanges:" . "2" . ": Found Claude block at line " . l:start_line
  
  let l:end_line = line('$')
  let l:markdown_delim = '^\s*```'

  let l:in_code_block = 0
  let l:current_block = {'header': '', 'code': [], 'start_line': 0}

  SilentEchoDebug "DDD: checking lines against " . l:markdown_delim
  for l:line_num in range(l:start_line, l:end_line)
    let l:line = getline(l:line_num)

    if l:line =~ l:markdown_delim
      if ! l:in_code_block
        " Start of code block
        let l:current_block = {'header': substitute(l:line, l:markdown_delim, '', ''), 'code': [], 'start_line': l:line_num + 1}
        SilentEchoDebug "ResponseExtractChanges:" . "3" . ": Starting code block at line " . l:line_num
        let l:in_code_block = 1
      else
        " End of code block
        let l:current_block.end_line = l:line_num
        SilentEchoDebug "ResponseExtractChanges:" . "4" . ": Ending code block at line " . l:line_num
        call s:ProcessCodeBlock(l:current_block, l:all_changes)
        let l:in_code_block = 0
      endif
    elseif l:in_code_block
      call add(l:current_block.code, substitute(l:line, '^' . s:GetClaudeIndent(), '', ''))
    endif
  endfor

  " Process any remaining open code block
  if l:in_code_block
    let l:current_block.end_line = l:end_line
    SilentEchoDebug "ResponseExtractChanges:" . "5" . ": Processing final block ending at " . l:end_line
    call s:ProcessCodeBlock(l:current_block, l:all_changes)
  endif

  SilentEchoDebug "ResponseExtractChanges:" . "6" . ": Completed with " . len(l:all_changes) . " changes"
  return l:all_changes
endfunction

function s:ApplyChanges(changes)
  let [l:chat_bufnr, l:chat_winid, l:current_winid] = s:GetOrCreateChatWindow()
  call win_gotoid(l:chat_winid)

  let l:all_changes = a:changes
  if !empty(l:all_changes)
    for [l:target_bufnr, l:changes] in items(l:all_changes)
      SilentEchoDebug "Applying changes to buffer " . l:target_bufnr . " (" . bufname(l:target_bufnr) . "); shortened_changes=" . string(l:changes)[0:100]." …"
      call s:ApplyCodeChangesDiff(str2nr(l:target_bufnr), l:changes)
    endfor
  endif
  normal! G

  call win_gotoid(l:current_winid)
endfunction

function s:ApplyChangesFromResponse()
  let l:all_changes = s:ResponseExtractChanges()
  call s:RecordChanges(l:all_changes)
  call s:ApplyChanges(l:all_changes)
endfunction


" ----- Handling responses

function! s:ClosePreviousFold()
  let l:save_cursor = getpos(".")

  normal! G[zk[zzc

  if foldclosed('.') == -1
    echom "Warning: Failed to close previous fold at line " . line('.')
  endif

  call setpos('.', l:save_cursor)
endfunction

function! s:CloseCurrentInteractionCodeBlocks()
  let l:save_cursor = getpos(".")

  " Move to the start of the current interaction
  normal! [z

  " Find and close all level 2 folds until the end of the interaction
  while 1
    if foldlevel('.') == 2
      normal! zc
    endif

    let current_line = line('.')
    normal! j
    if line('.') == current_line || foldlevel('.') < 1 || line('.') == line('$')
      break
    endif
  endwhile

  call setpos('.', l:save_cursor)
endfunction

function! s:PrepareNextInput()
  call append('$', '')
  call append('$', 'You: ')
  normal! G$
endfunction

function! s:StreamingChatResponse(delta)
  let [l:chat_bufnr, l:chat_winid, l:current_winid] = s:GetOrCreateChatWindow()

  " Update chat buffer from current window
  call setbufvar(l:chat_bufnr, '&modifiable', 1)
  
  let l:indent = s:GetClaudeIndent()
  let l:new_lines = split(a:delta, "\n", 1)

  if len(l:new_lines) > 0
    " Update the last line with the first segment of the delta
    let l:last_line = getbufline(l:chat_bufnr, '$')[0]
    call setbufline(l:chat_bufnr, '$', l:last_line . l:new_lines[0])

    if len(l:new_lines) > 1
      call appendbufline(l:chat_bufnr, '$', map(l:new_lines[1:], {_, v -> l:indent . v}))
    endif
  endif

endfunction

function! s:FinalChatResponse()
  let [l:chat_bufnr, l:chat_winid, l:current_winid] = s:GetOrCreateChatWindow()

  call win_gotoid(l:chat_winid)
  let [l:messages, l:system_prompt] = s:ParseChatBuffer()
  let l:tool_uses = s:ResponseExtractToolUses(l:messages)

  call s:ApplyChangesFromResponse()

  if !empty(l:tool_uses)
    call s:SendChatMessage('Claude...:')
  else
    call s:ClosePreviousFold()
    call s:CloseCurrentInteractionCodeBlocks()
    call s:PrepareNextInput()
    call win_gotoid(l:current_winid)
    unlet! s:current_chat_job
  endif
endfunction

function! s:CancelClaudeResponse()
  if exists("s:current_chat_job")
    if has('nvim')
      call jobstop(s:current_chat_job)
    else
      call ch_close(s:current_chat_job)
    endif
    unlet s:current_chat_job
    call s:AppendResponse("[Response cancelled by user]")
    call s:ClosePreviousFold()
    call s:CloseCurrentInteractionCodeBlocks()
    call s:PrepareNextInput()
    echo "Claude response cancelled."
  else
    echo "No ongoing Claude response to cancel."
  endif
endfunction
