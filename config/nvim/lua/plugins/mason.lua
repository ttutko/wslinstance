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
      -- Mason handles ONLY the prebuilt-binary / pip tools here — these install
      -- reliably. The NODE/npm-based LSP servers are deliberately NOT listed:
      -- current mason.nvim's npm installer hangs on a random one each headless
      -- build. They're installed via plain `npm install -g` in the neovim role
      -- and registered in langs.lua/csharp.lua with mason=false. See CLAUDE.md.
      ensure_installed = {
        "lua-language-server", -- Lua LSP        (prebuilt)
        "stylua",              -- Lua formatter  (prebuilt)
        "shfmt",               -- shell formatter(prebuilt)
        "shellcheck",          -- shell linter   (prebuilt)
        "taplo",               -- TOML LSP/fmt   (prebuilt)
        "marksman",            -- Markdown LSP   (prebuilt, self-contained)
        "omnisharp",           -- C# LSP         (self-contained release)
        "netcoredbg",          -- C# debugger    (prebuilt binary)
        -- ruff + debugpy are NOT installed via Mason (its installers fail for them
        -- on trixie): ruff comes from github_bins, debugpy from a pip venv in the
        -- neovim role. See CLAUDE.md.
      },
    },
  },
}
