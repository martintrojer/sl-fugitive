local core_ui = require("fugitive-core.ui")
local M = setmetatable({}, { __index = core_ui })

function M.file_at_rev(filename, rev)
  local init = require("sl-fugitive")
  local repo_root = init.repo_root()
  if not repo_root then
    return ""
  end

  local executable = init.config.command
  local result = vim.system({ executable, "cat", "-r", rev, filename }, { cwd = repo_root }):wait()
  if result.code ~= 0 then
    return ""
  end
  return result.stdout or ""
end

return M
