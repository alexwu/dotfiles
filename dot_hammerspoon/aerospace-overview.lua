local M = {}

local AEROSPACE = "/opt/homebrew/bin/aerospace"

local config = {
  showEmptyWorkspaces = false,
  cols = 3,
  cellWidth = 220,
  cellHeight = 120,
  cellPadding = 12,
  iconSize = 32,
  iconPadding = 6,
  bgColor = { white = 0.1, alpha = 0.92 },
  cellColor = { white = 0.18, alpha = 1.0 },
  focusedCellColor = { red = 0.2, green = 0.4, blue = 0.8, alpha = 0.4 },
  textColor = { white = 0.9 },
  labels = {
    ["0"] = "Slack",
    ["1"] = "Main",
    ["2"] = "Notes",
    ["3"] = "Dev",
    ["4"] = "Comms",
    ["5"] = "Remote",
  },
}

local canvas = nil
local escapeHotkey = nil
local appWatcher = nil
local cellIndices = {}
local focusedWsId = nil

-- Run aerospace synchronously, return parsed JSON
local function aeroJSON(args)
  local cmd = AEROSPACE
  for _, a in ipairs(args) do
    cmd = cmd .. " " .. a
  end
  local handle = io.popen(cmd)
  if not handle then
    return nil
  end
  local output = handle:read("*a")
  handle:close()
  if not output or output == "" then
    return nil
  end
  return hs.json.decode(output)
end

-- Run aerospace async, fire-and-forget
local function aeroAsync(args)
  hs.task.new(AEROSPACE, function() end, args):start()
end

local function getWorkspaces()
  if config.showEmptyWorkspaces then
    return aeroJSON({ "list-workspaces", "--all", "--json" })
  else
    return aeroJSON({ "list-workspaces", "--monitor", "focused", "--empty", "no", "--json" })
  end
end

local function getFocusedWorkspace()
  local result = aeroJSON({ "list-workspaces", "--focused", "--json" })
  return result and result[1] and result[1].workspace
end

local function getWindows(workspaceId)
  return aeroJSON({ "list-windows", "--workspace", workspaceId, "--json" })
end

local function getAppBundleMap()
  local apps = aeroJSON({ "list-apps", "--json" })
  local map = {}
  if apps then
    for _, app in ipairs(apps) do
      map[app["app-name"]] = app["app-bundle-id"]
    end
  end
  return map
end

local function updateFocusHighlight(newWsId)
  if not canvas then
    return
  end

  if focusedWsId and cellIndices[focusedWsId] then
    canvas[cellIndices[focusedWsId]].fillColor = config.cellColor
  end

  if cellIndices[newWsId] then
    canvas[cellIndices[newWsId]].fillColor = config.focusedCellColor
  end

  focusedWsId = newWsId
end

local function buildOverlay()
  local workspaces = getWorkspaces()
  if not workspaces or #workspaces == 0 then
    return
  end

  focusedWsId = getFocusedWorkspace()
  local bundleMap = getAppBundleMap()
  cellIndices = {}

  local cols = config.cols
  local rows = math.ceil(#workspaces / cols)
  local totalW = cols * config.cellWidth + (cols + 1) * config.cellPadding
  local totalH = rows * config.cellHeight + (rows + 1) * config.cellPadding

  local screen = hs.mouse.getCurrentScreen():frame()
  local x = screen.x + (screen.w - totalW) / 2
  local y = screen.y + (screen.h - totalH) / 2

  if canvas then
    canvas:delete()
  end
  canvas = hs.canvas.new({ x = x, y = y, w = totalW, h = totalH })
  canvas:level(hs.canvas.windowLevels.floating)
  canvas:clickActivating(false)

  canvas:appendElements({
    type = "rectangle",
    frame = { x = 0, y = 0, w = totalW, h = totalH },
    fillColor = config.bgColor,
    roundedRectRadii = { xRadius = 12, yRadius = 12 },
    action = "fill",
  })

  local elementIndex = 1

  for i, ws in ipairs(workspaces) do
    local wsId = ws.workspace
    local col = (i - 1) % cols
    local row = math.floor((i - 1) / cols)
    local cx = config.cellPadding + col * (config.cellWidth + config.cellPadding)
    local cy = config.cellPadding + row * (config.cellHeight + config.cellPadding)
    local isFocused = (wsId == focusedWsId)
    local label = config.labels[wsId] or ""
    local headerText = wsId .. (label ~= "" and (" — " .. label) or "")

    elementIndex = elementIndex + 1
    cellIndices[wsId] = elementIndex
    canvas:appendElements({
      type = "rectangle",
      frame = { x = cx, y = cy, w = config.cellWidth, h = config.cellHeight },
      fillColor = isFocused and config.focusedCellColor or config.cellColor,
      roundedRectRadii = { xRadius = 8, yRadius = 8 },
      action = "fill",
      trackMouseDown = true,
      id = "ws-" .. wsId,
    })

    elementIndex = elementIndex + 1
    canvas:appendElements({
      type = "text",
      text = headerText,
      textColor = config.textColor,
      textSize = 13,
      textFont = ".AppleSystemUIFont",
      frame = { x = cx + 10, y = cy + 8, w = config.cellWidth - 20, h = 20 },
    })

    local windows = getWindows(wsId) or {}
    local seen = {}
    local iconX = cx + 10
    local iconY = cy + 34
    local maxIcons = math.floor((config.cellWidth - 20) / (config.iconSize + config.iconPadding))

    for j, win in ipairs(windows) do
      if j > maxIcons then
        break
      end
      local appName = win["app-name"]
      if not seen[appName] then
        seen[appName] = true
        local bundleId = bundleMap[appName]
        if bundleId then
          local icon = hs.image.imageFromAppBundle(bundleId)
          if icon then
            elementIndex = elementIndex + 1
            canvas:appendElements({
              type = "image",
              image = icon,
              frame = { x = iconX, y = iconY, w = config.iconSize, h = config.iconSize },
              imageScaling = "scaleProportionally",
            })
            iconX = iconX + config.iconSize + config.iconPadding
          end
        end
      end
    end
  end

  canvas:mouseCallback(function(c, message, id, mx, my)
    if message == "mouseDown" and id then
      local wsId = string.match(id, "^ws%-(.+)$")
      if wsId then
        aeroAsync({ "workspace", wsId })
        updateFocusHighlight(wsId)
      end
    end
  end)
end

local function dismiss()
  if canvas then
    canvas:hide(0.15)
  end
  if escapeHotkey then
    escapeHotkey:delete()
    escapeHotkey = nil
  end
  if appWatcher then
    appWatcher:stop()
    appWatcher = nil
  end
end

function M.toggle()
  if canvas and canvas:isShowing() then
    dismiss()
  else
    buildOverlay()
    if canvas then
      canvas:show(0.15)
      escapeHotkey = hs.hotkey.bind({}, "escape", dismiss)
      appWatcher = hs.application.watcher.new(function(_, event)
        if event == hs.application.watcher.activated then
          dismiss()
        end
      end)
      appWatcher:start()
    end
  end
end

return M
