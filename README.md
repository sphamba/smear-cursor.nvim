# Smear cursor for Neovim

_Neovim plugin to animate the cursor with a smear effect. Inspired by [Neovide's animated cursor](https://neovide.dev/features.html#animated-cursor)._


# Demo

[Demo](https://private-user-images.githubusercontent.com/17217484/389234673-d0f17a00-af93-4081-a6be-9888698d8a22.mp4?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3MzI0MDU1OTAsIm5iZiI6MTczMjQwNTI5MCwicGF0aCI6Ii8xNzIxNzQ4NC8zODkyMzQ2NzMtZDBmMTdhMDAtYWY5My00MDgxLWE2YmUtOTg4ODY5OGQ4YTIyLm1wND9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNDExMjMlMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjQxMTIzVDIzNDEzMFomWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPTNhYjk0M2MxMTVmNWVmYmFjOGUzMWU1YTJkODdjMzdhNWIwNWY0YzI5MDlmNWQ1YmY1MTllODg4NTA4YzJlMGMmWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0In0.cUT045fhETUlOT3W60mTYcSm2R6e81V_UmYZEOzd81E)


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
    -- Cursor color. Defaults to Normal foreground color
    cursor_color = "#d3cdc3",

    -- Use floating windows to display smears outside buffers.
    -- May have performance issues with other plugins.
    use_floating_windows = true,

    -- Set to `true` if your font supports legacy computing symbols (block unicode symbols).
    -- Smears will blend better on all backgrounds.
    legacy_computing_symbols_support = false,

    -- Attempt to hide the real cursor when smearing.
    hide_target_hack = true,
  },
}
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
