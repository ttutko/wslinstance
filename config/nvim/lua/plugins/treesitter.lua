-- Treesitter parsers (nvim-treesitter `main` branch, as used by current
-- LazyVim). On an airgapped machine parsers CANNOT be downloaded at runtime,
-- so every parser you need is listed here and COMPILED at build time by the
-- priming step (ansible/roles/neovim/files/prime.lua).
-- To add a language: add it here AND to prime.lua's `langs` list, then rebuild
-- (or, on a networked box, `:TSInstall <lang>`) before re-exporting.
-- NOTE: `gitcommit` is intentionally omitted — its grammar compiles fine on its
-- own, but it reliably sticks in nvim-treesitter's concurrent installer during
-- headless priming (never completes, hangs the pass). Revisit when plugin
-- versions are pinned (lazy-lock). Keep this in sync with prime-ts.lua.
return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "lua", "luadoc", "vim", "vimdoc", "query",
        "bash", "python", "json",
        "yaml", "markdown", "markdown_inline", "toml",
        "regex", "diff", "dockerfile",
        "c_sharp",
        "javascript", "typescript", "tsx", "html", "css",
      },
    },
  },
}
