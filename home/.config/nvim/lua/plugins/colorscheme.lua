-- Catppuccin Mocha: same palette as kitty, Waybar and the rest of the desktop.
-- Plugin highlights (blink, telescope, gitsigns, ...) are detected automatically.
return {
  "catppuccin/nvim",
  name = "catppuccin",
  lazy = false,
  priority = 1000,
  opts = {
    flavour = "mocha",
    -- Let kitty's translucent, blurred background show through
    transparent_background = true,
    float = { transparent = false },
  },
  config = function(_, opts)
    require("catppuccin").setup(opts)
    vim.cmd.colorscheme("catppuccin")
  end,
}
