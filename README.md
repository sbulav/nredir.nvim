nredir.nvim
=========

> Redirect the output of a Vim Ex or external shell command into a scratch split, with an optional live spinner.
> Reworked for Neovim 0.10+.

[![GitHub tag](https://img.shields.io/github/v/tag/sbulav/nredir.nvim)](https://github.com/sbulav/nredir.nvim)

---

## Features

* 📺 Async execution of shell (`!…`) or Vim Ex commands
* 🔄 Live ASCII spinner in the scratch buffer while the job runs
* 🚪 Close (`q`), 🔍 toggle width (`Enter`), ↔ wrap toggle (`w`) out-of-the-box
* ⚙️ 100% Lua, configurable split command, keymaps, spinner speed
* 🔌 Works in pure Lua (no Vimscript shims)

---

## Requirements

* Neovim **0.10** or later

---

## Installation

### lazy.nvim

```lua
-- in your lazy spec:
require("lazy").setup({
  {
   "sbulav/nredir.nvim",
    cmd    = "Nredir",                  -- load on :Nredir
    config = function()
        -- call setup (you can omit the table if you want all defaults)
        require("nredir").setup {
        -- your overrides here
        }
    end,
  },
})
```

### packer.nvim

```lua
use {
  "sbulav/nredir.nvim",
  cmd    = "Nredir",
  config = function()
    require("nredir").setup {
      -- your overrides here
    }
  end,
}
```

---

## Configuring

Call `require("nredir").setup()` early in your config to override defaults:

```lua
require("nredir").setup {
  -- split command when opening scratch (any valid |:help :split| command)
  split_cmd        = "botright vsplit",

  -- buffer-local keymaps for the scratch window
  keymaps = {
    close = "q",    -- close window
    zoom  = "<CR>", -- toggle width 50%⇄90%
    wrap  = "w",    -- toggle line wrap
  },

  -- spinner frame interval in milliseconds
  spinner_interval = 120,
}
```

If you omit `setup{}`, the plugin defaults to the above values.

---

## Default Mappings (in the Nredir buffer)

| Key    | Action                                      |
| :----- | :------------------------------------------ |
| `q`    | Close the scratch window                    |
| `<CR>` | Toggle width between 50% and 90% of columns |
| `w`    | Toggle line wrapping                        |

---

## Usage

```vim
" Run a Vim Ex command:
:Nredir buffers

" Run a shell command:
:Nredir !ls -la

" Color output not supported:
:Nredir !tofu plan -no-color

" Run a complex shell pipeline:
:Nredir !sleep 5 && echo "done"
```

---

## Example Keybindings

### Vim-style mapping

Place this in your `init.vim`:

```vim
  autocmd FileType yaml nnoremap <buffer> <F5> <cmd>lua require('nredir').nredir("!kubectl apply -f " .. vim.fn.bufname() .. " --dry-run -o yaml")<cr>
  autocmd FileType helm nnoremap <buffer> <F5> :Nredir !helm template . <cr>
```

Now `F5` pops up an input and redirects its output to the scratch split.

---

### FileType-based mappings

If you’d rather use ft-mappings in lua, create:

```sh
~/.config/nvim/after/ftplugin/helm.lua
```

with:

```
-- after/ftplugin/helm.lua
vim.keymap.set("n", "<F6>", function()
  require("nredir").nredir("!helm template .")
end, { buffer = true, silent = true, nowait = true })
```

---

## Screenshots


---

## Credits

Built by [sbulav](https://github.com/sbulav), inspired by:

* [Romainl’s Redir gist][redir-gist]
* [telescope-github.nvim README][tgh-readme]

[redir-gist]: https://gist.github.com/romainl/eae0a260ab9c135390c30cd370c20cd7
[tgh-readme]: https://github.com/nvim-telescope/telescope-github.nvim#readme
