-- Priming pass 2: compile treesitter parsers for offline use. Runs in its OWN
-- headless nvim (must NOT share a session with the Mason priming pass, which
-- leaves nvim-treesitter's parser registry uninitialised):
--   NVIM_APPNAME=lvim nvim --headless -c 'luafile /path/prime-ts.lua'
--
-- nvim-treesitter `main` branch compiles parsers via the `tree-sitter` CLI + a
-- C compiler. The neovim role puts a glibc-compatible tree-sitter in
-- /usr/local/bin (Mason's needs glibc 2.39, too new for Debian 12) and installs
-- gcc for the build. install() returns an async Task that must be :wait()-ed.

local function log(msg)
  io.stderr:write("[prime-ts] " .. msg .. "\n")
end

log("tree-sitter cli executable: " .. tostring(vim.fn.executable("tree-sitter") == 1))
log("cc executable: " .. tostring(vim.fn.executable("cc") == 1 or vim.fn.executable("gcc") == 1))

local ok_ts, ts = pcall(require, "nvim-treesitter")
if ok_ts and type(ts.install) == "function" then
  pcall(function() ts.setup() end)
  local langs = {
    "lua", "luadoc", "vim", "vimdoc", "query",
    "bash", "python", "json",
    "yaml", "markdown", "markdown_inline", "toml",
    "regex", "diff", "gitcommit", "dockerfile",
  }
  local ok, err = pcall(function()
    local task = ts.install(langs)          -- async Task
    if task and type(task.wait) == "function" then
      task:wait(600000)                     -- BLOCK until all parsers built
    end
  end)
  if not ok then log("treesitter install error: " .. tostring(err)) end
  log("treesitter installed: " .. table.concat(ts.get_installed() or {}, ","))
else
  log("WARN: nvim-treesitter install() API not found")
end

vim.cmd("qa!")
