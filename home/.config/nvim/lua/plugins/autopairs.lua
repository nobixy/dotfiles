-- Auto-close brackets and quotes while typing (blink.cmp adds the brackets
-- after accepting a function completion on its own)
return {
  "windwp/nvim-autopairs",
  event = "InsertEnter",
  opts = {
    check_ts = true, -- use treesitter to skip strings etc.
    ts_config = {
      lua = { "string" },
      javascript = { "template_string" },
    },
  },
}
