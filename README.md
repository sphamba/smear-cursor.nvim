# Smear cursor for Neovim

_Neovim plugin to animate the cursor with a smear effect. Inspired by [Neovide's animated cursor](https://neovide.dev/features.html#animated-cursor)._

This plugin is intended for terminals/GUIs that can only display text and do not have graphical capabilities (unlike [Neovide](https://neovide.dev/), or the [Kitty](https://sw.kovidgoyal.net/kitty/) terminal). Also, check out the [karb94/neoscroll.nvim](https://github.com/karb94/neoscroll.nvim) plugin for smooth scrolling!


# Demo

[Demo](https://private-user-images.githubusercontent.com/17217484/389300116-fc95b4df-d791-4c53-9141-4f870eb03ab2.mp4?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3MzI0NzY0NDAsIm5iZiI6MTczMjQ3NjE0MCwicGF0aCI6Ii8xNzIxNzQ4NC8zODkzMDAxMTYtZmM5NWI0ZGYtZDc5MS00YzUzLTkxNDEtNGY4NzBlYjAzYWIyLm1wND9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNDExMjQlMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjQxMTI0VDE5MjIyMFomWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPTg1NjFhZjJlODQ4YmU2NjAzY2EzY2I3NWMzMzI5MWQ1Njk2MTExYmEwYmExNTMwMThmYTJjYjE2ZjIyOThjNjMmWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0In0.Skw2VVyVWVkMe4ht6mvl_AZ_6QasJm8O6qsIZmcQ2XE)


# Installation

## Using [lazy.nvim](https://lazy.folke.io/)

In `~/.config/nvim/lua/plugins/smear_cursor.lua`, add:
```lua
return {
  "sphamba/smear-cursor.nvim",
  opts = {},
}
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
return {
  "sphamba/smear-cursor.nvim",

  opts = {
    -- Cursor color. Defaults to Cursor gui color
    cursor_color = "#d3cdc3",

    -- Background color. Defaults to Normal gui background color
    normal_bg = "#282828",

    -- Smear cursor when switching buffers
    smear_between_buffers = true,

    -- Smear cursor when moving within line or to neighbor lines
    smear_between_neighbor_lines = true,

    -- Use floating windows to display smears outside buffers.
    -- May have performance issues with other plugins.
    use_floating_windows = true,

    -- Set to `true` if your font supports legacy computing symbols (block unicode symbols).
    -- Smears will blend better on all backgrounds.
    legacy_computing_symbols_support = false,
  },
}
```
Some terminals override the cursor color set by Neovim. If that is the case, manually change the cursor color as shown above.

Refer to `lua/smear_cursor/config.lua` for the full list of configuration options that can be set with `opts`. For example, you can tune the smear dynamics to be snappier:
```lua
  opts = {
    -- How fast the smear's head moves towards the target.
    -- 0: no movement, 1: instantaneous, default: 0.6
    stiffness = 0.8,

    -- How fast the smear's tail moves towards the head.
    -- 0: no movement, 1: instantaneous, default: 0.3
    trailing_stiffness = 0.6,

    -- How much the tail slows down when getting close to the head.
    -- 0: no slowdown, more: more slowdown, default: 0.1
    trailing_exponent = 0,

    -- Stop animating when the smear's tail is within this distance (in characters) from the target.
    -- Default: 0.1
    distance_stop_animating = 0.5,

    -- Attempt to hide the real cursor when smearing.
    -- Default: true
    hide_target_hack = false,
  },
```


## Using `init.vim`

You can set the configuration variables in your `init.vim` file like this:
```vim
lua require('smear_cursor').cursor_color = '#d3cdc3'
```


# Known issues

- There is a shadow around the smear (text become invisible). This is inherent to the way the smear is rendered, as Neovim is not able to render superimposed characters. The shadow is less noticeable when the smear is moving faster (see configuration options).
- Likely not compatible with other plugins that modify the cursor.
- When not using floating windows fallback:
  - No smear when buffer is duplicated
  - No smear outside buffer (further than the last line)
  - No smear through wrapped lines


# Development TODOs

## Features

- [ ] Smear when jumping to commands
- [ ] Help documentation

## Bugs

- [ ] Wrong background color over non-normal text
- [ ] Fold open and close not registering as a cursor movement
- [ ] Wrong smear placement when concealed characters are present
- [ ] Flickering of cursor at target location
- [ ] Occasional flickering over line numbers when using floating windows
- [ ] Smear freezes
  - [ ] when opening command line
  - [ ] when input incomplete keybindings
