-- Custom keymaps (LazyVim defines many defaults already).
-- Docs: https://lazyvim.org/configuration/keymaps
-- Leader is <Space>.

local map = vim.keymap.set

-- Sample: clear search highlight with <Esc> in normal mode.
map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })

-- Exit insert mode with `jk`.
map("i", "jk", "<Esc>", { desc = "Exit insert mode" })
-- Exit terminal-insert mode with `jk` (mirrors the insert-mode escape).
map("t", "jk", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- Add your own below, e.g.:
-- map("n", "<leader>w", "<cmd>w<CR>", { desc = "Save file" })
