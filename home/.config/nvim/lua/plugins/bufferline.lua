return {
  "akinsho/bufferline.nvim",
  version = "*",
  event = "VeryLazy",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  keys = {
    { "<S-h>", "<cmd>BufferLineCyclePrev<CR>", desc = "Previous buffer" },
    { "<S-l>", "<cmd>BufferLineCycleNext<CR>", desc = "Next buffer" },
    { "<leader>bd", "<cmd>bdelete<CR>", desc = "Close buffer" },
    { "<leader>bo", "<cmd>BufferLineCloseOthers<CR>", desc = "Close other buffers" },
    { "<leader>bp", "<cmd>BufferLineTogglePin<CR>", desc = "Pin buffer" },
  },
  opts = {
    options = {
      mode = "buffers",
      separator_style = "slant",
      always_show_bufferline = true,
      show_buffer_close_icons = true,
      show_close_icon = false,
      color_icons = true,
      diagnostics = "nvim_lsp",
      diagnostics_indicator = function(count, level)
        local icon = level:match("error") and "\u{f0159} " or "\u{f0026} "
        return " " .. icon .. count
      end,
      offsets = {
        { filetype = "NvimTree", text = "Explorer", highlight = "Directory", separator = true },
      },
    },
  },
}
