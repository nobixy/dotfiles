-- Neovim 0.12+ config. Layout:
--   lua/config/options.lua    editor settings (leader keys live here)
--   lua/config/keymaps.lua    plugin-independent keymaps
--   lua/config/autocmds.lua   small quality-of-life autocommands
--   lua/config/languages.lua  ONE place to add a language (parsers, LSP, formatters)
--   lua/config/lazy.lua       plugin manager bootstrap
--   lua/plugins/*.lua         one plugin per file, picked up automatically

require("config.options")
require("config.keymaps")
require("config.autocmds")
require("config.lazy")
