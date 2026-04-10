# brain-soc.nvim

**Real-time "Brain SOC" (battery) for your Neovim statusline**  
Powered by WakaTime + a 15-minute cron job that updates your Slack status too.

## Features

- Periodically estimates your coding fatigue level from wakatime data.
- Shows `🧠 87%` in your lualine (or any statusline)
- Protects your manual Slack status (won't overwrite if you set a different emoji)
- Fully local — only reads `~/.brain-soc.json`

## Installation

1. Create a file `~/.config/nvim/lua/plugins/brain-soc.lua` with these lines:

```lua
return {
  "jaredxfeng/brain-soc.nvim",
  dependencies = {
    { "nvim-lualine/lualine.nvim", optional = true },
  }
  lazy = false,
  config = function(_, opts)
    require("brain-soc")._opts = opts,
  end,
  opts = {
    capacity_minutes = 300,
    drain_rate = 1.1,
    coding_threshold_minutes = 2,
    recharge_minutes_per_break = 25,
  },
}
```

2. Create / edit the lualine config file `~/.config/nvim/lua/plugins/lualine.lua` with these lines:

```lua
return {
  "nvim-lualine/lualine.nvim",
  opts = function(_, opts)
    opts.sections = opts.sections or {}
    opts.sections.lualine_x = vim.list_extend(
      opts.sections.lualine_x or {},
      { require("brain-soc") }
    )
    return opts
  end,
}
```

3. In your neovim, run `:BrainSOCSetup` to input your wakatime API key and the Slack OAuth Token of The Brain SOC Slack App.

4. Add a line inside your `crontab -e`: `*/15 * * * * cd ~/.local/share/nvim/lazy/brain-soc.nvim/bin && ./run-brain-soc.sh`. Save and exit.

And you are done. Restart your neovim and continue to enjoy coding until it stops you!

## Parameters in `opts`

`capacity_minutes` - total capacity of your brain battery in minutes.

`drain_rate` - multiplier to the minutes cumulated from wakatime. The multiplied result is then added to the current fatigue.

`coding_threshold_minutes` - if the coding minutes in the last 15 minute interval are less than this, then The Brain SOC sees this interval as "charging" or break.

`recharge_minutes_per_break` - the minutes that will be subtracted from your fatigue during a break.

The current SOC then is just the difference between the capacity and the current fatigue in minutes.

## Commands

`:BrainSOCSetup` - see above.

`:BrainSOCConfig capacity_minutes=400 drain_rate=1.2` - overwrite default config.
