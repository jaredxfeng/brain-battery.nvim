local M = {}

local config = require("brain-soc.config")
config.load()

local cache = require("brain-soc.cache")
local commands = require("brain-soc.commands")

commands.setup()

-- Initial read + CursorHold refresh
vim.defer_fn(function()
  cache.init()

  vim.api.nvim_create_autocmd("CursorHold", {
    callback = function()
      cache.get_status() -- triggers refresh + modal if needed
    end,
  })
end, 1000)

function M.get_soc()
  return cache.get_soc()
end

function M.get_status()
  return cache.get_status()
end

function M.update_config(updates)
  local new_config = config.merge(updates)
  require("brain-soc.notify").info("Config(s) updated:\n" .. vim.inspect(new_config))
  -- TODO: rerender SOC % after updating config?
end

function M.lualine_component()
  return {
    M.get_status,
    cond = function()
      return vim.fn.filereadable(vim.fn.expand("~/.brain-soc.json")) == 1
    end,
    color = function()
      local soc = M.get_soc()
      if not soc then
        return {}
      end

      if soc <= 10 then
        return { bg = "#5a0000", gui = "bold" }
      elseif soc <= 20 then
        return { bg = "#f1c40f", fg = "#1e1e1e", gui = "bold" }
      end

      return {}
    end,
  }
end

return M
