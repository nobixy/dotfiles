return {
  "nvim-lualine/lualine.nvim",
  event = "VeryLazy",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  opts = function()
    local lazy_status = require("lazy.status")

    return {
      options = {
        theme = "auto", -- follows the colorscheme (catppuccin)
        globalstatus = true,
        disabled_filetypes = { statusline = { "alpha" } },
      },
      sections = {
        lualine_x = {
          { lazy_status.updates, cond = lazy_status.has_updates, color = { fg = "#fab387" } },
          "filetype",
        },
      },
    }
  end,
}
