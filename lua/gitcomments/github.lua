local M = {}

--- Run a shell command asynchronously and call callback(ok, stdout, stderr).
---@param cmd string[]
---@param callback fun(ok: boolean, stdout: string, stderr: string)
local function run(cmd, callback)
  local stdout_chunks = {}
  local stderr_chunks = {}

  vim.system(cmd, {
    stdout = function(_, data)
      if data then
        table.insert(stdout_chunks, data)
      end
    end,
    stderr = function(_, data)
      if data then
        table.insert(stderr_chunks, data)
      end
    end,
  }, function(obj)
    local out = table.concat(stdout_chunks)
    local err = table.concat(stderr_chunks)
    vim.schedule(function()
      callback(obj.code == 0, out, err)
    end)
  end)
end

--- Get the git repository root for the given directory.
---@param dir string
---@param callback fun(root: string|nil)
function M.get_repo_root(dir, callback)
  run({ "git", "-C", dir, "rev-parse", "--show-toplevel" }, function(ok, out)
    callback(ok and vim.trim(out) or nil)
  end)
end

--- Get the current git branch name.
---@param repo_root string
---@param callback fun(branch: string|nil)
function M.get_current_branch(repo_root, callback)
  run({ "git", "-C", repo_root, "rev-parse", "--abbrev-ref", "HEAD" }, function(ok, out)
    callback(ok and vim.trim(out) or nil)
  end)
end

--- Find the open PR number for the given branch using gh CLI.
---@param branch string
---@param callback fun(pr_number: integer|nil, err: string|nil)
function M.find_pr_for_branch(branch, callback)
  run({
    "gh", "pr", "list",
    "--head", branch,
    "--state", "open",
    "--json", "number",
    "--limit", "1",
  }, function(ok, out, err)
    if not ok then
      callback(nil, err)
      return
    end
    local ok_parse, list = pcall(vim.fn.json_decode, out)
    if not ok_parse or type(list) ~= "table" or #list == 0 then
      callback(nil, "No open PR found for branch: " .. branch)
      return
    end
    callback(list[1].number, nil)
  end)
end

--- Fetch review threads for the given PR number.
--- Returns a list of reviewThread objects from the GitHub API.
---@param pr_number integer
---@param callback fun(threads: table[]|nil, err: string|nil)
function M.fetch_review_threads(pr_number, callback)
  run({
    "gh", "pr", "view", tostring(pr_number),
    "--json", "reviewThreads",
  }, function(ok, out, err)
    if not ok then
      callback(nil, err)
      return
    end
    local ok_parse, data = pcall(vim.fn.json_decode, out)
    if not ok_parse or type(data) ~= "table" then
      callback(nil, "Failed to parse PR data")
      return
    end
    callback(data.reviewThreads or {}, nil)
  end)
end

return M
