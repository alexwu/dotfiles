local M = {}

-- Where Claude Code's knock mod keeps one Unix socket per session.
local SOCKET_DIR = "/tmp/cc-knock"

-- The listener takes a body of at most 16 KB, so a longer diff is replaced by a note.
local MAX_DIFF_BYTES = 12000

local MAX_FILE_BYTES = 1024 * 1024

---The file as it was on disk before the save in progress, by buffer.
---@type table<integer, string>
local before = {}

---@return string[]
local function sockets()
  local dir = vim.g.bombeelu_knock_dir or SOCKET_DIR
  return vim.fn.glob(dir .. "/*.sock", false, true)
end

---@param buf integer
---@return string|nil
local function file_of(buf)
  if vim.bo[buf].buftype ~= "" then
    return nil
  end
  local name = vim.api.nvim_buf_get_name(buf)
  if name == "" then
    return nil
  end
  return vim.fs.normalize(vim.fn.fnamemodify(name, ":p"))
end

---@param path string
---@return string|nil
local function read(path)
  local stat = vim.uv.fs_stat(path)
  if not stat or stat.type ~= "file" or stat.size > MAX_FILE_BYTES then
    return nil
  end
  local file = io.open(path, "rb")
  if not file then
    return nil
  end
  local text = file:read("*a")
  file:close()
  return text
end

---Keeps the file as it is on disk, just before a save replaces it.
---@param buf integer
function M.remember(buf)
  before[buf] = nil
  if vim.g.bombeelu_knock == false or vim.fn.executable("xh") ~= 1 or #sockets() == 0 then
    return
  end
  local path = file_of(buf)
  if path then
    before[buf] = read(path)
  end
end

---Sends each listening session a diff of what the save just changed. A session keeps it only
---for a file it works in, and shows it to the agent beside the next prompt.
---@param buf integer
function M.send(buf)
  local old = before[buf]
  before[buf] = nil
  local path = file_of(buf)
  local new = path and read(path)
  if not old or not path or not new then
    return
  end

  local diff = vim.text.diff(old, new, { ctxlen = 3 })
  if type(diff) ~= "string" or diff == "" then
    return
  end
  if #diff > MAX_DIFF_BYTES then
    diff = ("(This save's diff is %d bytes, too long to send. Read the file.)"):format(#diff)
  end

  for _, socket in ipairs(sockets()) do
    -- A socket whose session has gone refuses the connection, and nothing is waiting on the result.
    vim.system({
      "xh",
      "--quiet",
      "--timeout",
      "2",
      "--unix-socket",
      socket,
      "POST",
      "http://knock/edited",
      "Content-Type:text/plain",
      "X-Knock-Path:" .. vim.uri_encode(path),
    }, { stdin = diff, text = true }, function() end)
  end
end

function M.setup()
  local group = vim.api.nvim_create_augroup("BombeeluKnock", { clear = true })

  vim.api.nvim_create_autocmd("BufWritePre", {
    group = group,
    callback = function(ev)
      M.remember(ev.buf)
    end,
  })

  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    callback = function(ev)
      M.send(ev.buf)
    end,
  })
end

return M
