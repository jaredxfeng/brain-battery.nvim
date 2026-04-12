# brain-battery.nvim

**Real-time "brain battery" estimator for your Neovim statusline**  
Powered by WakaTime + a 15-minute cron job that updates your Slack status too.

## Features

- Periodically estimates your coding fatigue level from wakatime data.
- Shows `🧠 87%` in your lualine.
- Pops up modals that remind, convince, and later force you to have a break.
- Protects your manual Slack status (won't overwrite if you set a different emoji)

## Installation

1. Create a file `~/.config/nvim/lua/plugins/brain-battery.lua` with these lines:

```lua
return {
  "jaredxfeng/brain-battery.nvim",
  dependencies = {
    { "nvim-lualine/lualine.nvim", optional = true },
  },
  event = "VeryLazy",
  config = function(_, opts)
    require("brain-battery")._opts = opts
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
  dependencies = { "jaredxfeng/brain-battery.nvim" },  -- ← this ensures correct load order
  event = "VeryLazy",
  opts = function(_, opts)
    opts.sections = opts.sections or {}
    opts.sections.lualine_x = vim.list_extend(
      opts.sections.lualine_x or {},
      { require("brain-battery").lualine_component() }  -- ← this was the missing piece
    )
    return opts
  end,
}

```

3. In your neovim, run `:BrainBatterySetup` to input your wakatime API key and the Slack OAuth Token of The Brain SOC Slack App.

4. Add a line inside your `crontab -e`: `*/15 * * * * cd ~/.local/share/nvim/lazy/brain-battery.nvim/bin && ./run-brain-battery.sh`. Save and exit.

5. See `getEmoji()` in `brainBattery.ts`, this maps the current brain SOC to a battery emoji that you should also manually upload to your slack workspace.

And you are done. Restart your neovim and continue to enjoy coding until it stops you!

## Parameters in `opts`

`capacity_minutes` - total capacity of your brain battery in minutes.

`drain_rate` - multiplier to the minutes cumulated from wakatime. The multiplied result is then added to the current fatigue.

`coding_threshold_minutes` - if the coding minutes in the last 15 minute interval are less than this, then The Brain SOC sees this interval as "charging" or break.

`recharge_minutes_per_break` - the minutes that will be subtracted from your fatigue during a break.

The current SOC then is just the difference between the capacity and the current fatigue in minutes.

## Commands

`:BrainBatterySetup` - see above.

`:BrainBatteryConfig capacity_minutes=400 drain_rate=1.2` - overwrite default config.
