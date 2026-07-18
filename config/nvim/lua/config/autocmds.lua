-- Custom autocommands (LazyVim provides useful defaults already).
-- Docs: https://lazyvim.org/configuration/autocmds

-- Sample: highlight text briefly when yanked.
vim.api.nvim_create_autocmd("TextYankPost", {
  group = vim.api.nvim_create_augroup("wsl_highlight_yank", { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})
