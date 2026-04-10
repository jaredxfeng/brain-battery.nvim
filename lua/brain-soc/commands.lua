local M = {}

local config = require("brain-soc.config")
local notify = require("brain-soc.notify")

local CONFIG_DIR = vim.fn.expand("~/.config/brain-soc")

function M.setup()
  vim.api.nvim_create_user_command("BrainSOCConfig", function(opts)
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
      require("brain-soc").update_config(updates)
    end
  end, {
    nargs = "*",
    desc = "Update BrainSOC configuration (key=value ...)",
    complete = function(arglead)
      local completions = {}
      for _, k in ipairs(config.keys or {}) do
        if k:find(arglead, 1, true) then
          table.insert(completions, k .. "=")
        end
      end
      return completions
    end,
  })

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
end

return M
