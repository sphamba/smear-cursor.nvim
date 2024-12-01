-- Instructions: open this file in Neovim and run `source %`
-- Warning: this will open a lot of floating windows

local draw = require("smear_cursor.draw")

draw.clear()

local row = 2
local col = 2

draw.draw_quad({
	{ row, col },
	{ row, col + 2 },
	{ row + 2, col + 2 },
	{ row + 2, col },
})

-- Quads slope 1/8

col = 6

draw.draw_quad({
	{ row, col },
	{ row + 1, col + 9 },
	{ row + 10, col + 8 },
	{ row + 9, col - 1 },
})

row = 3
col = 16

draw.draw_quad({
	{ row, col },
	{ row - 1, col + 9 },
	{ row + 8, col + 10 },
	{ row + 9, col + 1 },
})

-- Quads slope 1/4

row = 2
col = 29

draw.draw_quad({
	{ row, col },
	{ row + 2, col + 9 },
	{ row + 11, col + 7 },
	{ row + 9, col - 2 },
})

row = 4
col = 39

draw.draw_quad({
	{ row, col },
	{ row - 2, col + 9 },
	{ row + 7, col + 11 },
	{ row + 9, col + 2 },
})

-- Quads slope 1/2

row = 2
col = 55

draw.draw_quad({
	{ row, col },
	{ row + 4, col + 9 },
	{ row + 13, col + 5 },
	{ row + 9, col - 4 },
})

row = 6
col = 65

draw.draw_quad({
	{ row, col },
	{ row - 4, col + 9 },
	{ row + 5, col + 13 },
	{ row + 9, col + 4 },
})

-- Quads slope 1

row = 13
col = 6

draw.draw_quad({
	{ row, col },
	{ row + 4, col + 5 },
	{ row + 9, col + 1 },
	{ row + 5, col - 4 },
})

row = 17
col = 12

draw.draw_quad({
	{ row, col },
	{ row - 4, col + 5 },
	{ row + 1, col + 9 },
	{ row + 5, col + 4 },
})

-- Lines

row = 23
col = 2

for i = 0, 8 do
	draw.draw_quad({
		{ row, col + 10 * i },
		{ row + i, col + 10 * i + 9 },
		{ row + i + 1, col + 10 * i + 9 },
		{ row + 1, col + 10 * i },
	})
end

row = 32
col = 2

for i = 8, 0, -1 do
	draw.draw_quad({
		{ row, col },
		{ row, col + 1 },
		{ row + 9, col + i + 1 },
		{ row + 9, col + i },
	})

	col = col + 4

	draw.draw_quad({
		{ row, col },
		{ row, col + 1 / 8 },
		{ row + 9, col + i + 1 / 8 },
		{ row + 9, col + i },
	})

	col = col + 5
end
