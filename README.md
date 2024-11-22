# Smear cursor for Neovim

_Neovim plugin to animate the cursor with a smear effect. Inspired by [Neovide's animated cursor](https://neovide.dev/features.html#animated-cursor)._


# Installation

## Using [vim-plug](https://github.com/junegunn/vim-plug)

In your `init.vim`, add:

```vim
call plug#begin()
Plug 'sphamba/smear-cursor.nvim'
call plug#end()
```


# Configuration

In your `init.vim`, add:
```vim
lua require('smear_cursor.color').cursor_fg = '#d3cdc3' "Put the cursor color set by your terminal
```


# Known issues

When not using floating windows fallback:
- No smear when buffer is duplicated
- No smear outside buffer (further than the last line)
- No smear through wrapped lines


# Development TODOs

## Features

- [ ] Reduce size with speed
- [ ] Smear when jumping to commands
- [ ] Configurable animation parameters
- [ ] Lazy.nvim configuration
- [ ] Help documentation

## Fixes

- [ ] Wrong background color over non-normal text
- [ ] Fold open and close not registering as a cursor movement
- [ ] Regular cursor still visible and moves instantly
- [ ] Wrong smear placement in nerdtree (due to extmarks?)
- [ ] Flickering of cursor at target location
- [ ] Occasional flickering over line numbers when using floating windows
- [ ] Smear freezes
  - [ ] when opening command line
  - [ ] when inputing incomplete keybindings
