-- Custom keymaps (LazyVim defines many defaults already).
-- Docs: https://lazyvim.org/configuration/keymaps
-- Leader is <Space>.

local map = vim.keymap.set

-- Sample: clear search highlight with <Esc> in normal mode.
map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })

-- Add your own below, e.g.:
-- map("n", "<leader>w", "<cmd>w<CR>", { desc = "Save file" })
