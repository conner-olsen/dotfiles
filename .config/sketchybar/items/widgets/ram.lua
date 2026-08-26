local icons = require("icons")
local colors = require("colors")
local settings = require("settings")

-- Execute the event provider binary which provides the event "memory_update"
-- for the memory usage data, which is fired every 2.0 seconds.
sbar.exec("killall memory_load >/dev/null; $CONFIG_DIR/helpers/event_providers/memory_load/bin/memory_load memory_update 2.0")

local ram = sbar.add("graph", "widgets.ram", 56, {
  position = "right",
  graph = { color = colors.blue },
  background = {
    height = 22,
    color = { alpha = 0 },
    border_color = { alpha = 0 },
    drawing = true,
  },
  icon = { string = icons.ram },
  label = {
    string = "??/??GB",
    font = {
      family = settings.font.numbers,
      style = settings.font.style_map["Bold"],
      size = 9.0,
    },
    align = "right",
    padding_right = 0,
    width = 0,
    y_offset = 4
  },
  padding_right = settings.paddings + 6
})

ram:subscribe("memory_update", function(env)
  local used = tonumber(env.used_percent)
  ram:push({ used / 100. })

  local color = colors.blue
  if used > 60 then
    if used < 75 then
      color = colors.yellow
    elseif used < 85 then
      color = colors.orange
    else
      color = colors.red
    end
  end

  ram:set({
    graph = { color = color },
    label = env.used_gb .. "/" .. env.total_gb .. "GB",
  })
end)

ram:subscribe("mouse.clicked", function(env)
  sbar.exec("open -a 'Activity Monitor'")
end)

-- Background around the ram item
sbar.add("bracket", "widgets.ram.bracket", { ram.name }, {
  background = { color = colors.bg1 }
})

-- Padding after the ram item
sbar.add("item", "widgets.ram.padding", {
  position = "right",
  width = settings.group_paddings
})
