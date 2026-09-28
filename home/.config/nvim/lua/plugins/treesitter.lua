-- nvim-treesitter `main` branch: installs parsers; Neovim itself does the
-- highlighting, folding and (via this plugin) indentation. Parsers to install
-- come from config/languages.lua. Opening any other filetype installs its
-- parser on the fly. Compiling parsers needs `tree-sitter` (tree-sitter-cli).
return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  lazy = false, -- doesn't support lazy-loading
  build = ":TSUpdate",
  config = function()
    local ts = require("nvim-treesitter")
    local can_install = vim.fn.executable("tree-sitter") == 1

    if can_install then
      ts.install(require("config.languages").parsers())
    end

    local available = {}
    for _, lang in ipairs(ts.get_available()) do
      available[lang] = true
    end

    local function attach(buf, lang)
      if not pcall(vim.treesitter.start, buf, lang) then
        return
      end
      vim.wo[0][0].foldexpr = "v:lua.vim.treesitter.foldexpr()"
      vim.wo[0][0].foldmethod = "expr"
      if vim.treesitter.query.get(lang, "indents") then
        vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end
    end

    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("user-treesitter", { clear = true }),
      callback = function(args)
        local lang = vim.treesitter.language.get_lang(args.match)
        if not lang then
          return
        end
        if vim.treesitter.language.add(lang) then
          attach(args.buf, lang)
        elseif can_install and available[lang] then
          ts.install(lang):await(function(err)
            if err then
              return
            end
            vim.schedule(function()
              if vim.api.nvim_buf_is_valid(args.buf) then
                attach(args.buf, lang)
              end
            end)
          end)
        end
      end,
    })
  end,
}
