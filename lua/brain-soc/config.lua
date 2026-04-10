local M = {}

local CONFIG_DIR = vim.fn.expand("~/.config/brain-soc")
local CONFIG_FILE = CONFIG_DIR .. "/config.json"

M.defaults = {
  capacity_minutes = 300,
  drain_rate = 1.1,
  coding_threshold_minutes = 3,
  recharge_minutes_per_break = 25,
}

M.options = vim.deepcopy(M.defaults)

local function ensure_dir()
  vim.fn.mkdir(CONFIG_DIR, "p")
end

local function to_backend_format(opts)
  return {
    capacityMinutes = opts.capacity_minutes,
    drainRate = opts.drain_rate,
    codingThresholdMinutes = opts.coding_threshold_minutes,
    rechargeMinutesPerBreak = opts.recharge_minutes_per_break,
  }
end

-- Merge new values and save to disk
function M.merge(new_opts)
  if type(new_opts) ~= "table" then
    vim.notify("BrainSOC: update_config expects a table", vim.log.levels.ERROR)
    return
  end

  local allowed = {
    capacity_minutes = true,
    drain_rate = true,
    coding_threshold_minutes = true,
    recharging_minutes_in_break = true,
  }

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
  if backend_config.capacityMinutes ~= nil then
    M.options.capacity_minutes = backend_config.capacityMinutes
  end
  if backend_config.drainRate ~= nil then
    M.options.drain_rate = backend_config.drainRate
  end
  if backend_config.codingThresholdMintues ~= nil then
    M.options.coding_threshold_minutes = backend_config.codingThresholdMintues
  end
  if backend_config.rechargingMintuesInBreak ~= nil then
    M.options.recharge_minutes_per_break = backend_config.rechargeMintuesPerBreak
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
