local M = {}

---@param msg string
---@param level? integer vim.log.levels.*
---@param opts? table
local function notify(msg, level, opts)
  opts = opts or {}
  opts.title = "The Brain SOC"
  vim.notify(msg, level, opts)
end

M.info = function(msg, opts)
  notify(msg, vim.log.levels.INFO, opts)
end
M.warn = function(msg, opts)
  notify(msg, vim.log.levels.WARN, opts)
end
M.error = function(msg, opts)
  notify(msg, vim.log.levels.ERROR, opts)
end

return M
