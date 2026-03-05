local M = {}

-- Cache: repo_root -> { ["rel/path:line"] -> thread[] }
local cache = {}

--- Build a lookup key from a relative file path and line number.
---@param rel_path string
---@param line integer
---@return string
local function key(rel_path, line)
  return rel_path .. ":" .. tostring(line)
end

--- Store parsed review threads for a repo root.
--- Threads that have no path or line are skipped.
---@param repo_root string
---@param threads table[] Raw reviewThread objects from GitHub
---@param include_resolved boolean
function M.store(repo_root, threads, include_resolved)
  local store = {}
  for _, thread in ipairs(threads) do
    if thread.path and thread.line then
      if include_resolved or not thread.isResolved then
        local k = key(thread.path, thread.line)
        if not store[k] then
          store[k] = {}
        end
        table.insert(store[k], thread)
      end
    end
  end
  cache[repo_root] = store
end

--- Clear cached comments for a repo root.
---@param repo_root string
function M.clear(repo_root)
  cache[repo_root] = nil
end

--- Get threads for a specific file line.
---@param repo_root string
---@param rel_path string Path relative to repo root
---@param line integer 1-based line number
---@return table[]|nil
function M.get(repo_root, rel_path, line)
  local store = cache[repo_root]
  if not store then return nil end
  return store[key(rel_path, line)]
end

--- Return all (rel_path, line) pairs that have comments for the given repo root.
---@param repo_root string
---@return {path: string, line: integer}[]
function M.all_locations(repo_root)
  local store = cache[repo_root]
  if not store then return {} end
  local result = {}
  for k, _ in pairs(store) do
    local path, line = k:match("^(.+):(%d+)$")
    if path and line then
      table.insert(result, { path = path, line = tonumber(line) })
    end
  end
  return result
end

--- Return true if there is cached data for this repo root.
---@param repo_root string
---@return boolean
function M.has_cache(repo_root)
  return cache[repo_root] ~= nil
end

return M
