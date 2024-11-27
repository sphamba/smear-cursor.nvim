-- Instructions: open this file in Neovim and run `source %`

local foldable_lines = {
	{
		"Hello",
	},
}

-- Line 1 with concealed characters
-- Line 2 without concealed characters
-- Line 3 with concealed characters

-- Line with	wide	characters

-- Line with extmark above (try to put the extmark at the very top of the screen)
-- Extmark after
-- Extmark over
-- Extmark inline
-- Line with extmark below

-- Line with 🎉 emoji
--
--
--
-- Also test:
-- - Popup menus
-- - Sidebar
-- - Split windows
-- - Tabs

-- 0│││1│││2│││3│││4
-- ─┘│││││││││││││││
-- ──┘││││││││││││││
-- ───┘│││││││││││││
-- 1───┘│││││││││││1
-- ─────┘│││││││││││
-- ──────┘││││││││││
-- ───────┘│││││││││
-- 2───────┘│││││││2
-- ─────────┘│││││││
-- ──────────┘││││││
-- ───────────┘│││││
-- 3───────────┘│││3
-- ─────────────┘│││
-- ──────────────┘││
-- ───────────────┘│
-- 4───1───2───3───4

-- This is a very long line. This is a very long line. This is a very long line. This is a very long line. This is a very long line. This is a very long line. This is a very long line. This is a very long line. This is a very long line. This is a very long line. This is a very long line. This is a very long line. This is a very long line. This is a very long line. This is a very long line. This is a very long line. This is a very long line. This is a very long line. This is a very long line. This is a very long line. This is a very long line. This is a very long line.

--
-- ....
--
-- ........
--
-- ............
--
-- ................
--
-- ....................
--
-- ........................
--
-- ............................
--
-- ................................
--
-- ............................
--
-- ........................
--
-- ....................
--
-- ............
--
-- ........
--
-- ....
--

local buffer_id = vim.api.nvim_get_current_buf()
local ns = vim.api.nvim_create_namespace("smear_cursor_test")
vim.api.nvim_buf_clear_namespace(buffer_id, ns, 0, -1)

vim.cmd([[
	syntax match SmearCursorConcealed1 /Line 1/ conceal
	syntax match SmearCursorConcealed3 /Line 3/ conceal cchar=*
	setlocal conceallevel=2
	setlocal concealcursor=n
]])

local extmarks_first_line = 14

vim.api.nvim_buf_set_extmark(buffer_id, ns, extmarks_first_line, 0, {
	virt_lines = { { { "Extmark above", "Question" } } },
	virt_lines_above = true,
})

vim.api.nvim_buf_set_extmark(buffer_id, ns, extmarks_first_line + 1, 0, {
	virt_text = { { "*", "Question" } },
	virt_text_pos = "eol",
})

vim.api.nvim_buf_set_extmark(buffer_id, ns, extmarks_first_line + 2, 10, {
	virt_text = { { "*", "Question" } },
	virt_text_pos = "overlay",
})

vim.api.nvim_buf_set_extmark(buffer_id, ns, extmarks_first_line + 3, 10, {
	virt_text = { { "*", "Question" } },
	virt_text_pos = "inline",
})

vim.api.nvim_buf_set_extmark(buffer_id, ns, extmarks_first_line + 4, 0, {
	virt_lines = { { { "Extmark below", "Question" } } },
})

local function create_float(content, row, col)
	local buffer_id = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buffer_id, 0, -1, false, { content })
	vim.api.nvim_buf_set_option(buffer_id, "filetype", "smear_cursor")
	vim.api.nvim_open_win(buffer_id, false, {
		relative = "win",
		row = row,
		col = col,
		width = #content,
		height = 1,
		style = "minimal",
		focusable = true,
	})
end

create_float("Floating window", 22, 10)
