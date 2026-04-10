local M = {}

local config = require("brain-soc.config")
local notify = require("brain-soc.notify")

local CONFIG_DIR = vim.fn.expand("~/.config/brain-soc")
local SOC_FILE = vim.fn.expand("~/.brain-soc.json")
local cache = { soc = nil, text = "🧠 --%", timestamp = 0 }
local CACHE_TTL = 60 -- seconds (refreshes automatically)

vim.api.nvim_create_user_command("BrainSOCConfig", function(opts)
  -- No arguments → show current config
  if #opts.fargs == 0 then
    notify.info("Current config:\n" .. vim.inspect(config))
    return
  end

  local updates = {}
  for _, arg in ipairs(opts.fargs) do
    local key, val_str = arg:match("^(%w+)=(.+)$")
    if key and val_str then
      local value = val_str
      if val_str == "true" then
        value = true
      elseif val_str == "false" then
        value = false
      elseif tonumber(val_str) then
        value = tonumber(val_str)
      end
      updates[key] = value
    else
      notify.warn("Invalid format. Use: key=value (e.g. param_one=newval)")
    end
  end

  if next(updates) then
    M.update_config(updates) -- or M.update_config if inside the module
  end
end, {
  nargs = "*",
  desc = "Update BrainSOC configuration (key=value ...)",
  complete = function(arglead)
    local completions = {}
    for _, k in ipairs(config.keys) do
      if k:find(arglead, 1, true) then
        table.insert(completions, k .. "=")
      end
    end
    return completions
  end,
})

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
end

function M.get_status()
  if os.time() - cache.timestamp > CACHE_TTL then
    local ok = pcall(readSocFile)
    if not ok then
      cache.text = "🧠 ERR"
    end
  end
  return cache.text
end

function M.update_config(updates)
  config.merge(updates)
  notify.info("Config(s) updated.")
  -- TODO: rerender SOC %?
end

vim.api.nvim_create_user_command("BrainSOCSetup", function()
  vim.ui.input({ prompt = "WakaTime API Key: " }, function(wakatime_token)
    if not wakatime_token or wakatime_token == "" then
      notify.warn("Setup cancelled")
      return
    end

    vim.ui.input({ prompt = "Slack Token (xoxp- or xoxb-): " }, function(slack_token)
      if not slack_token or slack_token == "" then
        notify.warn("Setup cancelled")
        return
      end

      vim.fn.mkdir(CONFIG_DIR, "p")

      local env_lines = {
        "WAKATIME_API_KEY=" .. wakatime_token,
        "SLACK_TOKEN=" .. slack_token,
        "", -- trailing empty line (good practice for .env files)
      }
      vim.fn.writefile(env_lines, CONFIG_DIR .. "/.env")

      notify.info(".env and config created in ~/.config/brain-soc/")
      notify.info(
        "Add this line to your crontab (crontab -e):\n*/15 * * * * cd ~/.local/share/nvim/lazy/TheBrainSOC/bin && ./run-brain-soc.sh"
      )
    end)
  end)
end, {
  nargs = "*",
  desc = "Setup The Brain SOC with secrets",
})

vim.defer_fn(function()
  local ok, err = pcall(readSocFile)
  if not ok then
    notify.warn("BrainSOC init error: " .. tostring(err))
  end

  vim.api.nvim_create_autocmd("CursorHold", {
    callback = function()
      if os.time() - cache.timestamp > CACHE_TTL then
        pcall(readSocFile)
      end
    end,
  })
end, 1000)

return M
