return {
  "nvim-telescope/telescope.nvim",
  version = "0.2.*", -- the old 0.1.x branch hasn't been updated since 2024
  cmd = "Telescope",
  dependencies = {
    "nvim-lua/plenary.nvim",
    { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    "nvim-telescope/telescope-ui-select.nvim", -- code actions etc. in a Telescope picker
    "nvim-tree/nvim-web-devicons",
  },
  keys = {
    { "<leader>ff", "<cmd>Telescope find_files<CR>", desc = "Find files" },
    { "<leader>fr", "<cmd>Telescope oldfiles<CR>", desc = "Recent files" },
    { "<leader>fs", "<cmd>Telescope live_grep<CR>", desc = "Find string (grep)" },
    { "<leader>fc", "<cmd>Telescope grep_string<CR>", desc = "Find string under cursor" },
    { "<leader>fb", "<cmd>Telescope buffers<CR>", desc = "Find buffer" },
    { "<leader>fh", "<cmd>Telescope help_tags<CR>", desc = "Find help" },
    { "<leader>fk", "<cmd>Telescope keymaps<CR>", desc = "Find keymap" },
    { "<leader>fd", "<cmd>Telescope diagnostics<CR>", desc = "Find diagnostics" },
    { "<leader>f.", "<cmd>Telescope resume<CR>", desc = "Resume last search" },
  },
  config = function()
    local telescope = require("telescope")
    local actions = require("telescope.actions")

    telescope.setup({
      defaults = {
        path_display = { "smart" },
        mappings = {
          i = {
            ["<C-k>"] = actions.move_selection_previous,
            ["<C-j>"] = actions.move_selection_next,
            ["<C-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
          },
        },
      },
      pickers = {
        find_files = { hidden = true, file_ignore_patterns = { "^.git/" } },
      },
      extensions = {
        ["ui-select"] = { require("telescope.themes").get_dropdown() },
      },
    })

    telescope.load_extension("fzf")
    telescope.load_extension("ui-select")
  end,
}
