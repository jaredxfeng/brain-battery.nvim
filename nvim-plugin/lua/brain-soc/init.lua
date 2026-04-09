-- Auto-load the plugin when Neovim starts
if vim.g.loaded_brain_soc then
  return
end
vim.g.loaded_brain_soc = true

require("brain-soc")
