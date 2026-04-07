require("hs.ipc")
local overview = require("aerospace-overview")

hs.hotkey.bind({ "ctrl", "alt", "cmd" }, "space", function()
  overview.toggle()
end)
