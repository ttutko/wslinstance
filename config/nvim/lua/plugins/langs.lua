-- Broad multi-language LSP + autocompletion + formatting (Web/config, Python,
-- DevOps). Hand-wired (rather than via LazyVim lang extras) so the exact set of
-- servers is predictable and matches what gets baked offline. C# lives in its
-- own file (csharp.lua); Lua is a LazyVim default.
--
-- OFFLINE: every server/formatter/debugger below is installed at BUILD time by
-- Mason and MUST also be listed in config/nvim/lua/plugins/mason.lua AND
-- ansible/roles/neovim/files/prime.lua (the bake list). Node-based servers need
-- the Node runtime added by the `nodejs` ansible role. Treesitter parsers for
-- these languages are in treesitter.lua + prime-ts.lua. Keep all lists in sync.
return {
  -- LSP servers: registered here so LazyVim/lspconfig starts them and blink.cmp
  -- offers their completions. Names are lspconfig server names.
  {
    "neovim/nvim-lspconfig",
    opts = {
      -- NOTE: every npm-based server below is set `mason = false` — the neovim
      -- role installs them via plain `npm install -g` onto PATH (Mason's npm
      -- installer hangs headless). `mason = false` makes LazyVim start them from
      -- the PATH binary and skip the Mason install. Only ruff/marksman/taplo are
      -- Mason-managed here (reliable prebuilt binaries).
      servers = {
        -- Python
        pyright = { mason = false },
        ruff = { mason = false }, -- ruff binary from github_bins (on PATH); also conform
        -- Web / config
        ts_ls = { mason = false }, -- typescript-language-server (TS/JS)
        html = { mason = false },
        cssls = { mason = false },
        jsonls = { mason = false },
        yamlls = { mason = false },
        -- DevOps
        bashls = { mason = false },
        dockerls = { mason = false },
        docker_compose_language_service = { mason = false },
        marksman = { mason = false }, -- Markdown (github_bins binary on PATH)
        taplo = {}, -- TOML (Mason prebuilt binary)
      },
    },
  },

  -- Formatters via conform.nvim (LazyVim's formatter engine).
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        python = { "ruff_format" },
        javascript = { "prettier" },
        javascriptreact = { "prettier" },
        typescript = { "prettier" },
        typescriptreact = { "prettier" },
        json = { "prettier" },
        jsonc = { "prettier" },
        yaml = { "prettier" },
        html = { "prettier" },
        css = { "prettier" },
        markdown = { "prettier" },
      },
    },
  },

  -- Python debugging via debugpy (opted in with the Python group).
  {
    "mfussenegger/nvim-dap-python",
    ft = "python",
    dependencies = { "mfussenegger/nvim-dap" },
    config = function()
      -- debugpy is installed into a dedicated venv by the neovim role (Mason's
      -- pip installer fails for it on trixie). Point dap-python at that python.
      require("dap-python").setup("/opt/debugpy-venv/bin/python")
    end,
  },
}
