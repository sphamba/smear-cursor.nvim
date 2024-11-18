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


# Development TODOs

## Features

- [ ] Color gradient smear
- [ ] Reduce size with speed
- [ ] Smear when jumping to commands
- [ ] Configurable animation parameters
- [ ] Lazy.nvim configuration
- [ ] Help documentation

## Fixes

- [ ] Smear outside buffer (further than the last line)
  - [ ] Transition to a buffer with less lines than the current cursor row
- [ ] Drawing smear through wrapped lines
- [ ] Wrong background color over non-normal text
- [ ] Smears appear on duplicated buffer
