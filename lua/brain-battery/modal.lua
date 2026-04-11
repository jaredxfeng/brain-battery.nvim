local M = {}

local last_modal = {
  critical = 0, -- timestamp of last ≤10% modal
  warning = 0, -- timestamp of last 11-20% modal
}
local CRITICAL_COOLDOWN = 300 -- 5 minutes
local WARNING_COOLDOWN = 900 -- 15 minutes

-- State for the forced rest modal (SOC == 0)
local forced_rest = {
  modal_win = nil,
  dim_win = nil,
}

local function close_forced_rest()
  if forced_rest.modal_win and vim.api.nvim_win_is_valid(forced_rest.modal_win) then
    pcall(vim.api.nvim_win_close, forced_rest.modal_win, true)
  end
  if forced_rest.dim_win and vim.api.nvim_win_is_valid(forced_rest.dim_win) then
    pcall(vim.api.nvim_win_close, forced_rest.dim_win, true)
  end
  forced_rest.modal_win = nil
  forced_rest.dim_win = nil
end

local function create_dimmer()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"

  local win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    width = vim.o.columns,
    height = vim.o.lines,
    col = 0,
    row = 0,
    style = "minimal",
    zindex = 240,
  })

  -- Even stronger dim effect
  vim.wo[win].winblend = 65
  vim.wo[win].winhighlight = "Normal:NormalFloat"

  return win
end

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
  local title = " The Brain Battery "
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

-- The big ASCII art from ascii.txt (exactly as provided)
local ascii_art = {
  "                 uuuuuuu",
  "             uu$$$$$$$$$$$uu",
  "          uu$$$$$$$$$$$$$$$$$uu",
  "         u$$$$$$$$$$$$$$$$$$$$$u",
  "        u$$$$$$$$$$$$$$$$$$$$$$$u",
  "       u$$$$$$$$$$$$$$$$$$$$$$$$$u",
  "       u$$$$$$$$$$$$$$$$$$$$$$$$$u",
  '       u$$$$$$"   "$$$"   "$$$$$$u',
  '       "$$$$"      u$u       $$$$"',
  "        $$$u       u$u       u$$$",
  "        $$$u      u$$$u      u$$$",
  '         "$$$$uu$$$   $$$uu$$$$"',
  '          "$$$$$$$"   "$$$$$$$"',
  "            u$$$$$$$u$$$$$$$u",
  '             u$"$"$"$"$"$"$"$u',
  "  uuu        $$u$ $ $ $ $u$$       uuu",
  " u$$$$        $$$$$u$u$u$$$       u$$$$",
  '  $$$$$uu      "$$$$$$$$$"     uu$$$$$$',
  'u$$$$$$$$$$$uu    """""    uuuu$$$$$$$$$$',
  '$$$$"""$$$$$$$$$$uuu   uu$$$$$$$$$"""$$$"',
  ' """      ""$$$$$$$$$$$uu ""$"""',
  '           uuuu ""$$$$$$$$$$uuu',
  '  u$$$uuu$$$$$$$$$uu ""$$$$$$$$$$$uuu$$$',
  '  $$$$$$$$$$""""           ""$$$$$$$$$$$"',
  '   "$$$$$"                      ""$$$$""',
  '     $$$"                         $$$$"',
}

local function create_forced_rest_modal(soc)
  -- Clean up any previous forced modal first
  close_forced_rest()

  -- Stronger full-screen dimmer
  local dim_win = create_dimmer()

  local title = " ⚠️  FORCED REST — BRAIN SOC AT 0%  ⚠️ "

  local lines = {
    "",
    "                   🚨   YOUR BRAIN IS AT 0%   🚨",
    "",
  }

  -- Insert the full ASCII art
  for _, line in ipairs(ascii_art) do
    table.insert(lines, line)
  end

  table.insert(lines, "")
  table.insert(lines, string.format("               State of Charge: %d%%               ", math.floor(soc + 0.5)))
  table.insert(lines, "")
  table.insert(lines, "   YOU MUST TAKE A BREAK RIGHT NOW.")
  table.insert(lines, "   Continuing to code will seriously damage your brain.")
  table.insert(lines, "")
  table.insert(lines, "   • Stand up and move around")
  table.insert(lines, "   • Drink water")
  table.insert(lines, "   • Look at something far away (20-20-20 rule)")
  table.insert(lines, "   • Rest your eyes and mind")
  table.insert(lines, "")
  table.insert(lines, "   This modal will disappear automatically")
  table.insert(lines, "   when your SOC recovers to 10% or higher.")
  table.insert(lines, "")
  table.insert(lines, "                ❤️   PROTECT YOUR BRAIN   ❤️")
  table.insert(lines, "")

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"

  -- Even larger modal (width 92 to comfortably fit the huge ASCII art)
  local width = 92
  local height = #lines

  local modal_win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = "minimal",
    border = "double",
    title = title,
    title_pos = "center",
    zindex = 300,
  })

  vim.wo[modal_win].winhighlight = "Normal:NormalFloat,FloatBorder:DiagnosticError"
  vim.wo[modal_win].winblend = 0 -- solid, no transparency on the modal itself

  forced_rest.modal_win = modal_win
  forced_rest.dim_win = dim_win

  -- NO keymaps → completely forced (user cannot dismiss manually)
end

function M.show_if_needed(soc)
  -- Forced rest modal has absolute priority
  if forced_rest.modal_win then
    if soc and soc >= 10 then
      close_forced_rest()
    end
    return
  end

  -- SOC just dropped to zero → launch the huge forced modal
  if soc and soc <= 0 then
    create_forced_rest_modal(soc)
    return
  end

  -- Regular warning/critical behavior (unchanged)
  if should_show_modal(soc) then
    M.create_centered_warning(soc)
  end
end

-- Optional cleanup (call on plugin unload if desired)
function M.cleanup()
  close_forced_rest()
end

return M
