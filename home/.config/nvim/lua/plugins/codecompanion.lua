-- CodeCompanion: pair programming with your local guy (Ollama, ~/.local/bin/guy).
-- <leader>g mirrors ALT+A in Hyprland. Chat and inline edits use qwen3.5:4b
-- (fast, fits the GPU, thinking off); <leader>gs opens a chat on the slower,
-- smarter 9b with thinking on.

local function guy(...)
  local cmd = { vim.fn.expand("~/.local/bin/guy"), ... }
  return function() vim.system(cmd, { detach = true }) end
end

return {
  "olimorris/codecompanion.nvim",
  dependencies = { "nvim-lua/plenary.nvim", "nvim-treesitter/nvim-treesitter" },
  cmd = { "CodeCompanion", "CodeCompanionChat", "CodeCompanionActions", "CodeCompanionCmd" },
  keys = {
    { "<leader>gg", "<cmd>CodeCompanionChat Toggle<cr>", mode = { "n", "v" }, desc = "Chat with your guy" },
    { "<leader>gs", "<cmd>CodeCompanionChat adapter=ollama_think<cr>", desc = "Chat, think harder (9b)" },
    { "<leader>ga", "<cmd>CodeCompanionChat Add<cr>", mode = "v", desc = "Add selection to chat" },
    { "<leader>gi", ":CodeCompanion ", mode = { "n", "v" }, desc = "Inline edit (type a prompt)" },
    { "<leader>gp", "<cmd>CodeCompanionActions<cr>", mode = { "n", "v" }, desc = "Action palette" },
    { "<leader>gt", guy("today"), desc = "Today: desk time summary" },
  },
  opts = {
    adapters = {
      http = {
        ollama = function()
          return require("codecompanion.adapters").extend("ollama", {
            schema = { model = { default = "qwen3.5:4b" }, think = { default = false } },
          })
        end,
        ollama_think = function()
          return require("codecompanion.adapters").extend("ollama", {
            name = "ollama_think",
            schema = { model = { default = "qwen3.5:9b" }, think = { default = true } },
          })
        end,
      },
    },
    interactions = {
      chat = { adapter = "ollama" },
      inline = { adapter = "ollama" },
      cmd = { adapter = "ollama" },
      background = { adapter = "ollama" },
    },
  },
}
