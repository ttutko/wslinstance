-- Priming pass 1: sync all LazyVim plugins and install Mason tools so they are
-- present with no network. Run headless:
--   NVIM_APPNAME=lvim nvim --headless -c 'luafile /path/prime.lua'
-- Treesitter parsers are handled in a SEPARATE invocation (prime-ts.lua) — doing
-- it in this same session (after Mason) leaves nvim-treesitter's parser registry
-- uninitialised ("config.list is nil").
-- The environment MUST set GIT_TERMINAL_PROMPT=0 so a git subprocess fails fast
-- instead of deadlocking a headless (no-tty) session.

local function log(msg)
  io.stderr:write("[prime] " .. msg .. "\n")
end

local function load(plugins)
  pcall(function() require("lazy").load({ plugins = plugins }) end)
end

-- 1) Install / sync ALL plugins, blocking until complete -------------------
log("syncing plugins (lazy.sync wait=true)...")
local ok_lazy, lazy = pcall(require, "lazy")
if ok_lazy then
  local ok, err = pcall(function() lazy.sync({ wait = true, show = false }) end)
  if not ok then log("lazy.sync error: " .. tostring(err)) end
else
  log("ERROR: lazy not available")
end
log("plugin sync done")

-- 2) Mason tools -----------------------------------------------------------
-- NB: tools here install as prebuilt binaries or via the Node/Python runtimes
-- baked into the image (see langs.lua). csharpier is intentionally excluded — its
-- Mason `dotnet tool` installer hangs in headless priming; OmniSharp formats C#
-- instead. tree-sitter CLI is intentionally NOT installed here — Mason's is
-- linked against glibc 2.39 and won't run on Debian 12; the neovim role installs
-- a glibc-compatible one to /usr/local/bin instead.
log("installing mason tools...")
load({ "mason.nvim", "mason-lspconfig.nvim" })
local ok_reg, registry = pcall(require, "mason-registry")
if ok_reg then
  pcall(function() registry.refresh() end)
  local tools = {
    "lua-language-server", "stylua",
    "shfmt", "shellcheck",
    "taplo", "marksman",
    "omnisharp", "netcoredbg",
    -- Python
    "pyright", "ruff", "debugpy",
    -- Web / config (node-based)
    "typescript-language-server", "html-lsp", "css-lsp",
    "json-lsp", "yaml-language-server", "prettier",
    -- DevOps (node-based)
    "bash-language-server",
    "dockerfile-language-server", "docker-compose-language-service",
  }
  local remaining = 0
  for _, name in ipairs(tools) do
    local ok_pkg, pkg = pcall(registry.get_package, name)
    if ok_pkg and not pkg:is_installed() then
      remaining = remaining + 1
      pkg:install():once("closed", function() remaining = remaining - 1 end)
    end
  end
  vim.wait(480000, function() return remaining == 0 end, 500)
end
log("mason done")

vim.cmd("qa!")
