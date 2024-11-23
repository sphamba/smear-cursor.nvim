# Smear cursor for Neovim

_Neovim plugin to animate the cursor with a smear effect. Inspired by [Neovide's animated cursor](https://neovide.dev/features.html#animated-cursor)._


# Installation

## Using [lazy.nvim](https://lazy.folke.io/)

Add to your lazy.vim configuration:
```lua
  {
    "sphamba/smear-cursor.nvim",
  },
```


## Using [vim-plug](https://github.com/junegunn/vim-plug)

In your `init.vim`, add:

```vim
call plug#begin()
Plug 'sphamba/smear-cursor.nvim'
call plug#end()

lua require('smear_cursor').enabled = true
```


# Configuration

## Using [lazy.nvim](https://lazy.folke.io/)

Here are the default configuration options:
```lua
  {
    "sphamba/smear-cursor.nvim",

    opts = {
      -- Cursor color. Defaults to Normal foreground color
      cursor_color = '#d3cdc3', 

      -- Use floating windows to display smears outside buffers.
      -- May have performance issues with other plugins.
      use_floating_windows = true,

      -- Set to `true` if your font supports legacy computing symbols (block unicode symbols).
      -- Smears will blend better on all backgrounds.
      legacy_computing_symbols_support = false,

      -- Attempt to hide the real cursor when smearing.
      hide_target_hack = true,
    },
  },
```
Some terminals override the cursor color set by Neovim. If that is the case, manually set the cursor color as shown above. Refer to `lua/smear_cursor/config.lua` for the full list of configuration options.


## Using `init.vim`

You can set the configuration variables in your `init.vim` file like this:
```vim
lua require('smear_cursor').cursor_color = '#d3cdc3'
```


# Known issues

When not using floating windows fallback:
- No smear when buffer is duplicated
- No smear outside buffer (further than the last line)
- No smear through wrapped lines


# Development TODOs

## Features

- [ ] Smear when jumping to commands
- [ ] Help documentation

## Fixes

- [ ] Wrong background color over non-normal text
- [ ] Fold open and close not registering as a cursor movement
- [ ] Wrong smear placement in nerdtree (due to extmarks?)
- [ ] Flickering of cursor at target location
- [ ] Occasional flickering over line numbers when using floating windows
- [ ] Smear freezes
  - [ ] when opening command line
  - [ ] when inputing incomplete keybindings
