local M = {}

local modal = require("brain-battery.modal")

local SOC_FILE = vim.fn.expand("~/.brain-battery.json")
local cache = { soc = nil, text = "🧠 --%", timestamp = 0 }
local CACHE_TTL = 60 -- seconds

local function readSocFile()
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
  local raw_text = string.format("🧠 %d%%", math.floor(cache.soc + 0.5))
  cache.text = raw_text:gsub("%%", "%%%%")
  cache.timestamp = os.time()

  modal.show_if_needed(cache.soc)
end

local function ensure_fresh_cache()
  if os.time() - cache.timestamp > CACHE_TTL then
    pcall(readSocFile)
  end
end

function M.get_soc()
  ensure_fresh_cache()
  return cache.soc
end

function M.get_status()
  ensure_fresh_cache()
  return cache.text
end

function M.init()
  pcall(readSocFile)
end

return M
