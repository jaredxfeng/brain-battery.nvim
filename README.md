# brain-battery.nvim

**Real-time "brain battery" estimator for your Neovim statusline**  
Powered by WakaTime.

## Features

- Periodically estimates your coding fatigue level from wakatime data.
- Shows `🧠 87%` in your lualine.
- Shows `Brain: 87%` in your Slack status with a battery icon approximating the fill level.
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
  dependencies = { "jaredxfeng/brain-battery.nvim" },
  event = "VeryLazy",
  opts = function(_, opts)
    opts.sections = opts.sections or {}
    opts.sections.lualine_x = vim.list_extend(
      opts.sections.lualine_x or {},
      { require("brain-battery").lualine_component() }
    )
    return opts
  end,
}

```

3. In your neovim, run `:BrainBatterySetup` to input your wakatime API key and the Slack OAuth Token of a Slack app that you will separately create. For how to create such a Slack app, see the section **Slack App Creation**.

4. Add a line inside your `crontab -e`: `*/15 * * * * cd ~/.local/share/nvim/lazy/brain-battery.nvim/bin && ./run-brain-battery.sh`. Save and exit.

And you are done. Restart your neovim and enjoy coding until it stops you!

## Slack App Creation
1. Search for the "Your Apps" page on Slack web, click create new app -> from scratch -> name the app and select the workspace you want.
2. Once created, go to the app settings, find the OAuth & Permissions from the left menu.
3. Inside OAuth & Permissions, the "User OAuth Token" is the token you will input to `BrainBatterySetup`. Copy and save it.
4. Still in OAuth & Permissions, scroll down to find the User Token Scopes section. Click "Add an OAuth Scope". Find and enable `users:read`, `users.profile:write`, and `users.profile:read`. 
5. In your slack app itself (make sure you are in the target workspace), add emojis according to `getEmoji()` function in `brainBattery.ts`. You are now all set in Slack.
 
## Parameters in `opts`

`capacity_minutes` - total capacity of your brain battery in minutes.

`drain_rate` - multiplier to the minutes cumulated from wakatime. The multiplied result is then added to the current fatigue.

`coding_threshold_minutes` - if the coding minutes in the last 15 minute interval are less than this, then The Brain Battery sees this interval as "charging" or break.

`recharge_minutes_per_break` - the minutes that will be added to your current battery during a break.

The current SOC then is just the percentage remainder of capacity after subtracting the current fatigue in minutes.

## Commands

`:BrainBatterySetup` - see above.

`:BrainBatteryConfig capacity_minutes=400 drain_rate=1.2` - overwrite default config.
