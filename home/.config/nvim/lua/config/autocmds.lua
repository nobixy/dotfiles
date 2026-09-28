local group = vim.api.nvim_create_augroup("user", { clear = true })
local autocmd = vim.api.nvim_create_autocmd

autocmd("TextYankPost", {
  group = group,
  desc = "Briefly highlight yanked text",
  callback = function()
    vim.hl.on_yank()
  end,
})

autocmd("BufReadPost", {
  group = group,
  desc = "Reopen files at the last cursor position",
  callback = function(args)
    local mark = vim.api.nvim_buf_get_mark(args.buf, '"')
    local lines = vim.api.nvim_buf_line_count(args.buf)
    if mark[1] > 0 and mark[1] <= lines and vim.bo[args.buf].filetype ~= "gitcommit" then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

autocmd("VimResized", {
  group = group,
  desc = "Keep splits equal when the terminal is resized",
  command = "tabdo wincmd =",
})

autocmd("FileType", {
  group = group,
  pattern = { "markdown", "text", "gitcommit" },
  desc = "Prose: soft-wrap at word boundaries and spellcheck",
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
    vim.opt_local.spell = true
  end,
})

autocmd("FileType", {
  group = group,
  pattern = { "help", "qf", "checkhealth", "man", "lspinfo" },
  desc = "Close utility windows with q",
  callback = function(args)
    vim.bo[args.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = args.buf, silent = true })
  end,
})
