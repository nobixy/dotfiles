-- Start screen when Neovim opens without a file
return {
  "goolord/alpha-nvim",
  event = "VimEnter",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    local dashboard = require("alpha.themes.dashboard")

    dashboard.section.header.val = {
      "                                                     ",
      "  ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗ ",
      "  ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║ ",
      "  ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║ ",
      "  ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║ ",
      "  ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║ ",
      "  ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝ ",
      "                                                     ",
    }

    -- Icons are escapes (Nerd Font codepoints) so they survive any editor
    dashboard.section.buttons.val = {
      dashboard.button("f", "\u{f002}  Find file", "<cmd>Telescope find_files<CR>"),
      dashboard.button("r", "\u{f0c5}  Recent files", "<cmd>Telescope oldfiles<CR>"),
      dashboard.button("s", "\u{f022}  Find text", "<cmd>Telescope live_grep<CR>"),
      dashboard.button("e", "\u{f07b}  File explorer", "<cmd>NvimTreeToggle<CR>"),
      dashboard.button("l", "\u{f03d6}  Plugins", "<cmd>Lazy<CR>"),
      dashboard.button("q", "\u{f426}  Quit", "<cmd>qa<CR>"),
    }

    require("alpha").setup(dashboard.opts)
  end,
}
