-- Sizes a scratchpad window the first time it appears: centered on its screen
-- and smaller than it. AeroSpace floats these apps' windows and
-- aerospace-scratchpad shows and hides them (see ~/.aerospace.toml), but neither
-- can place a floating window. A window you move or resize afterwards stays put.
local M = {}

-- App names as Hammerspoon reports them. Keep in step with the scratchpad rules
-- in ~/.aerospace.toml.
local APPS = { "Ghostty", "kitty", "Zed", "neovide" }

-- Fractions of the screen's usable area.
local WIDTH = 0.70
local HEIGHT = 0.75

-- Width over height. On the ultrawide, WIDTH alone gives a window wider than the
-- laptop's whole screen, so the width is also capped by the window's shape.
local MAX_ASPECT = 1.6

-- AeroSpace floats the window from its own window-detected callback. Wait for
-- that, so the frame is set on a window that is already floating.
local SETTLE_SECONDS = 0.3

---The centered frame for a screen's usable area.
---@param area { x: number, y: number, w: number, h: number }
---@return { x: number, y: number, w: number, h: number }
function M.frameFor(area)
  local h = math.floor(area.h * HEIGHT)
  local w = math.floor(math.min(area.w * WIDTH, h * MAX_ASPECT))
  return {
    x = area.x + math.floor((area.w - w) / 2),
    y = area.y + math.floor((area.h - h) / 2),
    w = w,
    h = h,
  }
end

---@param win hs.window
local function place(win)
  -- The window can close during the wait, and dialogs keep their own size.
  if not win:isStandard() then
    return
  end
  local screen = win:screen()
  if screen then
    win:setFrame(M.frameFor(screen:frame()), 0)
  end
end

function M.start()
  -- Timers are kept here until they fire; an unreferenced one can be collected first.
  M.pending = {}
  -- Kept on the module so the filter isn't collected.
  M.filter = hs.window.filter.new(APPS)
  M.filter:subscribe(hs.window.filter.windowCreated, function(win)
    local id = win:id()
    if not id then
      return
    end
    M.pending[id] = hs.timer.doAfter(SETTLE_SECONDS, function()
      M.pending[id] = nil
      place(win)
    end)
  end)
end

return M
