-- Tells each Claude Code session running the knock mod when the screen locks
-- and unlocks. A session counts what finishes while the screen is locked, and
-- on unlock offers a "what did I miss" question in its prompt box.
local M = {}

-- Where the knock mod keeps one Unix socket per session.
local SOCKET_DIR = "/tmp/cc-knock"

-- Homebrew's xh by its full path: Hammerspoon runs with launchd's PATH, and the mise shim for xh
-- has no version set, so it only works where it can fall through to this one.
local XH = "/opt/homebrew/bin/xh"

---Posts `text` to `route` on every session's socket.
---@param route string
---@param text string
---@return integer # how many sockets it was sent to
function M.post(route, text)
  local sent = 0
  local ok, iter, dir = pcall(hs.fs.dir, SOCKET_DIR)
  if not ok then
    return sent
  end
  for name in iter, dir do
    if name:match("%.sock$") then
      -- A socket whose session has gone refuses the connection, and nothing waits on the result.
      hs.task
        .new(XH, nil, {
          "--ignore-stdin",
          "--quiet",
          "--timeout",
          "2",
          "--unix-socket",
          SOCKET_DIR .. "/" .. name,
          "POST",
          "http://knock/" .. route,
          "Content-Type:text/plain",
          "--raw",
          text,
        })
        :start()
      sent = sent + 1
    end
  end
  return sent
end

function M.start()
  local events = hs.caffeinate.watcher
  -- Kept on the module so the watcher isn't collected.
  M.watcher = events.new(function(event)
    if event == events.screensDidLock then
      M.post("away", "locked")
    elseif event == events.screensDidUnlock then
      M.post("back", "unlocked")
    end
  end)
  M.watcher:start()
end

return M
