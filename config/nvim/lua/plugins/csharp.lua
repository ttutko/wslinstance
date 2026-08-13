-- C# / .NET editing support (C#-ONLY; the F# half of LazyVim's lang.dotnet extra
-- is deliberately omitted — fsautocomplete/fantomas install via `dotnet tool`/NuGet
-- and are unwanted here). Mirrors the C# portions of
-- lazyvim.plugins.extras.lang.dotnet.
--
-- OFFLINE NOTE: the tools below (omnisharp, netcoredbg) are baked at BUILD time
-- — they must ALSO appear in ansible/roles/neovim/files/prime.lua so they are
-- installed while the network is available. The c_sharp treesitter parser is
-- likewise primed via prime-ts.lua. Keep those lists in sync (see CLAUDE.md).
-- NB: csharpier is intentionally NOT used — its Mason installer (a `dotnet tool`)
-- hangs in headless priming, and OmniSharp already formats C# via the LSP.
return {
  -- Enhanced goto-definition (steps into decompiled / $metadata sources).
  { "Hoffs/omnisharp-extended-lsp.nvim", lazy = true },

  -- Treesitter parser for C# (also listed in treesitter.lua / prime-ts.lua).
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "c_sharp" } },
  },

  -- Bake the C# Mason tools (kept in sync with prime.lua + mason.lua).
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "omnisharp", "netcoredbg" } },
  },

  -- OmniSharp LSP, with goto-definition routed through omnisharp-extended.
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        omnisharp = {
          handlers = {
            ["textDocument/definition"] = function(...)
              return require("omnisharp_extended").handler(...)
            end,
          },
          keys = {
            {
              "gd",
              LazyVim.has("telescope.nvim") and function()
                require("omnisharp_extended").telescope_lsp_definitions()
              end or function()
                require("omnisharp_extended").lsp_definitions()
              end,
              desc = "Goto Definition",
            },
          },
          enable_roslyn_analyzers = true,
          organize_imports_on_format = true,
          enable_import_completion = true,
        },
      },
    },
  },

  -- netcoredbg adapter for C# debugging.
  {
    "mfussenegger/nvim-dap",
    optional = true,
    -- `config` (not `opts`): nvim-dap has no setup(), so lazy.nvim's default
    -- opts-handler would call require("dap").setup(opts) and error on nil.
    config = function()
      local dap = require("dap")
      if not dap.adapters["netcoredbg"] then
        -- Resolve netcoredbg robustly: prefer PATH, but fall back to the Mason
        -- install path so the command never freezes to "" if Mason's bin isn't
        -- on PATH yet when this runs (which showed up as a checkhealth error).
        local cmd = vim.fn.exepath("netcoredbg")
        if cmd == "" then
          cmd = vim.fn.stdpath("data") .. "/mason/bin/netcoredbg"
        end
        dap.adapters["netcoredbg"] = {
          type = "executable",
          command = cmd,
          args = { "--interpreter=vscode" },
          options = {
            detached = false,
          },
        }
      end
      if not dap.configurations["cs"] then
        dap.configurations["cs"] = {
          {
            type = "netcoredbg",
            name = "Launch file",
            request = "launch",
            ---@diagnostic disable-next-line: redundant-parameter
            program = function()
              return vim.fn.input("Path to dll: ", vim.fn.getcwd() .. "/", "file")
            end,
            cwd = "${workspaceFolder}",
          },
        }
      end
    end,
  },
}
