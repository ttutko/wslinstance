-- Mason-managed LSP servers / formatters. Same offline rule as treesitter:
-- everything listed here is installed at build time and baked in.
--
-- IMPORTANT (offline): only tools Mason ships as SELF-CONTAINED prebuilt
-- binaries are listed. npm-based servers (bash-language-server, json-lsp,
-- yaml-language-server, pyright, ...) require a Node.js runtime to *execute*,
-- and Node is not installed in this image — so they would not work offline.
-- To add them: install nodejs in the image (see ansible/roles/apt_tools), add
-- the server here, and rebuild so it is re-primed.
return {
  {
    "williamboman/mason.nvim",
    opts = {
      -- Append Mason's bin to PATH (don't prepend) so the system tree-sitter
      -- in /usr/local/bin (glibc-compatible) wins over Mason's glibc-2.39 one.
      PATH = "append",
      ensure_installed = {
        "lua-language-server", -- Lua LSP        (prebuilt)
        "stylua",              -- Lua formatter  (prebuilt)
        "shfmt",               -- shell formatter(prebuilt)
        "shellcheck",          -- shell linter   (prebuilt)
        "taplo",               -- TOML LSP/fmt   (prebuilt)
        "marksman",            -- Markdown LSP   (prebuilt, self-contained)
      },
    },
  },
}
