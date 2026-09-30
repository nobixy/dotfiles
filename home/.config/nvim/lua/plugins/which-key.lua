-- Press <leader> (space) and wait: which-key lists everything under it
return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = {
    spec = {
      { "<leader>b", group = "buffer" },
      { "<leader>c", group = "code" },
      { "<leader>d", group = "debug" },
      { "<leader>e", group = "explorer" },
      { "<leader>f", group = "find" },
      { "<leader>h", group = "git hunk", mode = { "n", "v" } },
      { "<leader>i", group = "study" },
      { "<leader>m", group = "format" },
      { "<leader>n", group = "search" },
      { "<leader>p", group = "project" },
      { "<leader>r", group = "rename/restart" },
      { "<leader>s", group = "split" },
      { "<leader>t", group = "toggle" },
    },
  },
  keys = {
    {
      "<leader>?",
      function()
        require("which-key").show({ global = false })
      end,
      desc = "Keymaps for this buffer",
    },
  },
}
