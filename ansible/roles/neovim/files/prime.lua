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
    "taplo",
    "omnisharp", "netcoredbg",
    -- ruff (github_bins) + debugpy (pip venv) are installed by the neovim role,
    -- NOT Mason — its installers fail for them on trixie.
  }
  -- Trigger installs and wait on mason's COMPLETION EVENTS, not on is_installed().
  -- Polling is_installed() is racy: mason flips a package's installed-state true
  -- before its install task finishes writing, so the wait returns early and the
  -- `qa!` below terminates the still-running install ("Neovim is exiting while
  -- packages are still installing"), leaving a random tool half-installed. The
  -- install:success / install:failed events fire on ACTUAL completion, whoever
  -- started the install (LazyVim's mason config may have already begun the
  -- ensure_installed set; newer mason.nvim also errors if we call install() on an
  -- in-flight package — hence the pcall).
  local pending = 0
  for _, name in ipairs(tools) do
    local ok_pkg, pkg = pcall(registry.get_package, name)
    if ok_pkg and not pkg:is_installed() then
      pending = pending + 1
      local function settled() pending = pending - 1 end
      pkg:once("install:success", settled)
      pkg:once("install:failed", settled)
      pcall(function() pkg:install() end)
    end
  end
  vim.wait(1200000, function() return pending == 0 end, 200)
  -- Belt-and-suspenders: give any final receipt writes a moment to flush before
  -- we quit, and only report done once every target is actually on disk.
  vim.wait(5000, function() return false end, 1000)
end
log("mason done")

vim.cmd("qa!")
