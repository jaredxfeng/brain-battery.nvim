local M = {}

local CONFIG_DIR = vim.fn.expand("~/.config/brain-soc")
local CONFIG_FILE = CONFIG_DIR .. "/config.json"
local SOC_FILE = vim.fn.expand("~/.brain-soc.json")
local cache = { soc = nil, text = "🧠 SOC --%", timestamp = 0 }
local CACHE_TTL = 60 * 15  -- seconds (refreshes automatically)

local function read_soc_file()
  local ok, file = pcall(vim.fn.readfile, SOC_FILE)
  if not ok or #file == 0 then
    cache.soc = nil
    cache.text = "🧠 SOC ?%"
    return
  end

  local ok_json, data = pcall(vim.json.decode, table.concat(file, "\n"))
  if not ok_json or not data or not data.soc then
    cache.soc = nil
    cache.text = "🧠 SOC ?%"
    return
  end

  cache.soc = tonumber(data.soc)
  local rawtext = string.format("🧠 SOC %d%%", math.floor(cache.soc + 0.5))
  cache.text = rawtext:gsub("%%", "%%%%")
  cache.timestamp = os.time()
end

function M.get_status()
  if os.time() - cache.timestamp > CACHE_TTL then
    local ok = pcall(read_soc_file)
    if not ok then
      cache.text = "🧠 ERR"
    end
  end
  return cache.text
end

local function write_config(opts)
  vim.fn.mkdir(CONFIG_DIR, "p")
  local config = {
    capacityMinutes = opts.CAPACITY_MINUTES,
    drainRate = opts.DRAIN_RATE,
    codingThresholdMinutes = opts.CODING_THRESHOLD_MINUTES,
    rechargeMinutesPerBreak = opts.RECHARGE_MINUTES_PER_BREAK,
  }
  vim.fn.writefile({ vim.json.encode(config) }, CONFIG_FILE)
end

vim.api.nvim_create_user_command("BrainSOCSetup", function()
  vim.ui.input({ prompt = "WakaTime API Key: " }, function(wakatime_key)
    if not wakatime_key or wakatime_key == "" then
      vim.notify("Setup cancelled", vim.log.levels.WARN)
      return
    end

    vim.ui.input({ prompt = "Slack Token (xoxp- or xoxb-): " }, function(slack_token)
      if not slack_token or slack_token == "" then
        vim.notify("Setup cancelled", vim.log.levels.WARN)
        return
      end

      vim.fn.mkdir(CONFIG_DIR, "p")

      local env_lines = {
        "WAKATIME_API_KEY=" .. wakatime_key,
        "SLACK_TOKEN=" .. slack_token,
        ""  -- trailing empty line (good practice for .env files)
      }
      vim.fn.writefile(env_lines, CONFIG_DIR .. "/.env")

      vim.notify(".env and config created in ~/.config/brain-soc/", vim.log.levels.INFO)
      vim.notify("Add this line to your crontab (crontab -e):\n*/15 * * * * cd ~/.local/share/nvim/lazy/TheBrainSOC/bin && ./run-brain-soc.sh", vim.log.levels.INFO)
    end)
  end)
end, {})

vim.defer_fn(function()
  local opts = M._opts or {}
  write_config(opts)

  local ok, err = pcall(read_soc_file)
  if not ok then
    vim.notify("BrainSOC init error: " .. tostring(err), vim.log.levels.WARN)
  end

  vim.api.nvim_create_autocmd("CursorHold", {
    callback = function()
      if os.time() - cache.timestamp > CACHE_TTL then
        pcall(read_soc_file)
      end
    end,
  })
end, 1000)

vim.notify("🧠 Brain SOC plugin loaded", vim.log.levels.INFO)
return M
