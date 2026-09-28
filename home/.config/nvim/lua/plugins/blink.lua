-- Completion: LSP, snippets (friendly-snippets via vim.snippet), paths, buffer
-- words and the Neovim Lua API (lazydev). Replaces nvim-cmp + LuaSnip + 5 sources.
return {
  "saghen/blink.cmp",
  version = "1.*", -- release tags ship a prebuilt Rust fuzzy matcher
  event = { "InsertEnter", "CmdlineEnter" },
  dependencies = { "rafamadriz/friendly-snippets" },
  ---@module 'blink.cmp'
  ---@type blink.cmp.Config
  opts = {
    -- Enter accepts only an item you've selected (C-j/C-k or C-n/C-p);
    -- otherwise it's a normal newline. Tab/S-Tab jump through snippets.
    keymap = {
      preset = "enter",
      ["<C-j>"] = { "select_next", "fallback" },
      ["<C-k>"] = { "select_prev", "fallback" },
    },
    completion = {
      list = { selection = { preselect = false, auto_insert = true } },
      documentation = { auto_show = true, auto_show_delay_ms = 250 },
    },
    signature = { enabled = true },
    sources = {
      default = { "lazydev", "lsp", "path", "snippets", "buffer" },
      providers = {
        lazydev = { name = "LazyDev", module = "lazydev.integrations.blink", score_offset = 100 },
      },
    },
    fuzzy = { implementation = "prefer_rust_with_warning" },
  },
  opts_extend = { "sources.default" },
}
