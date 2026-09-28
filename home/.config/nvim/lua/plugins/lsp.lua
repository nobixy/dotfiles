-- LSP on Neovim's own API (vim.lsp.config / vim.lsp.enable). Servers and their
-- settings come from config/languages.lua; nvim-lspconfig only supplies the
-- default configs (cmd, filetypes, root markers) for each server.
--
-- Built-in keymaps (no setup needed):
--   K hover · grn rename · gra code action · grr references · gri implementation
--   grt type definition · gO document symbols · [d ]d diagnostics · <C-s> signature help (insert)
--   v_an / v_in expand/shrink selection
return {
  "neovim/nvim-lspconfig",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = {
    { "mason-org/mason.nvim", cmd = "Mason", opts = {} },
    "mason-org/mason-lspconfig.nvim",
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    -- Loaded first so its completion capabilities reach every server
    "saghen/blink.cmp",
  },
  config = function()
    local languages = require("config.languages")

    vim.diagnostic.config({
      severity_sort = true,
      virtual_text = { spacing = 2, source = "if_many" },
      float = { source = "if_many" },
      signs = {
        text = { -- Nerd Font icons as escapes, so no tool can mangle them
          [vim.diagnostic.severity.ERROR] = "\u{f0159} ",
          [vim.diagnostic.severity.WARN] = "\u{f0026} ",
          [vim.diagnostic.severity.INFO] = "\u{f02fc} ",
          [vim.diagnostic.severity.HINT] = "\u{f0335} ",
        },
      },
    })

    for name, config in pairs(languages.servers()) do
      vim.lsp.config(name, config)
    end

    -- Installs the servers and enables every Mason-installed one, except
    -- `tools` that also happen to have an LSP mode (e.g. stylua)
    local mason_lspconfig = require("mason-lspconfig")
    local to_server = mason_lspconfig.get_mappings().package_to_lspconfig
    local not_servers = {}
    for _, tool in ipairs(languages.tools()) do
      if to_server[tool] then
        table.insert(not_servers, to_server[tool])
      end
    end
    mason_lspconfig.setup({
      ensure_installed = languages.mason_servers(),
      automatic_enable = { exclude = not_servers },
    })
    require("mason-tool-installer").setup({
      ensure_installed = languages.tools(),
      start_delay = 3000, -- check after startup, not during it
    })
    -- Servers from the system (e.g. clangd) are enabled directly
    vim.lsp.enable(languages.system_servers())

    vim.api.nvim_create_autocmd("LspAttach", {
      group = vim.api.nvim_create_augroup("user-lsp-attach", { clear = true }),
      callback = function(event)
        local client = vim.lsp.get_client_by_id(event.data.client_id)

        local function map(keys, action, desc, mode)
          vim.keymap.set(mode or "n", keys, action, { buffer = event.buf, desc = desc })
        end

        map("gd", "<cmd>Telescope lsp_definitions<CR>", "Go to definition")
        map("gD", vim.lsp.buf.declaration, "Go to declaration")
        map("gR", "<cmd>Telescope lsp_references<CR>", "References (Telescope)")
        map("<leader>ca", vim.lsp.buf.code_action, "Code action", { "n", "v" })
        map("<leader>rn", vim.lsp.buf.rename, "Rename symbol")
        map("<leader>cd", vim.diagnostic.open_float, "Line diagnostics")
        map("<leader>cD", "<cmd>Telescope diagnostics bufnr=0<CR>", "Buffer diagnostics")
        map("<leader>rs", "<cmd>lsp restart<CR>", "Restart LSP")

        if client and client:supports_method("textDocument/inlayHint") then
          map("<leader>th", function()
            vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = event.buf }), { bufnr = event.buf })
          end, "Toggle inlay hints")
        end

        -- basedpyright answers hover for Python; ruff's is noise
        if client and client.name == "ruff" then
          client.server_capabilities.hoverProvider = false
        end
      end,
    })
  end,
}
