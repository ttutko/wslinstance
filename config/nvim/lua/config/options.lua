-- Options loaded before lazy.nvim starts.
-- LazyVim applies sensible defaults automatically; put OVERRIDES here.
-- Docs: https://lazyvim.org/configuration/general

local opt = vim.opt

opt.relativenumber = true   -- relative line numbers (set false for absolute)
opt.wrap = false            -- no soft wrap by default
opt.scrolloff = 8           -- keep cursor away from screen edges

-- Use the Windows clipboard through WSL. xsel is installed; for the Windows
-- system clipboard you can also install win32yank. Leaving unset uses LazyVim's
-- default OSC52/clipboard handling.
-- vim.g.clipboard = "osc52"
