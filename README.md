nredir.nvim
=========

A [nredir](https://github.com/sbulav/nredir.nvim) Redirect the output of a Vim
or external command into a scratch buffer, in LUA.
It's basically an implementation of [Romainl's
Redir](https://gist.github.com/romainl/eae0a260ab9c135390c30cd370c20cd7),
written for learn purposes in Lua

## Installing

**NOTE: This plugin requires Neovim 0.5 versions**

```
Plug 'sbulav/nredir.lua'
```

## Usage

Show full output of command `:buffers` in scratch window:

```
:Nredir buffers
```

Show full output of command `!ls -la` in scratch window:

```
:Nredir !ls -la
```

- Pressing `q` will automatically close the window
- Pressing `enter` will maximize scratch window

You can also create a mapping to open command-line window and substitute
Nredir:

```viml
nnoremap <leader>R :Nredir <c-f>A
```

## Screenshot

[![nredir.nvim](TBD)](TBD)
