-- Treesitter parsers (nvim-treesitter `main` branch, as used by current
-- LazyVim). On an airgapped machine parsers CANNOT be downloaded at runtime,
-- so every parser you need is listed here and COMPILED at build time by the
-- priming step (ansible/roles/neovim/files/prime.lua).
-- To add a language: add it here AND to prime.lua's `langs` list, then rebuild
-- (or, on a networked box, `:TSInstall <lang>`) before re-exporting.
return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "lua", "luadoc", "vim", "vimdoc", "query",
        "bash", "python", "json",
        "yaml", "markdown", "markdown_inline", "toml",
        "regex", "diff", "gitcommit", "dockerfile",
        "c_sharp",
        "javascript", "typescript", "tsx", "html", "css",
      },
    },
  },
}
