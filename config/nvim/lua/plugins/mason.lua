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
        "omnisharp",           -- C# LSP         (self-contained release)
        "netcoredbg",          -- C# debugger    (prebuilt binary)
        -- Python (needs Node for pyright; Python for debugpy)
        "pyright",             -- Python LSP     (node)
        "ruff",                -- Python lint/fmt(prebuilt binary)
        "debugpy",             -- Python debugger(pip/venv)
        -- Web / config (all node-based)
        "typescript-language-server",  -- TS/JS LSP
        "html-lsp",            -- HTML LSP       (node)
        "css-lsp",             -- CSS LSP        (node)
        "json-lsp",            -- JSON LSP       (node)
        "yaml-language-server",-- YAML LSP       (node)
        "prettier",            -- web formatter  (node)
        -- DevOps
        "bash-language-server",-- Bash LSP       (node)
        "dockerfile-language-server",       -- Dockerfile LSP (node)
        "docker-compose-language-service",  -- compose LSP    (node)
      },
    },
  },
}
