# brain-soc.nvim

**Real-time "Brain SOC" (battery) for your Neovim statusline**  
Powered by WakaTime + a 15-minute cron job that updates your Slack status too.

## Features
- Shows `🧠 87%` in your lualine (or any statusline)
- Protects your manual Slack status (won't overwrite if you set a different emoji)
- Fully local — only reads `~/.brain-soc.json`

## Installation

### 1. Install the Neovim plugin (LazyVim)

Create a file `~/.config/nvim/lua/plugins/brain-soc.lua` with these lines:

```lua
return {
  "jaredxfeng/brain-soc.nvim",   -- ← change to your repo
  lazy = false,
  config = function() end,
}
```

## Commands

`:BrainSOCRefresh` — force update the statusline.
