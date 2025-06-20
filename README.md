<!-- panvimdoc-ignore-start -->

# Smear cursor for Neovim

_Neovim plugin to animate the cursor with a smear effect in all terminals. Inspired by [Neovide's animated cursor](https://neovide.dev/features.html#animated-cursor)._

This plugin is intended for terminals/GUIs that can only display text and do not have graphical capabilities (unlike [Neovide](https://neovide.dev/), or the [Kitty](https://sw.kovidgoyal.net/kitty/) terminal). Also, check out the [karb94/neoscroll.nvim](https://github.com/karb94/neoscroll.nvim) plugin for smooth scrolling!


## 🚀 Demo

[Demo](https://private-user-images.githubusercontent.com/17217484/389300116-fc95b4df-d791-4c53-9141-4f870eb03ab2.mp4?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3MzI0NzY0NDAsIm5iZiI6MTczMjQ3NjE0MCwicGF0aCI6Ii8xNzIxNzQ4NC8zODkzMDAxMTYtZmM5NWI0ZGYtZDc5MS00YzUzLTkxNDEtNGY4NzBlYjAzYWIyLm1wND9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNDExMjQlMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjQxMTI0VDE5MjIyMFomWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPTg1NjFhZjJlODQ4YmU2NjAzY2EzY2I3NWMzMzI5MWQ1Njk2MTExYmEwYmExNTMwMThmYTJjYjE2ZjIyOThjNjMmWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0In0.Skw2VVyVWVkMe4ht6mvl_AZ_6QasJm8O6qsIZmcQ2XE)

Some configuration examples:

| Default | Faster |
| --- | --- |
| ![Image](https://github.com/user-attachments/assets/8d4ea0e6-6764-48ce-a182-7f1a63ffd762) | ![Image](https://github.com/user-attachments/assets/6c2ae042-55df-48a3-8e18-57517dc06633) |

| Smooth cursor without smear | Fire hazard |
| --- | --- |
| ![Image](https://github.com/user-attachments/assets/47950a0c-2bbe-4148-b633-fea6d5e1f985) | ![Image](https://github.com/user-attachments/assets/ba847071-f918-4e8f-ae74-169a31e05368) |

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
    -- Smear cursor when switching buffers or windows.
    smear_between_buffers = true,

    -- Smear cursor when moving within line or to neighbor lines.
    -- Use `min_horizontal_distance_smear` and `min_vertical_distance_smear` for finer control
    smear_between_neighbor_lines = true,

    -- Draw the smear in buffer space instead of screen space when scrolling
    scroll_buffer_space = true,

    -- Set to `true` if your font supports legacy computing symbols (block unicode symbols).
    -- Smears will blend better on all backgrounds.
    legacy_computing_symbols_support = false,

    -- Smear cursor in insert mode.
    -- See also `vertical_bar_cursor_insert_mode` and `distance_stop_animating_vertical_bar`.
    smear_insert_mode = true,
  },
}
```

Refer to [`lua/smear_cursor/config.lua`](https://github.com/sphamba/smear-cursor.nvim/blob/main/lua/smear_cursor/config.lua) and [`lua/smear_cursor/color.lua`](https://github.com/sphamba/smear-cursor.nvim/blob/main/lua/smear_cursor/color.lua) for the full list of configuration options that can be set with `opts`.

> [!TIP]
> Some terminals override the cursor color set by Neovim. If that is the case, manually put the actual cursor color in your config to get a matching smear color:
> ```lua
>   opts = {
>     -- Smear cursor color. Defaults to Cursor GUI color if not set.
>     -- Set to "none" to match the text color at the target cursor position.
>     cursor_color = "#d3cdc3",
>   }
> ```

> [!NOTE]
> Fonts with legacy computing symbols support seems to be rare. One notable example is [Cascadia Code](https://github.com/microsoft/cascadia-code/releases). You can still use smear-cursor.nvim without such a font.


### Examples

> [!TIP]
> See videos at the top for visual examples.

<details>
<summary>🔥 Faster smear</summary>

As an example of further configuration, you can tune the smear dynamics to be snappier:
```lua
  opts = {                                -- Default  Range
    stiffness = 0.9,                      -- 0.65     [0, 1]
    trailing_stiffness = 0.7,             -- 0.5      [0, 1]
    stiffness_insert_mode = 0.7,          -- 0.55     [0, 1]
    trailing_stiffness_insert_mode = 0.7, -- 0.55     [0, 1]
    damping = 0.65,                       -- 0.6      [0, 1]
    distance_stop_animating = 0.5,        -- 0.1      > 0
  },
```

If you notice a low framerate, you can try lowering the time interval between draws (default is 17ms):
```lua
  opts = {
    time_interval = 7, -- milliseconds
  },
```

You can also change the "bounciness" of the smear by adjusting the `damping` parameter (default to `0.6`). Increasing it (_e.g._ to `0.65`) will reduce the overshoot, while decreasing it (_e.g._ to `0.55`) will make the smear more elastic.


> **🔥 FIRE HAZARD 🔥**
>
> Feel free to experiment with all the configuration options, but be aware that some combinations may cause your cursor to flicker or even **catch fire**. That can happen with the following settings:
> ```lua
>   opts = {
>     cursor_color = "#ff8800",
>     stiffness = 0.3,
>     trailing_stiffness = 0.15,
>     damping = 0.5,
>     trailing_exponent = 5,
>     never_draw_over_target = true,
>     hide_target_hack = true,
>     gamma = 1,
>   }
> ```

</details>

<details>
<summary>█ Smooth cursor without smear</summary>

If you wish to only have a smoother cursor that keeps its rectangular shape (without the trail), you can set the following options:

```lua
  opts = {
    stiffness = 0.65,
    trailing_stiffness = 0.64,
    damping = 0.63,
  },
```

</details>

<details>
<summary>🌌 Transparent background</summary>

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

</details>

<details>
<summary>🔲 No GUI colors</summary>

If you are not using `termguicolors`, you need to manually set a color gradient for the smear (it can be a single color):
```lua
  opts = {
    cterm_cursor_colors = { 240, 245, 250, 255 },
    cterm_bg = 235,
  }
```

If you are not using `guicursor`, and you notice the cursor getting duplicated (smear visible at the same time as the _real_ cursor), try setting
```lua
  opts = {
    hide_target_hack = true,
    never_draw_over_target = true,
  }
```

</details>


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
