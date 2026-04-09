local M = {}

local SOC_FILE = vim.fn.expand("~/.brain-soc.json")
local cache = { soc = nil, text = "🧠 --%", timestamp = 0 }
local CACHE_TTL = 60 * 15  -- seconds (refreshes automatically)

local function read_soc_file()
  local ok, file = pcall(vim.fn.readfile, SOC_FILE)
  if not ok or #file == 0 then
    cache.soc = nil
    cache.text = "🧠 ?%"
    return
  end

  local ok_json, data = pcall(vim.json.decode, table.concat(file, "\n"))
  if not ok_json or not data or not data.soc then
    cache.soc = nil
    cache.text = "🧠 ?%"
    return
  end

  cache.soc = tonumber(data.soc)
  cache.text = string.format("🧠 %d%%", math.floor(cache.soc))
  cache.timestamp = os.time()
end

-- Public API: call this from your statusline
function M.get_status()
  -- Refresh if cache is stale
  if os.time() - cache.timestamp > CACHE_TTL then
    read_soc_file()
  end
  return cache.text
end

-- Optional: command to force refresh
vim.api.nvim_create_user_command("BrainSOCRefresh", function()
  read_soc_file()
  vim.cmd("redrawstatus!")
  print("Brain SOC refreshed: " .. cache.text)
end, {})

-- Auto-refresh every 30 seconds in the background
vim.defer_fn(function()
  read_soc_file()
  vim.api.nvim_create_autocmd("CursorHold", {
    callback = function()
      if os.time() - cache.timestamp > CACHE_TTL then
        read_soc_file()
      end
    end,
  })
end, 1000)

vim.notify("🧠 Brain SOC plugin loaded", vim.log.levels.INFO)
return M
