vim.g.mapleader = " "
vim.g.maplocalleader = "\\"
vim.g.have_nerd_font = true

-- No remote plugins in other languages; skips a ~40 ms Python probe when
-- opening .py files (LSP, formatting etc. don't need these)
vim.g.loaded_python3_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_node_provider = 0

local opt = vim.opt

opt.number = true
opt.relativenumber = true
opt.cursorline = true
opt.signcolumn = "yes"
opt.showmode = false -- lualine shows the mode
opt.termguicolors = true
opt.winborder = "rounded" -- borders on hover, diagnostics and other floats
opt.fillchars = { eob = " " } -- no ~ after the end of the buffer

opt.shiftwidth = 4
opt.tabstop = 4
opt.expandtab = true
opt.smartindent = true

opt.wrap = false
opt.scrolloff = 8
opt.sidescrolloff = 8

-- Treesitter folds (za toggles), but files open fully unfolded
opt.foldlevel = 99
opt.foldlevelstart = 99

opt.ignorecase = true
opt.smartcase = true
opt.inccommand = "split" -- live preview of :s substitutions

opt.splitbelow = true
opt.splitright = true

-- Show tabs and trailing spaces
opt.list = true
opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

opt.undofile = true -- undo history survives restarts (browse it with <leader>u)
opt.confirm = true -- ask instead of failing on :q with unsaved changes
opt.updatetime = 250
opt.timeoutlen = 300

-- System clipboard; set after startup since it can be slow to detect
vim.schedule(function()
  opt.clipboard = "unnamedplus"
end)
