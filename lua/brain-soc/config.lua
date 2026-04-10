local M = {}

local CONFIG_DIR = vim.fn.expand("~/.config/brain-soc")
local CONFIG_FILE = CONFIG_DIR .. "/config.json"

M.keys = {
  "capacity_minutes",
  "drain_rate",
  "coding_threshold_minutes",
  "recharge_minutes_per_break",
}

M.defaults = {
  capacity_minutes = 300,
  drain_rate = 1.1,
  coding_threshold_minutes = 3,
  recharge_minutes_per_break = 25,
}

M.options = vim.deepcopy(M.defaults)

-- Build lookup table once (no duplication)
local allowed = {}
for _, k in ipairs(M.keys) do
  allowed[k] = true
end

-- Snake_case → camelCase mapping for your backend
local backend_mapping = {
  capacity_minutes          = "capacityMinutes",
  drain_rate                = "drainRate",
  coding_threshold_minutes  = "codingThresholdMinutes",
  recharge_minutes_per_break = "rechargeMinutesPerBreak",
}

local function ensure_dir()
  vim.fn.mkdir(CONFIG_DIR, "p")
end

local function to_backend_format(opts)
  local backend = {}
  for _, key in ipairs(M.keys) do
    local camel_key = backend_mapping[key]
    backend[camel_key] = opts[key]
  end
  return backend
end

-- Merge new values and save to disk
function M.merge(new_opts)
  if type(new_opts) ~= "table" then
    vim.notify("BrainSOC: config.merge expects a table", vim.log.levels.ERROR)
    return
  end

  for k, v in pairs(new_opts) do
    if allowed[k] then
      M.options[k] = v
    else
      vim.notify("BrainSOC: Unknown config key " .. k, vim.log.levels.WARN)
    end
  end

  M.save()
end

-- Load saved config from disk. Called once at startup
function M.load()
  if vim.fn.filereadable(CONFIG_FILE) == 0 then
    return
  end

  local content = vim.fn.readfile(CONFIG_FILE)
  local ok, backend_config = pcall(vim.json.decode, table.concat(content, ""))
  if not ok or not backend_config then
    return
  end

  -- Convert camelCase back to snake_case (retire after lua rewrite of TS backend)
  for _, key in ipairs(M.keys) do
    local camel_key = backend_mapping[key]
    if backend_config[camel_key] ~= nil then
      M.options[key] = backend_config[camel_key]
    end
  end
end

-- Public getter
function M.get()
  return vim.deepcopy(M.options)
end

-- Save to disk
function M.save()
  ensure_dir()
  local backend_config = to_backend_format(M.options)

  local ok, err = pcall(function()
    vim.fn.writefile({ vim.json.encode(backend_config) }, CONFIG_FILE)
  end)

  if not ok then
    vim.notify("BrainSOC: failed to save config - " .. (err or "unknown error"), vim.log.levels.ERROR)
  end
end

return M
