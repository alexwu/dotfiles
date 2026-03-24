local M = {}

---@class GitBaseCache
---@field branch string
---@field merge_base string
---@field timestamp number

---@type table<string, GitBaseCache>
local cache = {}

local CACHE_TTL = 300 -- 5 minutes

---@param ref string
---@return string|nil
local function resolve_ref(ref)
  for _, candidate in ipairs({ "origin/" .. ref, ref }) do
    local result = vim.system({ "git", "rev-parse", "--verify", candidate }, { text = true }):wait()
    if result.code == 0 then
      return candidate
    end
  end
  return nil
end

---@param root string
---@return string|nil branch, string|nil merge_base
local function from_cache(root)
  local entry = cache[root]
  if entry and (os.time() - entry.timestamp) < CACHE_TTL then
    return entry.branch, entry.merge_base
  end
  return nil, nil
end

---@param root string
local function fetch_pr_base_async(root)
  local current =
    vim.trim(vim.system({ "git", "branch", "--show-current" }, { text = true, cwd = root }):wait().stdout or "")
  if current == "" then
    return
  end

  vim.system(
    { "gh", "pr", "view", current, "--json", "baseRefName", "--jq", ".baseRefName" },
    { text = true, cwd = root },
    function(result)
      local base = vim.trim(result.stdout or "")
      if base ~= "" then
        vim.schedule(function()
          local ref = resolve_ref(base)
          if ref then
            local mb = vim.trim(
              vim.system({ "git", "merge-base", "HEAD", ref }, { text = true, cwd = root }):wait().stdout or ""
            )
            if mb ~= "" then
              cache[root] = { branch = ref, merge_base = mb, timestamp = os.time() }
            end
          end
        end)
      end
    end
  )
end

--- Tier 2: Check reflog for creation entry
---@param root string
---@return string|nil ref, string|nil merge_base
local function from_reflog(root)
  local current =
    vim.trim(vim.system({ "git", "branch", "--show-current" }, { text = true, cwd = root }):wait().stdout or "")
  if current == "" then
    return nil, nil
  end

  local result = vim.system({ "git", "reflog", "show", current, "--format=%gs" }, { text = true, cwd = root }):wait()
  local lines = vim.split(vim.trim(result.stdout or ""), "\n")
  local creation_line = lines[#lines] or ""
  local created_from = creation_line:match("Created from (.+)")

  if created_from and created_from ~= "HEAD" and not created_from:match("^%x+$") then
    local ref = resolve_ref(created_from)
    if ref then
      local mb =
        vim.trim(vim.system({ "git", "merge-base", "HEAD", ref }, { text = true, cwd = root }):wait().stdout or "")
      if mb ~= "" then
        return ref, mb
      end
    end
  end

  return nil, nil
end

--- Tier 3: Merge-base distance heuristic (scan branches, find closest)
---@param root string
---@return string|nil ref, string|nil merge_base
local function from_merge_base_scan(root)
  local current =
    vim.trim(vim.system({ "git", "branch", "--show-current" }, { text = true, cwd = root }):wait().stdout or "")

  local refs_result = vim
    .system(
      {
        "git",
        "for-each-ref",
        "--format=%(refname:short)",
        "--sort=-committerdate",
        "refs/heads/",
        "refs/remotes/origin/",
      },
      { text = true, cwd = root }
    )
    :wait()

  local best_branch, best_mb, best_ahead = nil, nil, math.huge
  local count = 0

  for _, branch in ipairs(vim.split(vim.trim(refs_result.stdout or ""), "\n")) do
    if branch ~= "" and branch ~= current and branch ~= ("origin/" .. current) and branch ~= "origin/HEAD" then
      local mb =
        vim.trim(vim.system({ "git", "merge-base", "HEAD", branch }, { text = true, cwd = root }):wait().stdout or "")
      if mb ~= "" then
        local count_result = vim
          .system({ "git", "rev-list", "--count", mb .. "..HEAD" }, { text = true, cwd = root })
          :wait()
        local ahead = tonumber(vim.trim(count_result.stdout or "")) or math.huge
        if ahead < best_ahead then
          best_ahead = ahead
          best_branch = branch
          best_mb = mb
        end
      end

      count = count + 1
      if count >= 20 then
        break
      end
    end
  end

  return best_branch, best_mb
end

--- Tier 4: Default branch fallback
---@param root string
---@return string|nil ref, string|nil merge_base
local function from_default_branch(root)
  if vim.fn.executable("gh") == 1 then
    local result = vim
      .system(
        { "gh", "repo", "view", "--json", "defaultBranchRef", "--jq", ".defaultBranchRef.name" },
        { text = true, cwd = root }
      )
      :wait()
    local default = vim.trim(result.stdout or "")
    if default ~= "" then
      local ref = resolve_ref(default)
      if ref then
        local mb =
          vim.trim(vim.system({ "git", "merge-base", "HEAD", ref }, { text = true, cwd = root }):wait().stdout or "")
        if mb ~= "" then
          return ref, mb
        end
      end
    end
  end

  for _, ref in ipairs({ "origin/main", "origin/master", "main", "master" }) do
    local check = vim.system({ "git", "rev-parse", "--verify", ref }, { text = true, cwd = root }):wait()
    if check.code == 0 then
      local mb =
        vim.trim(vim.system({ "git", "merge-base", "HEAD", ref }, { text = true, cwd = root }):wait().stdout or "")
      if mb ~= "" then
        return ref, mb
      end
    end
  end

  return nil, nil
end

---@return string|nil git_root
local function get_git_root()
  local result = vim.system({ "git", "rev-parse", "--show-toplevel" }, { text = true }):wait()
  if result.code == 0 then
    return vim.trim(result.stdout or "")
  end
  return nil
end

--- Find the base branch for the current branch.
--- Reads from PR cache first, then falls through tiers synchronously.
---@return string base_ref, string merge_base
function M.find_base_branch()
  local root = get_git_root()
  if not root then
    return "HEAD", "HEAD"
  end

  -- Tier 1: Cached PR base
  local branch, mb = from_cache(root)
  if branch and mb then
    return branch, mb
  end

  -- Tier 2: Reflog
  branch, mb = from_reflog(root)
  if branch and mb then
    return branch, mb
  end

  -- Tier 3: Merge-base scan (capped at 20 branches)
  branch, mb = from_merge_base_scan(root)
  if branch and mb then
    return branch, mb
  end

  -- Tier 4: Default branch
  branch, mb = from_default_branch(root)
  if branch and mb then
    return branch, mb
  end

  return "HEAD", "HEAD"
end

function M.clear_cache()
  cache = {}
end

function M.setup()
  local group = vim.api.nvim_create_augroup("GitBaseCache", { clear = true })

  -- Nuke cache on directory change
  vim.api.nvim_create_autocmd("DirChanged", {
    group = group,
    callback = function()
      M.clear_cache()
    end,
  })

  -- Async PR base fetch on BufEnter (only if not cached)
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    callback = function()
      if vim.fn.executable("gh") ~= 1 then
        return
      end

      local root = get_git_root()
      if not root then
        return
      end

      -- Skip if already cached and not expired
      local entry = cache[root]
      if entry and (os.time() - entry.timestamp) < CACHE_TTL then
        return
      end

      fetch_pr_base_async(root)
    end,
  })
end

return M
