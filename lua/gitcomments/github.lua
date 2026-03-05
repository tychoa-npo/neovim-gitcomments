local M = {}

--- Run a shell command asynchronously and call callback(ok, stdout, stderr).
--- Uses vim.fn.jobstart for compatibility with Neovim 0.8+.
---@param cmd string[]
---@param callback fun(ok: boolean, stdout: string, stderr: string)
local function run(cmd, callback)
  -- jobstart delivers stdout as chunks where the last element of each chunk
  -- is a partial line continued by the first element of the next chunk.
  -- We keep a running buffer to correctly reconstruct the full output.
  local stdout_buf = { "" }
  local stderr_buf = { "" }

  local function collect(buf, data)
    if not data or #data == 0 then return end
    buf[#buf] = buf[#buf] .. data[1]
    for i = 2, #data do
      table.insert(buf, data[i])
    end
  end

  vim.fn.jobstart(cmd, {
    -- Prevent child processes (gh, git) from inheriting Neovim's terminal
    -- stdin. Without this, gh can put the TTY into raw mode for interactive
    -- prompts, which causes "uv_tty_set_mode failed: i/o error" crashes.
    stdin = "null",
    on_stdout = function(_, data) collect(stdout_buf, data) end,
    on_stderr = function(_, data) collect(stderr_buf, data) end,
    on_exit = function(_, exit_code)
      local out = table.concat(stdout_buf, "\n")
      local err = table.concat(stderr_buf, "\n")
      vim.schedule(function()
        callback(exit_code == 0, out, err)
      end)
    end,
  })
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

--- Parse the GitHub owner and repo name from the git remote URL.
---@param repo_root string
---@param callback fun(info: {owner: string, name: string}|nil, err: string|nil)
function M.get_repo_info(repo_root, callback)
  run({ "git", "-C", repo_root, "remote", "get-url", "origin" }, function(ok, out, err)
    if not ok then
      callback(nil, err)
      return
    end
    local url = vim.trim(out)
    -- Handles both SSH (git@github.com:owner/repo.git) and HTTPS forms
    local owner, name = url:match("github%.com[:/]([^/]+)/([^/%.]+)")
    if owner and name then
      callback({ owner = owner, name = name }, nil)
    else
      callback(nil, "Could not parse GitHub owner/repo from remote: " .. url)
    end
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

--- Fetch all inline review comments for a PR via the REST API.
--- Uses per_page=100 (the API maximum) to minimise requests.
---@param pr_number integer
---@param owner string
---@param repo string
---@param callback fun(comments: table[]|nil, err: string|nil)
function M.fetch_review_comments(pr_number, owner, repo, callback)
  local path = string.format(
    "/repos/%s/%s/pulls/%d/comments?per_page=100",
    owner, repo, pr_number
  )
  run({ "gh", "api", path }, function(ok, out, err)
    if not ok then
      callback(nil, err)
      return
    end
    local ok_parse, data = pcall(vim.fn.json_decode, out)
    if not ok_parse or type(data) ~= "table" then
      callback(nil, "Failed to parse PR comments")
      return
    end
    callback(data, nil)
  end)
end

return M
