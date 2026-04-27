-- lua/nredir/init.lua
local M = {}

-- user-configurable defaults
local defaults = {
  split_cmd = "botright vsplit",
  keymaps = {
    close = "q",
    zoom = "<CR>",
    wrap = "w",
  },
  spinner_interval = 120, -- ms between spinner frames
}

local opts = vim.tbl_deep_extend("force", {}, defaults)

-- module state
local buf, win, spinner_timer, job_id

-- spinner frames
local spinners = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

-- ANSI/OSC patterns
local ANSI_CSI = "\27%[[0-9;:]*[ -/]*[@-~]"
local OSC = "\27%][^%z\27]*[\7\27\\]"
local ANSI_RE = ANSI_CSI .. "|" .. OSC

local function strip_ansi(line)
  return line:gsub(ANSI_RE, "")
end

local function update_buf(lines)
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return
  end
  vim.api.nvim_set_option_value("modifiable", true, { scope = "local", buf = buf })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { scope = "local", buf = buf })
end

--- Close spinner, job, window
function M.close()
  if spinner_timer then
    spinner_timer:stop()
    spinner_timer:close()
    spinner_timer = nil
  end
  if job_id then
    vim.fn.jobstop(job_id)
    job_id = nil
  end
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end
  buf, win = nil, nil
end

--- Toggle width between 50% and 90%
function M.zoom_toggle()
  if not (win and vim.api.nvim_win_is_valid(win)) then
    return
  end
  local cols = vim.api.nvim_get_option_value("columns", {})
  local cur = vim.api.nvim_win_get_width(win)
  local maxw = math.ceil(cols * 0.9)
  local minw = math.ceil(cols * 0.5)
  vim.api.nvim_win_set_width(win, (cur == maxw) and minw or maxw)
end

--- Create the scratch window and set keymaps per opts
local function create_win()
  buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, "Nredir Output")

  -- buffer-local options
  for opt_name, val in pairs {
    buftype = "nofile",
    bufhidden = "wipe",
    swapfile = false,
    filetype = "Nredir",
  } do
    vim.api.nvim_set_option_value(opt_name, val, { scope = "local", buf = buf })
  end

  -- open split via user-configured cmd
  vim.cmd(opts.split_cmd)
  win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)

  -- window-local options
  for _, o in ipairs { "wrap", "cursorline" } do
    vim.api.nvim_set_option_value(o, true, { scope = "local", win = win })
  end

  -- automatically clean up if buffer is wiped
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buf,
    callback = M.close,
  })

  -- keymaps
  vim.keymap.set("n", opts.keymaps.close, M.close, { buffer = buf, silent = true })
  vim.keymap.set("n", opts.keymaps.zoom, M.zoom_toggle, { buffer = buf, silent = true })
  vim.keymap.set("n", opts.keymaps.wrap, function()
    local w = vim.api.nvim_get_option_value("wrap", { scope = "local", win = win })
    vim.api.nvim_set_option_value("wrap", not w, { scope = "local", win = win })
  end, { buffer = buf, silent = true })
end

--- Main entry: async shell or sync Ex + spinner
function M.nredir(cmd)
  -- tear down any previous run
  if spinner_timer then
    spinner_timer:stop()
    spinner_timer:close()
    spinner_timer = nil
  end
  if job_id then
    vim.fn.jobstop(job_id)
    job_id = nil
  end

  if not (cmd and #cmd > 0) then
    if not (win and vim.api.nvim_win_is_valid(win)) then
      create_win()
    else
      vim.api.nvim_set_current_win(win)
    end
    return update_buf { "Error: empty command" }
  end

  local source_win = vim.api.nvim_get_current_win()
  local is_shell = cmd:sub(1, 1) == "!"
  local to_run = is_shell and cmd:sub(2) or cmd

  -- Capture Ex output before switching windows so buffer/cursor-local
  -- commands run in the invocation context, not the scratch window.
  local captured_lines
  if not is_shell then
    local ok, result
    local function execute_ex()
      ok, result = pcall(vim.fn.execute, to_run)
    end

    if vim.api.nvim_win_is_valid(source_win) then
      vim.api.nvim_win_call(source_win, execute_ex)
    else
      execute_ex()
    end

    captured_lines = vim.tbl_map(strip_ansi, vim.fn.split(result, "\n"))
  end

  -- open or focus window
  if not (win and vim.api.nvim_win_is_valid(win)) then
    create_win()
  else
    vim.api.nvim_set_current_win(win)
  end

  -- write previously captured Ex output
  if not is_shell then
    return update_buf(captured_lines)
  end

  -- start spinner
  spinner_timer = vim.loop.new_timer()
  spinner_timer:start(
    0,
    opts.spinner_interval,
    vim.schedule_wrap(function()
      if buf and vim.api.nvim_buf_is_valid(buf) then
        local ms = vim.loop.hrtime() / 1e6
        local idx = math.floor(ms / opts.spinner_interval) % #spinners + 1
        update_buf { ("%s Awaiting for command output"):format(spinners[idx]) }
      end
    end)
  )

  -- launch shell job via /bin/sh -c so &&, fish quirks, etc. don’t bite us
  local job_cmd = { "/bin/sh", "-c", to_run }
  local out, err = {}, {}

  job_id = vim.fn.jobstart(job_cmd, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if data then
        vim.list_extend(out, data)
      end
    end,
    on_stderr = function(_, data)
      if data then
        vim.list_extend(err, data)
      end
    end,
    on_exit = function(_, code)
      -- stop spinner
      if spinner_timer then
        spinner_timer:stop()
        spinner_timer:close()
        spinner_timer = nil
      end

      -- if the buffer was closed, skip
      if not (buf and vim.api.nvim_buf_is_valid(buf)) then
        job_id = nil
        return
      end

      -- strip ANSI
      out = vim.tbl_map(strip_ansi, out)
      err = vim.tbl_map(strip_ansi, err)

      -- merge streams: stdout first, then stderr (so you see errors too)
      local all = {}
      if #out > 0 then
        vim.list_extend(all, out)
      end
      if #err > 0 then
        vim.list_extend(all, err)
      end

      -- if nothing at all, show exit code
      if #all == 0 then
        all = { "No output.", ("Exit code: %d"):format(code) }
      end

      update_buf(all)
      job_id = nil
    end,
  })
end

--- Setup with user overrides
---
--- @param user_opts table
---   split_cmd:string       – override split command
---   keymaps:table          – override close/zoom/wrap keys
---   spinner_interval:number– override ms between frames
function M.setup(user_opts)
  opts = vim.tbl_deep_extend("force", opts, user_opts or {})
end

-- define the :Nredir command
vim.api.nvim_create_user_command("Nredir", function(ctx)
  require("nredir").nredir(ctx.args)
end, {
  nargs = 1,
  complete = "command",
  desc = "Run shell or Ex command with spinner and redirect output",
})

return M
