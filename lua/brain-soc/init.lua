local M = {}

local config = require("brain-soc.config")
config.load()
local notify = require("brain-soc.notify")

local CONFIG_DIR = vim.fn.expand("~/.config/brain-soc")
local SOC_FILE = vim.fn.expand("~/.brain-soc.json")
local cache = { soc = nil, text = "🧠 --%", timestamp = 0 }
local CACHE_TTL = 60 -- seconds (refreshes automatically)

local last_modal = {
  critical = 0,  -- timestamp of last ≤10% modal
  warning = 0,   -- timestamp of last 11-20% modal
}
local CRITICAL_COOLDOWN = 300   -- 5 minutes in seconds
local WARNING_COOLDOWN = 900    -- 15 minutes in seconds

vim.api.nvim_create_user_command("BrainSOCConfig", function(opts)
  -- No arguments → show current config
  if #opts.fargs == 0 then
    notify.info("Current config:\n" .. vim.inspect(config.get()))
    return
  end

  local updates = {}
  for _, arg in ipairs(opts.fargs) do
    local eq_pos = arg:find("=")
    if eq_pos then
      local key = vim.trim(arg:sub(1, eq_pos - 1))
      local val_str = vim.trim(arg:sub(eq_pos + 1))
      local value
      if val_str == "true" then
        value = true
      elseif val_str == "false" then
        value = false
      elseif tonumber(val_str) then
        value = tonumber(val_str)
      end
      updates[key] = value
    else
      notify.warn("Invalid format. Use: key=value (e.g. drain_rate=1)")
    end
  end

  if next(updates) then
    M.update_config(updates)
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

local function should_show_modal(soc)
  if not soc or soc > 20 then
    return false
  end

  local now = os.time()
  local is_critical = soc <= 10

  if is_critical then
    if now - last_modal.critical >= CRITICAL_COOLDOWN then
      last_modal.critical = now
      return true
    end
  else
    if now - last_modal.warning >= WARNING_COOLDOWN then
      last_modal.warning = now
      return true
    end
  end

  return false
end

local function create_centered_warning(soc)
  local is_critical = soc <= 10
  local title = "The Brain SOC"
  local hl_group = is_critical and "DiagnosticError" or "DiagnosticWarn"  -- matches your lualine colors

  local lines = {
    "",
    string.format("      🧠 : %d%%      ", math.floor(soc + 0.5)),
    "",
    is_critical and "   Take a break or your brain breaks.   " or "   Consider a short break soon.   ",
    "",
    "   Press <Esc> or q to dismiss   ",
    ""
  }

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"

  local width = 52
  local height = #lines

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = "minimal",
    border = "rounded",
    title = title,
    title_pos = "center",
    zindex = 250,
  })

  -- Color the modal
  vim.wo[win].winhighlight = "Normal:NormalFloat,FloatBorder:" .. hl_group

  -- Close helpers
  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  vim.keymap.set("n", "<Esc>", close, { buffer = buf, silent = true, nowait = true })
  vim.keymap.set("n", "q", close, { buffer = buf, silent = true, nowait = true })

  -- Yellow warnings auto-dismiss after 8 seconds (red stays until manually closed)
  if not is_critical then
    vim.defer_fn(close, 8000)
  end

  return win
end

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

  -- Automatic centered warning modal
  if should_show_modal(cache.soc) then
    create_centered_warning(cache.soc)
  end
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

function M.update_config(updates)
  local new_config = config.merge(updates)
  notify.info("Config(s) updated:\n" .. vim.inspect(new_config))
  -- TODO: rerender SOC % after updating config?
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
        "",
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

function M.lualine_component()
  return {
    M.get_status,
    cond = function()
      return vim.fn.filereadable(SOC_FILE) == 1
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
