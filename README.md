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
  lazy = false,
  config = function(_, opts)
    require("brain-soc")._opts = opts,
  end,
  opts = {
    CAPACITY_MINUTES = 300,
    DRAIN_RATE = 1.1,
    CODING_THRESHOLD_MINUTES = 2,
    RECHARGE_MINUTES_PER_BREAK = 25,
  },
}
```

2. In your neovim, run `:BrainSOCSetup` to input your wakatime API key and the Slack OAuth Token of The Brain SOC Slack App.

3. Add a line inside your `crontab -e`: `*/15 * * * * cd ~/.local/share/nvim/lazy/brain-soc.nvim/bin && ./run-brain-soc.sh`. Save and exit.

4. Restart your neovim and continue to enjoy coding until it stops you!

## Parameters in `opts`

`CAPACITY_MINUTES` - total capacity of your brain battery in minutes.

`DRAIN_RATE` - multiplier to the minutes cumulated from wakatime. The multiplied result is then added to the current fatigue.

`CODING_THRESHOLD_MINUTES` - if the coding minutes in the last 15 minute interval are less than this, then The Brain SOC sees this interval as "charging" or break.

`RECHARGE_MINUTES_PER_BREAK` - the minutes that will be subtracted from your fatigue during a break.

The current SOC then is just the difference between the capacity and the current fatigue in minutes.

## Commands

`:BrainSOCSetup` - see above.
