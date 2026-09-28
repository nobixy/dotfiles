return {
  "lewis6991/gitsigns.nvim",
  event = { "BufReadPre", "BufNewFile" },
  opts = {
    on_attach = function(bufnr)
      local gs = require("gitsigns")

      local function map(mode, keys, action, desc)
        vim.keymap.set(mode, keys, action, { buffer = bufnr, desc = desc })
      end

      -- Navigation
      map("n", "]h", function()
        gs.nav_hunk("next")
      end, "Next git hunk")
      map("n", "[h", function()
        gs.nav_hunk("prev")
      end, "Previous git hunk")

      -- Actions
      map("n", "<leader>hs", gs.stage_hunk, "Stage/unstage hunk")
      map("n", "<leader>hr", gs.reset_hunk, "Reset hunk")
      map("v", "<leader>hs", function()
        gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
      end, "Stage selected lines")
      map("v", "<leader>hr", function()
        gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
      end, "Reset selected lines")
      map("n", "<leader>hS", gs.stage_buffer, "Stage buffer")
      map("n", "<leader>hR", gs.reset_buffer, "Reset buffer")
      map("n", "<leader>hp", gs.preview_hunk_inline, "Preview hunk")
      map("n", "<leader>hb", function()
        gs.blame_line({ full = true })
      end, "Blame line")
      map("n", "<leader>hd", gs.diffthis, "Diff against index")
      map("n", "<leader>hD", function()
        gs.diffthis("~")
      end, "Diff against last commit")

      -- Text object: select a hunk with ih
      map({ "o", "x" }, "ih", gs.select_hunk, "Select hunk")
    end,
  },
}
