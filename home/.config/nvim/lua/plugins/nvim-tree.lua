return {
  "nvim-tree/nvim-tree.lua",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  cmd = { "NvimTreeToggle", "NvimTreeFindFile", "NvimTreeFindFileToggle", "NvimTreeOpen" },
  keys = {
    -- Same key as the desktop: ALT+\ opens the app launcher in Hyprland
    { "<leader>\\", "<cmd>NvimTreeToggle<CR>", desc = "Toggle file explorer" },
    { "<leader>ee", "<cmd>NvimTreeToggle<CR>", desc = "Toggle file explorer" },
    { "<leader>ef", "<cmd>NvimTreeFindFileToggle<CR>", desc = "Toggle file explorer on current file" },
    { "<leader>ec", "<cmd>NvimTreeCollapse<CR>", desc = "Collapse file explorer" },
    { "<leader>er", "<cmd>NvimTreeRefresh<CR>", desc = "Refresh file explorer" },
    { "<leader>pv", "<cmd>NvimTreeFindFile<CR>", desc = "Project view (reveal current file)" },
  },
  init = function()
    -- nvim-tree replaces netrw...
    vim.g.loaded_netrw = 1
    vim.g.loaded_netrwPlugin = 1
    -- ...so `nvim some/dir` must load it right away to show the directory
    if vim.fn.argc(-1) == 1 then
      local stat = vim.uv.fs_stat(vim.fn.argv(0))
      if stat and stat.type == "directory" then
        require("nvim-tree")
      end
    end
  end,
  opts = {
    hijack_directories = { enable = true },
    view = {
      width = 35,
      relativenumber = true,
    },
    renderer = {
      indent_markers = { enable = true },
      icons = {
        glyphs = {
          folder = {
            arrow_closed = "\u{f061}",
            arrow_open = "\u{f063}",
          },
        },
      },
    },
    actions = {
      open_file = {
        window_picker = { enable = false },
      },
    },
    filters = {
      custom = { ".DS_Store" },
    },
    git = {
      ignore = false,
    },
  },
}
