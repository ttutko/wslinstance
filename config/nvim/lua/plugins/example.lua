-- Sample plugin spec — a template for adding your own.
-- Anything you add here is downloaded at BUILD time (network available) and
-- baked into the image. Uncomment / edit and rebuild.
return {
  -- Set the default colorscheme (tokyonight ships with LazyVim).
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "tokyonight",
    },
  },

  -- Example: add a new plugin (uncomment to enable, then rebuild).
  -- {
  --   "folke/zen-mode.nvim",
  --   cmd = "ZenMode",
  --   opts = {},
  --   keys = { { "<leader>z", "<cmd>ZenMode<CR>", desc = "Zen Mode" } },
  -- },
}
