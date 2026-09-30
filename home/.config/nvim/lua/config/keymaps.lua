-- Plugin-independent keymaps. Plugin keymaps live in their plugin file, LSP
-- keymaps in plugins/lsp.lua. Press <leader> and wait to see them all.
local map = vim.keymap.set

map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlights" })
map("n", "<leader>nh", "<cmd>nohlsearch<CR>", { desc = "Clear search highlights" })

-- Windows
map("n", "<leader>sv", "<C-w>v", { desc = "Split window vertically" })
map("n", "<leader>sh", "<C-w>s", { desc = "Split window horizontally" })
map("n", "<leader>se", "<C-w>=", { desc = "Make splits equal size" })
map("n", "<leader>sx", "<cmd>close<CR>", { desc = "Close current split" })

-- Move selected lines up/down
map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down", silent = true })
map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up", silent = true })

-- Keep the cursor centred when jumping half pages and through search results
map("n", "<C-d>", "<C-d>zz", { desc = "Half page down" })
map("n", "<C-u>", "<C-u>zz", { desc = "Half page up" })
map("n", "n", "nzzzv", { desc = "Next match" })
map("n", "N", "Nzzzv", { desc = "Previous match" })

-- Paste over a selection without losing what you yanked
map("x", "<leader>p", [["_dP]], { desc = "Paste without yanking" })

-- Built-in undo tree (Nvim 0.12), loaded on first use
map("n", "<leader>u", function()
  vim.cmd.packadd("nvim.undotree")
  require("undotree").open()
end, { desc = "Undo tree" })

-- Study, mirroring ALT+I in Hyprland (~/.local/bin/eecs and eecs-agent).
-- Notes open in this Neovim; the agents run in the background and answer
-- with a notification.
local bin = vim.fn.expand("~/.local/bin/")

local function study_note(thing)
  return function()
    local paths = vim.fn.systemlist({ bin .. "eecs", "path", thing })
    if vim.v.shell_error ~= 0 or #paths == 0 then
      vim.notify("eecs path " .. thing .. " found nothing", vim.log.levels.WARN)
      return
    end
    local function edit(path)
      if path then vim.cmd.edit(vim.fn.fnameescape(path)) end
    end
    if #paths == 1 then
      return edit(paths[1])
    end
    vim.ui.select(paths, {
      prompt = "Open",
      format_item = function(path) return vim.fn.fnamemodify(path, ":t:r") end,
    }, edit)
  end
end

local function study_run(...)
  local cmd = { ... }
  cmd[1] = bin .. cmd[1]
  return function() vim.system(cmd, { detach = true }) end
end

map("n", "<leader>il", study_note("log"), { desc = "Today's log" })
map("n", "<leader>in", study_note("block"), { desc = "Current block note" })
map("n", "<leader>id", study_note("dashboard"), { desc = "Dashboard" })
map("n", "<leader>ik", study_note("checklist"), { desc = "Degree checklist" })
map("n", "<leader>ib", study_run("eecs", "open", "bench"), { desc = "Study Bench (Chrome)" })
map("n", "<leader>ir", study_run("eecs-record", "toggle"), { desc = "Record study session (OBS)" })
map("n", "<leader>iu", study_run("eecs-record", "upload"), { desc = "Upload a recording to YouTube" })
map("n", "<leader>ip", study_run("eecs-agent", "plan"), { desc = "Plan my day" })
map("n", "<leader>iw", study_run("eecs-agent", "shifts"), { desc = "Sync work shifts" })
map("n", "<leader>ii", study_run("eecs-agent", "shifts-paste"), { desc = "Type in shifts" })
map("n", "<leader>ic", study_run("eecs-agent", "coach"), { desc = "Coach: rebuild the week" })
map("n", "<leader>ia", study_run("eecs-agent", "menu"), { desc = "All agents" })
