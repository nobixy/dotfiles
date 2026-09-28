-- Harpoon: pin a few files and jump straight to them.
-- <C-h/j/k/l> are the QWERTY home row (the Harpoon README's <C-h/t/n/s> is
-- Dvorak). Ctrl+Shift combos are avoided because kitty captures them.

-- list("select", 1) -> function calling require("harpoon"):list():select(1)
local function list(method, arg)
  return function()
    local l = require("harpoon"):list()
    l[method](l, arg)
  end
end

local keys = {
  { "<leader>a", list("add"), desc = "Harpoon: add file" },
  { "<leader>[", list("prev"), desc = "Harpoon: previous file" },
  { "<leader>]", list("next"), desc = "Harpoon: next file" },
  {
    "<C-e>",
    function()
      local harpoon = require("harpoon")
      harpoon.ui:toggle_quick_menu(harpoon:list())
    end,
    desc = "Harpoon: menu",
  },
}
for i, key in ipairs({ "<C-h>", "<C-j>", "<C-k>", "<C-l>" }) do
  table.insert(keys, { key, list("select", i), desc = "Harpoon: file " .. i })
end

return {
  "ThePrimeagen/harpoon",
  branch = "harpoon2",
  dependencies = { "nvim-lua/plenary.nvim" },
  keys = keys,
  config = function()
    require("harpoon"):setup()
  end,
}
