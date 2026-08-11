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
-- instead. tree-sitter CLI is intentionally NOT installed via Mason here — the
-- neovim role installs the prebuilt one to /usr/local/bin (Mason is PATH="append"
-- so that one wins).
log("installing mason tools...")
load({ "mason.nvim", "mason-lspconfig.nvim" })
local ok_reg, registry = pcall(require, "mason-registry")
if ok_reg then
  pcall(function() registry.refresh() end)
  -- ONLY prebuilt-binary / pip tools — these install reliably via Mason. All the
  -- NODE/npm-based LSP servers (pyright, typescript, html/css/json, yaml, prettier,
  -- docker×2, bash) are intentionally absent: Mason's npm installer hangs on a
  -- random one each headless build. The neovim role installs them via plain
  -- `npm install -g` and langs.lua/csharp.lua register them with mason=false.
  local tools = {
    "lua-language-server", "stylua",
    "shfmt", "shellcheck",
    "taplo", "marksman",
    "omnisharp", "netcoredbg",
    -- ruff (github_bins) + debugpy (pip venv) are installed by the neovim role,
    -- NOT Mason — its installers fail for them on trixie.
  }
  -- Trigger an install for anything not yet installed. LazyVim's mason config
  -- may have ALREADY started installing the ensure_installed set when mason
  -- loaded, and newer mason.nvim ERRORS ("Package is already installing") if you
  -- call install() on an in-flight package — so pcall the call and ignore it.
  for _, name in ipairs(tools) do
    local ok_pkg, pkg = pcall(registry.get_package, name)
    if ok_pkg and not pkg:is_installed() then
      pcall(function() pkg:install() end)
    end
  end
  -- Wait until every target tool is installed, whoever started it. Polling
  -- installed-state (not handle "closed" events) is robust to the above pcall.
  -- Generous window: ~20 npm/pip/binary installs run concurrently and npm can be
  -- slow (a straggler like bash-language-server otherwise gets cut off).
  vim.wait(1200000, function()
    for _, name in ipairs(tools) do
      local ok_pkg, pkg = pcall(registry.get_package, name)
      if ok_pkg and not pkg:is_installed() then return false end
    end
    return true
  end, 1000)
end
log("mason done")

vim.cmd("qa!")
