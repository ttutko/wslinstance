-- Completion keymap. blink.cmp is LazyVim's completion engine (baked offline as
-- a LazyVim dependency). The "super-tab" preset makes <Tab> accept/expand the
-- selected item and navigate the menu (<S-Tab> goes back); completions come from
-- the LSP servers wired in langs.lua / csharp.lua.
-- Presets: https://cmp.saghen.dev/configuration/keymap#presets
return {
  {
    "saghen/blink.cmp",
    opts = {
      keymap = {
        preset = "super-tab",
      },
    },
  },
}