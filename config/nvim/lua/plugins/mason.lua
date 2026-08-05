-- Mason-managed LSP servers / formatters. Same offline rule as treesitter:
-- everything listed here is installed at build time and baked in.
--
-- OFFLINE: a tool works offline only if the runtime it needs is in the
-- image. Prebuilt binaries always work; npm-based servers (bash-language-server,
-- json-lsp, yaml-language-server, pyright, ...) work because the `nodejs` role
-- bakes Node.js; pip-based ones (debugpy) work via the image's Python. To add a
-- server: list it here AND in ansible/roles/neovim/files/prime.lua (bake) AND
-- register it in opts.servers (langs.lua/csharp.lua) so it starts, then rebuild.
-- Anything needing a runtime not in the image (Go, Ruby, ...) needs that added
-- first.
return {
  {
    "mason-org/mason.nvim",
    opts = {
      -- Append Mason's bin to PATH (don't prepend) so the tree-sitter CLI the
      -- neovim role installs in /usr/local/bin wins over any Mason-provided one.
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
