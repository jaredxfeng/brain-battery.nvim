local M = {}

local last_modal = {
  critical = 0, -- timestamp of last ≤10% modal
  warning = 0,  -- timestamp of last 11-20% modal
}
local CRITICAL_COOLDOWN = 300 -- 5 minutes
local WARNING_COOLDOWN = 900  -- 15 minutes

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

function M.create_centered_warning(soc)
  local is_critical = soc <= 10
  local title = " The Brain SOC "
  local hl_group = is_critical and "DiagnosticError" or "DiagnosticWarn"

  local lines = {
    "",
    string.format("   🧠 state of charge: %d%%      ", math.floor(soc + 0.5)),
    "",
    is_critical and "   Take a break or your brain breaks.   " or "   Consider a short break soon.   ",
    "",
    "   Press <Esc> or q to dismiss   ",
    "",
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

  vim.wo[win].winhighlight = "Normal:NormalFloat,FloatBorder:" .. hl_group

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  vim.keymap.set("n", "<Esc>", close, { buffer = buf, silent = true, nowait = true })
  vim.keymap.set("n", "q", close, { buffer = buf, silent = true, nowait = true })

  if not is_critical then
    vim.defer_fn(close, 8000)
  end

  return win
end

function M.show_if_needed(soc)
  if should_show_modal(soc) then
    M.create_centered_warning(soc)
  end
end

return M
