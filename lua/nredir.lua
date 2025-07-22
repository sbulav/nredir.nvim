-- lua/nredir/init.lua
local M = {}
local buf, win

-- ANSI / OSC patterns (pre-compiled)
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

function M.close()
	if win and vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_win_close(win, true)
	end
	buf, win = nil, nil
end

function M.zoom_toggle()
	if not (win and vim.api.nvim_win_is_valid(win)) then
		return
	end
	local cols = vim.api.nvim_get_option_value("columns", {})
	local cur_w = vim.api.nvim_win_get_width(win)
	local max_w = math.ceil(cols * 0.9)
	local min_w = math.ceil(cols * 0.5)
	local new_w = (cur_w == max_w) and min_w or max_w
	vim.api.nvim_win_set_width(win, new_w)
end

local function create_win()
	buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(buf, "Nredir Output")
	for opt, val in pairs({
		buftype = "nofile",
		bufhidden = "wipe",
		swapfile = false,
		filetype = "Nredir",
	}) do
		vim.api.nvim_set_option_value(opt, val, { scope = "local", buf = buf })
	end

	vim.cmd("botright vsplit")
	win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(win, buf)
	for _, opt in ipairs({ "wrap", "cursorline" }) do
		vim.api.nvim_set_option_value(opt, true, { scope = "local", win = win })
	end

	vim.keymap.set("n", "q", M.close, { buffer = buf, silent = true })
	vim.keymap.set("n", "<CR>", M.zoom_toggle, { buffer = buf, silent = true })
	vim.keymap.set("n", "w", function()
		local w = vim.api.nvim_get_option_value("wrap", { scope = "local", win = win })
		vim.api.nvim_set_option_value("wrap", not w, { scope = "local", win = win })
	end, { buffer = buf, silent = true })
end

--- Asynchronously run `cmd` and dump its output on job exit.
--- If cmd starts with "!", it’s a shell command, otherwise a Vim Ex command.
function M.nredir(cmd)
	if not (win and vim.api.nvim_win_is_valid(win)) then
		create_win()
	else
		vim.api.nvim_set_current_win(win)
	end

	if not (cmd and #cmd > 0) then
		return update_buf({ "Error: empty command" })
	end

	-- Decide between shell vs Ex
	local is_shell = cmd:sub(1, 1) == "!"
	local to_run = is_shell and cmd:sub(2) or cmd

	-- Collect stdout+stderr
	local out, err = {}, {}

	-- Build a true shell invocation for complex commands
	local job_cmd
	if is_shell then
		local shell = vim.o.shell or "/bin/sh"
		job_cmd = { shell, "-c", to_run }
	else
		-- use Vim's :execute for Ex commands
		-- we’ll just call execute synchronously
		local lines = vim.fn.split(vim.fn.execute(to_run), "\n")
		return update_buf(vim.tbl_map(strip_ansi, lines))
	end

	vim.fn.jobstart(job_cmd, {
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
		on_exit = function()
			local lines = {}
			if #out > 0 then
				lines = out
			elseif #err > 0 then
				lines = err
			else
				lines = { "No output." }
			end
			-- strip ANSI and render once
			update_buf(vim.tbl_map(strip_ansi, lines))
		end,
	})
end

vim.api.nvim_create_user_command("Nredir", function(ctx)
	require("nredir").nredir(ctx.args)
end, {
	nargs = 1,
	complete = "command",
	desc = "Run shell or Ex command and redirect its output to a Nredir split",
})

return M
