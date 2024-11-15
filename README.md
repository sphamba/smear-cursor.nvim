# Smear cursor for Neovim

_Neovim plugin to animate the cursor with a smear effect_


# Development TODOs

## Features

- [ ] Cursor speed
- [ ] Better persistence management
- [ ] Sub-character smear
- [ ] Color gradient smear
- [ ] Reduce size with speed
- [ ] Smear when jumping to commands
- [ ] Smear when jumping between windows

## Fixes

- [ ] Smear outside buffer (further than the last line)
  - [ ] Transition to a buffer with less lines than the current cursor row
- [ ] Drawing smear through folded lines
- [ ] Drawing smear through wrapped lines
- [ ] Remove smear when exiting insert mode
