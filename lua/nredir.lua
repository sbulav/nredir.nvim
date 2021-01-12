local buf, win, start_win


local function close()
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end
end

local function zoom_toggle()
  local width = vim.api.nvim_get_option('columns')
    if vim.api.nvim_win_get_width(win) == width then
        -- change this to a lua call
        vim.api.nvim_win_set_width(win, math.ceil(width * 0.9))
    else
        vim.api.nvim_win_set_width(win, math.ceil(width * 0.5))
        -- vim.cmd("resize")
        -- vim.cmd("vertical resize")
    end
end

local function starts_with(str, start)
   return str:sub(1, #start) == start
end

local function redraw(cmd)

  local result = {}

  if cmd == nil or cmd == '' then
    table.insert(result, "Attempt to execute empty command!")
  elseif starts_with(cmd, "!") then
    -- System command
    result = vim.fn.systemlist(string.sub(cmd, 2))
  else
    -- Vim EX command
    vim.api.nvim_set_var('__redir_exec_cmd', cmd)
    vim.cmd([[
      redir => g:__redir_exec_output
        silent! execute g:__redir_exec_cmd
      redir END
    ]])

    local tmp = vim.api.nvim_get_var('__redir_exec_output')
    for s in tmp:gmatch("[^\r\n]+") do
        table.insert(result, s)
    end
  end

  vim.api.nvim_buf_set_option(buf, 'modifiable', true)

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, result)
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
end

local function set_mappings()
  local mappings = {
    q = 'close()',
    ['<cr>'] = 'zoom_toggle()',
  }

  for k,v in pairs(mappings) do
    vim.api.nvim_buf_set_keymap(buf, 'n', k, ':lua require"result".'..v..'<cr>', {
        nowait = true, noremap = true, silent = true
      })
  end
end

local function create_win()
  -- start_win = vim.api.nvim_get_current_win()

  vim.api.nvim_command('botright vnew')
  win = vim.api.nvim_get_current_win()
  buf = vim.api.nvim_get_current_buf()

  vim.api.nvim_buf_set_name(0, 'result #' .. buf)

  vim.api.nvim_buf_set_option(0, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(0, 'swapfile', false)
  vim.api.nvim_buf_set_option(0, 'filetype', 'result')
  vim.api.nvim_buf_set_option(0, 'bufhidden', 'wipe')

  vim.api.nvim_command('setlocal nowrap')
  vim.api.nvim_command('setlocal cursorline')

  set_mappings()
end

local function nredir(cmd)
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_set_current_win(win)
  else
    create_win()
  end

  redraw(cmd)
end

return {
  nredir = nredir,
  close = close,
  zoom_toggle = zoom_toggle,
}
