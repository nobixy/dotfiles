-- Every language in one place. To add one, add an entry below; treesitter,
-- LSP, Mason and conform all read from this table.
--
--   parsers         treesitter parsers           (:h nvim-treesitter, SUPPORTED_LANGUAGES.md)
--   servers         LSP server name -> settings  (names: nvim-lspconfig's lsp/ directory)
--                   Mason installs them, unless `mason = false` (binary must be on PATH)
--   formatters      filetype -> conform formatters (:h conform-formatters)
--   tools           extra Mason packages, e.g. formatters and linters
--   format_on_save  false = only format with <leader>mp (applies to the
--                   `formatters` filetypes plus any listed in `filetypes`)

local M = {}

M.languages = {
  lua = {
    parsers = { "lua", "luadoc" },
    servers = {
      lua_ls = {
        settings = { Lua = { completion = { callSnippet = "Replace" } } },
      },
    },
    formatters = { lua = { "stylua" } },
    tools = { "stylua" },
  },

  python = {
    parsers = { "python" },
    servers = {
      -- Types and navigation; picks up a project's .venv automatically
      basedpyright = {
        settings = {
          basedpyright = {
            disableOrganizeImports = true, -- ruff does it
            analysis = { typeCheckingMode = "standard" },
          },
        },
      },
      -- Linting, import sorting and formatting. Same position encoding as
      -- basedpyright, so features using both clients agree on columns.
      ruff = { capabilities = { general = { positionEncodings = { "utf-16" } } } },
    },
    formatters = { python = { "ruff_organize_imports", "ruff_format" } },
    tools = { "debugpy" }, -- debugger (plugins/dap.lua)
  },

  markdown = {
    -- Also used for the Obsidian vault: never formatted, so notes aren't rewritten
    parsers = { "markdown", "markdown_inline" },
    servers = { marksman = {} },
    filetypes = { "markdown" },
    format_on_save = false,
  },

  web = {
    parsers = { "javascript", "typescript", "tsx", "html", "css", "json", "yaml" },
    servers = { ts_ls = {}, html = {}, cssls = {}, jsonls = {} },
    formatters = {
      javascript = { "prettier" },
      typescript = { "prettier" },
      javascriptreact = { "prettier" },
      typescriptreact = { "prettier" },
      html = { "prettier" },
      css = { "prettier" },
      json = { "prettier" },
      yaml = { "prettier" },
    },
    tools = { "prettier" },
  },

  c = {
    parsers = { "c", "cpp" },
    -- clangd and clang-format come with the system clang package
    servers = { clangd = { mason = false } },
    formatters = { c = { "clang_format" }, cpp = { "clang_format" } },
    format_on_save = false, -- don't restyle course/starter code on every save
  },

  shell = {
    parsers = { "bash" },
    servers = { bashls = {} },
    formatters = { sh = { "shfmt" }, bash = { "shfmt" } },
    tools = { "shfmt", "shellcheck" }, -- bashls lints with shellcheck
  },

  rust = {
    parsers = { "rust" },
    servers = {
      rust_analyzer = {
        mason = false,
        settings = {
          ["rust-analyzer"] = {
            check = { command = "clippy" },
          },
        },
      },
    },
    formatters = { rust = { "rustfmt" } },
  },

  go = {
    parsers = { "go", "gomod", "gosum" },
    servers = {
      gopls = {
        settings = {
          gopls = {
            analyses = { unusedparams = true },
            staticcheck = true,
            gofumpt = true,
          },
        },
      },
    },
    formatters = { go = { "gofumpt", "goimports" } },
    tools = { "gofumpt", "goimports", "delve" }, -- delve: debugger (plugins/dap.lua)
  },

  java = {
    parsers = { "java" },
    servers = { jdtls = {} },
  },

  assembly = {
    parsers = { "asm" },
    servers = { asm_lsp = {} },
  },

  verilog = {
    parsers = { "systemverilog", "vhdl" },
    servers = { verible = {} },
  },

  matlab = {
    parsers = { "matlab" },
  },

  latex = {
    parsers = { "latex", "bibtex" },
    servers = { texlab = {} },
    formatters = {
      tex = { "latexindent" },
      bib = { "bibtex-tidy" },
    },
    tools = { "bibtex-tidy" },
    format_on_save = false,
  },

  other = {
    parsers = { "vim", "vimdoc", "query", "regex", "diff", "gitcommit", "git_rebase", "toml" },
  },
}

---------------------------------------------------------------------------
-- Accessors used by plugins/treesitter.lua, plugins/lsp.lua, plugins/conform.lua

local function each(field, fn)
  for _, lang in pairs(M.languages) do
    if lang[field] then
      fn(lang[field], lang)
    end
  end
end

function M.parsers()
  local out = {}
  each("parsers", function(parsers)
    vim.list_extend(out, parsers)
  end)
  return out
end

--- name -> vim.lsp.Config (without the `mason` flag)
function M.servers()
  local out = {}
  each("servers", function(servers)
    for name, config in pairs(servers) do
      local copy = vim.deepcopy(config)
      copy.mason = nil
      out[name] = copy
    end
  end)
  return out
end

--- Servers Mason should install
function M.mason_servers()
  local out = {}
  each("servers", function(servers)
    for name, config in pairs(servers) do
      if config.mason ~= false then
        table.insert(out, name)
      end
    end
  end)
  return out
end

--- Servers that come from the system instead of Mason
function M.system_servers()
  local out = {}
  each("servers", function(servers)
    for name, config in pairs(servers) do
      if config.mason == false then
        table.insert(out, name)
      end
    end
  end)
  return out
end

function M.tools()
  local out = {}
  each("tools", function(tools)
    vim.list_extend(out, tools)
  end)
  return out
end

function M.formatters()
  local out = {}
  each("formatters", function(formatters)
    out = vim.tbl_extend("force", out, formatters)
  end)
  return out
end

--- Filetypes (set) whose language opted out of format-on-save
function M.no_format_on_save()
  local out = {}
  for _, lang in pairs(M.languages) do
    if lang.format_on_save == false then
      for ft in pairs(lang.formatters or {}) do
        out[ft] = true
      end
      for _, ft in ipairs(lang.filetypes or {}) do
        out[ft] = true
      end
    end
  end
  return out
end

return M
