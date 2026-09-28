-- Formatting. Formatters per filetype come from config/languages.lua.
-- Format on save is on except for languages that opt out (Markdown, C);
-- <leader>tf turns it off/on for the session.
return {
  "stevearc/conform.nvim",
  event = "BufWritePre",
  cmd = "ConformInfo",
  keys = {
    {
      "<leader>mp",
      function()
        require("conform").format({ async = true, lsp_format = "fallback" })
      end,
      mode = { "n", "v" },
      desc = "Format file or range",
    },
    {
      "<leader>tf",
      function()
        vim.g.disable_autoformat = not vim.g.disable_autoformat
        vim.notify("Format on save " .. (vim.g.disable_autoformat and "off" or "on"))
      end,
      desc = "Toggle format on save",
    },
  },
  opts = function()
    local languages = require("config.languages")
    local skip = languages.no_format_on_save()

    return {
      formatters_by_ft = languages.formatters(),
      format_on_save = function(bufnr)
        if vim.g.disable_autoformat or skip[vim.bo[bufnr].filetype] then
          return
        end
        return { timeout_ms = 1000, lsp_format = "fallback" }
      end,
    }
  end,
}
