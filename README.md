<!-- panvimdoc-ignore-start -->

# Smear cursor for Neovim

_Neovim plugin to animate the cursor with a smear effect in all terminals. Inspired by [Neovide's animated cursor](https://neovide.dev/features.html#animated-cursor)._

This plugin is intended for terminals/GUIs that can only display text and do not have graphical capabilities (unlike [Neovide](https://neovide.dev/), or the [Kitty](https://sw.kovidgoyal.net/kitty/) terminal). Also, check out the [karb94/neoscroll.nvim](https://github.com/karb94/neoscroll.nvim) plugin for smooth scrolling!


## 🚀 Demo

[Demo](https://private-user-images.githubusercontent.com/17217484/389300116-fc95b4df-d791-4c53-9141-4f870eb03ab2.mp4?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3MzI0NzY0NDAsIm5iZiI6MTczMjQ3NjE0MCwicGF0aCI6Ii8xNzIxNzQ4NC8zODkzMDAxMTYtZmM5NWI0ZGYtZDc5MS00YzUzLTkxNDEtNGY4NzBlYjAzYWIyLm1wND9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNDExMjQlMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjQxMTI0VDE5MjIyMFomWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPTg1NjFhZjJlODQ4YmU2NjAzY2EzY2I3NWMzMzI5MWQ1Njk2MTExYmEwYmExNTMwMThmYTJjYjE2ZjIyOThjNjMmWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0In0.Skw2VVyVWVkMe4ht6mvl_AZ_6QasJm8O6qsIZmcQ2XE)

<!-- panvimdoc-ignore-end -->


## 📦 Installation

> [!NOTE]
> After enabling the plugin in your configuration, you can toggle the smear cursor on and off with the `:SmearCursorToggle` command or with `:lua require("smear_cursor").toggle()`.


### Minimum requirements

- Neovim 0.10.2


### Using [lazy.nvim](https://lazy.folke.io/)

In `~/.config/nvim/lua/plugins/smear_cursor.lua`, add:
```lua
return {
  "sphamba/smear-cursor.nvim",
  opts = {},
}
```


### Using [vim-plug](https://github.com/junegunn/vim-plug)

In your `init.vim`, add:

```vim
call plug#begin()
Plug 'sphamba/smear-cursor.nvim'
call plug#end()

lua require('smear_cursor').enabled = true
```


## ⚙  Configuration

### Using [lazy.nvim](https://lazy.folke.io/)

Here are the default configuration options:
```lua
return {
  "sphamba/smear-cursor.nvim",

  opts = {
    -- Smear cursor color. Defaults to Cursor GUI color if not set.
    -- Set to "none" to match the text color at the target cursor position.
    cursor_color = "#d3cdc3",

    -- Background color. Defaults to Normal GUI background color if not set.
    normal_bg = "#282828",

    -- Smear cursor when switching buffers or windows.
    smear_between_buffers = true,

    -- Smear cursor when moving within line or to neighbor lines.
    smear_between_neighbor_lines = true,

    -- Set to `true` if your font supports legacy computing symbols (block unicode symbols).
    -- Smears will blend better on all backgrounds.
    legacy_computing_symbols_support = false,
  },
}
```

Refer to [`lua/smear_cursor/config.lua`](https://github.com/sphamba/smear-cursor.nvim/blob/main/lua/smear_cursor/config.lua) for the full list of configuration options that can be set with `opts`.

> [!TIP]
> Some terminals override the cursor color set by Neovim. If that is the case, manually put the actual cursor color in your config, as shown above, to get a matching smear color.


### Faster smear

As an example of further configuration, you can tune the smear dynamics to be snappier:
```lua
  opts = {                         -- Default  Range
    stiffness = 0.8,               -- 0.6      [0, 1]
    trailing_stiffness = 0.5,      -- 0.3      [0, 1]
    distance_stop_animating = 0.5, -- 0.1      > 0
    hide_target_hack = false,      -- true     boolean
  },
```


> [!WARNING]
> **🔥 FIRE HAZARD 🔥** Feel free to experiment with all the configuration options, but be aware that some combinations may cause your cursor to flicker or even **catch fire**. That can happen with the following settings:
> ```lua
>   opts = {
>     cursor_color = "#ff8800",
>     stiffness = 0.3,
>     trailing_stiffness = 0.1,
>     trailing_exponent = 3,
>     gamma = 1,
>     volume_reduction_exponent = -0.1,
>   }
> ```

### Transparent background

Drawing the smear over a transparent background works better when using a font that supports legacy computing symbols, therefore setting the following option:
```lua
  opts = {
    legacy_computing_symbols_support = true,
  },
```

If your font does not support legacy computing symbols, there will be a shadow under the smear. You may set a color for this shadow to be less noticeable:
```lua
  opts = {
    transparent_bg_fallback_color = "#303030",
  },
```


### Using `init.vim`

You can set the configuration variables in your `init.vim` file like this:
```vim
lua require('smear_cursor').setup({
    \cursor_color = '#d3cdc3',
\})
```


## 🤕 Known issues

- There is a shadow around the smear (text become invisible). This is inherent to the way the smear is rendered, as Neovim is not able to render superimposed characters. The shadow is less noticeable when the smear is moving faster (see configuration options).
- Likely not compatible with other plugins that modify the cursor.


<!-- panvimdoc-ignore-start -->

## 👨‍💻 Contributing

Please feel free to open an issue or a pull request if you have any suggestions or improvements!
This project uses [pre-commit](https://pre-commit.com/) hooks to ensure code quality (with [StyLua](https://github.com/JohnnyMorganz/StyLua)) and meaningful commit messages (following [Conventional Commits](https://www.conventionalcommits.org/))


### Requirements

- Neovim >= 0.10.2
- Make
- pre-commit (`pip install pre-commit`)


### Setup

1. Clone the repository
2. Run `make install` to install the pre-commit hooks

<!-- panvimdoc-ignore-end -->
