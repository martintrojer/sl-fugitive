local M = {}

M.config = {
  default_command = "log",
  open_mode = "split",
  command = "/var/home/martintrojer/sl/sl",
}

local last_repo_root = nil

local COMPLETE_COMMANDS = {
  "annotate",
  "blame",
  "bookmark",
  "browse",
  "commit",
  "describe",
  "diff",
  "log",
  "pull",
  "push",
  "review",
  "status",
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

local function repo_markers()
  return { ".sl", ".git/sl" }
end

local function find_repo_root()
  local search_paths = {}
  local buf_name = vim.api.nvim_buf_get_name(0)
  if buf_name ~= "" then
    local buf_dir = vim.fn.fnamemodify(buf_name, ":p:h")
    if vim.fn.isdirectory(buf_dir) == 1 then
      table.insert(search_paths, buf_dir)
    end
  end
  table.insert(search_paths, vim.fn.getcwd())

  for _, path in ipairs(search_paths) do
    for _, marker in ipairs(repo_markers()) do
      local found = vim.fs.find(marker, { path = path, upward = true, type = "directory" })
      if #found > 0 then
        local marker_path = found[1]
        if marker == ".git/sl" then
          last_repo_root = vim.fn.fnamemodify(marker_path, ":h:h")
        else
          last_repo_root = vim.fn.fnamemodify(marker_path, ":h")
        end
        return last_repo_root
      end
    end
  end

  if last_repo_root then
    for _, marker in ipairs(repo_markers()) do
      if vim.fn.isdirectory(last_repo_root .. "/" .. marker) == 1 then
        return last_repo_root
      end
    end
  end

  return nil
end

local function command_name()
  return M.config.command
end

local function run_with_feedback(cmd, opts, label)
  local proc = vim.system(cmd, opts)
  local result = proc:wait(200)
  if not result then
    vim.api.nvim_echo({ { label .. ": running...", "Comment" } }, false, {})
    vim.cmd("redraw")
    result = proc:wait()
    vim.api.nvim_echo({ { "" } }, false, {})
  end
  return result
end

function M.repo_root()
  return find_repo_root()
end

function M.run_vcs(args, opts)
  local ui = require("sl-fugitive.ui")
  local repo_root = find_repo_root()
  if not repo_root then
    ui.err("Not in a Sapling repository")
    return nil
  end

  local executable = command_name()
  local sys_opts = { cwd = repo_root }
  if opts and opts.env then
    sys_opts.env = opts.env
  end

  local cmd
  if type(args) == "string" then
    cmd = { "sh", "-c", executable .. " " .. args }
  elseif type(args) == "table" then
    cmd = vim.list_extend({ executable }, vim.deepcopy(args))
  else
    ui.err("Invalid arguments to run_vcs")
    return nil
  end

  local result = run_with_feedback(cmd, sys_opts, "sl")
  if result.code ~= 0 then
    local err_msg = result.stderr or ""
    if err_msg:match("^%s*$") then
      err_msg = result.stdout or ""
    end
    if err_msg:match("^%s*$") then
      err_msg = "command failed (exit code " .. result.code .. ")"
    end
    ui.err("sl: " .. err_msg:gsub("%s+$", ""))
    return nil
  end

  return result.stdout, repo_root
end

function M.run_vcs_terminal(args, opts)
  local ui = require("sl-fugitive.ui")
  local repo_root = find_repo_root()
  if not repo_root then
    ui.err("Not in a Sapling repository")
    return
  end

  local executable = command_name()
  local args_str = type(args) == "table" and table.concat(args, " ") or args
  if not args_str or args_str == "" then
    return
  end

  vim.notify("sl terminal mode", vim.log.levels.INFO)
  vim.cmd("tabnew")
  local term_buf = vim.api.nvim_get_current_buf()

  local env_prefix = ""
  if opts and opts.env then
    local parts = {}
    for key, value in pairs(opts.env) do
      table.insert(parts, key .. "=" .. vim.fn.shellescape(value))
    end
    table.sort(parts)
    env_prefix = table.concat(parts, " ") .. " "
  end

  vim.fn.termopen(env_prefix .. executable .. " " .. args_str, {
    cwd = repo_root,
    on_exit = function(_, exit_code)
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(term_buf) then
          vim.api.nvim_buf_delete(term_buf, { force = true })
        end
        if exit_code == 0 then
          M.refresh_views()
        end
      end)
    end,
  })
  vim.cmd("startinsert")
end

function M.sl(args)
  if not args or args == "" then
    if M.config.default_command and M.config.default_command ~= "" then
      return M.sl(M.config.default_command)
    end
    require("sl-fugitive.log").show()
    return
  end

  local parts = vim.split(args, "%s+", { trimempty = true })
  local command = parts[1]
  local rest = table.concat(parts, " ", 2)

  if command == "status" then
    require("sl-fugitive.status").show()
    return
  end

  if command == "log" then
    require("sl-fugitive.log").show()
    return
  end

  if command == "annotate" or command == "blame" then
    require("sl-fugitive.annotate").show(rest ~= "" and rest or nil)
    return
  end

  if command == "bookmark" or command == "bookmarks" then
    require("sl-fugitive.bookmark").show()
    return
  end

  if command == "describe" then
    require("sl-fugitive.describe").describe(rest ~= "" and rest or nil)
    return
  end

  if command == "commit" then
    require("sl-fugitive.describe").commit()
    return
  end

  if command == "browse" then
    require("sl-fugitive.browse").browse(rest ~= "" and rest or nil)
    return
  end

  if command == "diff" then
    require("sl-fugitive.diff").show(rest ~= "" and rest or nil)
    return
  end

  if command == "review" then
    require("sl-fugitive.review").show()
    return
  end

  if command == "push" or command == "pull" then
    local result = M.run_vcs(args)
    if result then
      local msg = result:gsub("%s+$", "")
      vim.notify(msg ~= "" and msg or (command .. " completed"), vim.log.levels.INFO)
      M.refresh_views()
    end
    return
  end

  local result = M.run_vcs(args)
  if result then
    print(result)
    M.refresh_views()
  end
end

function M.refresh_views()
  vim.schedule(function()
    require("sl-fugitive.log").refresh()
    require("sl-fugitive.status").refresh()
    require("sl-fugitive.bookmark").refresh()
  end)
end

function M.refresh_log()
  M.refresh_views()
end

function M.undo()
  require("sl-fugitive.ui").warn("Undo is not implemented yet for sl-fugitive")
  return false
end

function M.complete(arglead)
  local matches = {}
  for _, item in ipairs(COMPLETE_COMMANDS) do
    if item:find("^" .. vim.pesc(arglead)) then
      table.insert(matches, item)
    end
  end
  return matches
end

return M
