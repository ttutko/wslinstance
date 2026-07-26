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
      servers = {
        -- Python
        pyright = {},
        ruff = {}, -- linter + formatter (also used by conform below)
        -- Web / config
        ts_ls = {}, -- typescript-language-server (TS/JS)
        html = {},
        cssls = {},
        jsonls = {},
        yamlls = {},
        -- DevOps
        bashls = {},
        dockerls = {},
        docker_compose_language_service = {},
        marksman = {}, -- Markdown (binary already baked)
        taplo = {}, -- TOML (binary already baked)
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
      -- debugpy is baked by Mason; use its bundled venv python.
      local path = LazyVim.get_pkg_path("debugpy", "/venv/bin/python")
      require("dap-python").setup(path)
    end,
  },
}
