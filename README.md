# Smear cursor for Neovim

_Neovim plugin to animate the cursor with a smear effect. Inspired by [Neovide's animated cursor](https://neovide.dev/features.html#animated-cursor)._


# Development TODOs

## Features

- [ ] Color gradient smear
- [ ] Reduce size with speed
- [ ] Smear when jumping to commands
- [ ] Smear when jumping between windows
- [ ] Easily set cursor color

## Fixes

- [ ] Smear outside buffer (further than the last line)
  - [ ] Transition to a buffer with less lines than the current cursor row
- [ ] Drawing smear through folded lines
- [ ] Drawing smear through wrapped lines
- [ ] Remove smear when exiting insert mode
