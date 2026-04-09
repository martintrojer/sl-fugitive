local M = {}

M.config = {
  default_command = "log",
  open_mode = "split",
  command = "sl",
}

local last_repo_root = nil

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  require("fugitive-core").setup(M.config)

  local has_redline, redline = pcall(require, "redline")
  if has_redline then
    local ui = require("sl-fugitive.ui")
    M.review_config = redline.make_config({
      repo_type = "Sapling",
      repo_root = function()
        return M.repo_root() or vim.fn.getcwd()
      end,
      open_mode = M.config.open_mode,
      buf_name = "sl-review",
      source = "sl-fugitive review",
      on_show = function(bufnr)
        if ui.buf_var(bufnr, "sl_review_keymaps_set", false) then
          return
        end
        pcall(vim.api.nvim_buf_set_var, bufnr, "sl_review_keymaps_set", true)

        ui.map(bufnr, "n", "gl", function()
          vim.cmd(ui.close_cmd())
          require("sl-fugitive").sl("log")
        end)
        ui.map(bufnr, "n", "gs", function()
          vim.cmd(ui.close_cmd())
          require("sl-fugitive.status").show()
        end)
        ui.map(bufnr, "n", "gb", function()
          vim.cmd(ui.close_cmd())
          require("sl-fugitive").sl("bookmark")
        end)
        ui.map(bufnr, "n", "g?", function()
          ui.help_popup("sl-fugitive Review", {
            "Review buffer",
            "",
            "Views:",
            "  gb      Switch to bookmark view",
            "  gl      Switch to log view",
            "  gs      Switch to status view",
            "",
            "Other:",
            "  q       Close",
            "  g?      This help",
          })
        end)
      end,
    })
  end
end

local REPO_MARKERS = { ".sl", ".hg", ".git/sl" }

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
    for _, marker in ipairs(REPO_MARKERS) do
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
    for _, marker in ipairs(REPO_MARKERS) do
      if vim.fn.isdirectory(last_repo_root .. "/" .. marker) == 1 then
        return last_repo_root
      end
    end
  end

  return nil
end

local function run_with_feedback(cmd, opts, label)
  vim.api.nvim_echo({ { label .. ": running...", "Comment" } }, false, {})
  vim.cmd("redraw")
  local result = vim.system(cmd, opts):wait()
  vim.api.nvim_echo({ { "" } }, false, {})
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

  local executable = M.config.command
  local sys_opts = { cwd = repo_root }
  if opts and opts.env then
    sys_opts.env = vim.tbl_extend("force", vim.fn.environ(), opts.env)
  end

  local cmd
  if type(args) == "string" then
    cmd = { "sh", "-c", executable .. " " .. args }
  elseif type(args) == "table" then
    cmd = vim.list_extend({ executable }, args)
  else
    ui.err("Invalid arguments to run_vcs")
    return nil
  end

  local result = run_with_feedback(cmd, sys_opts, executable)
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

  local executable = M.config.command
  local args_str = type(args) == "table" and table.concat(args, " ") or args
  if not args_str or args_str == "" then
    return
  end

  local prev_tab = vim.api.nvim_get_current_tabpage()
  vim.cmd("tabnew")
  local term_tab = vim.api.nvim_get_current_tabpage()

  local cmd = executable .. " " .. args_str
  if opts and opts.env then
    local parts = {}
    for key, value in pairs(opts.env) do
      table.insert(parts, key .. "=" .. vim.fn.shellescape(value))
    end
    table.sort(parts)
    cmd = table.concat(parts, " ") .. " " .. cmd
  end

  local function close_term_tab()
    vim.schedule(function()
      if vim.api.nvim_tabpage_is_valid(term_tab) then
        local wins = vim.api.nvim_tabpage_list_wins(term_tab)
        for _, win in ipairs(wins) do
          if vim.api.nvim_win_is_valid(win) then
            pcall(vim.api.nvim_win_close, win, true)
          end
        end
      end
      if vim.api.nvim_tabpage_is_valid(prev_tab) then
        pcall(vim.api.nvim_set_current_tabpage, prev_tab)
      end
    end)
  end

  vim.notify("Terminal mode — :q to cancel", vim.log.levels.INFO)
  local job_id = vim.fn.termopen(cmd, {
    cwd = repo_root,
    on_exit = function(_, exit_code)
      if exit_code == 0 then
        close_term_tab()
        vim.schedule(function()
          M.refresh_views()
        end)
      else
        vim.schedule(function()
          vim.notify(
            "Terminal exited with code " .. exit_code .. " — :q to close",
            vim.log.levels.WARN
          )
        end)
      end
    end,
  })
  if job_id <= 0 then
    ui.err("Failed to start terminal (job_id=" .. job_id .. "): " .. cmd)
    close_term_tab()
    return
  end
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
    if M.review_config then
      require("redline").show(M.review_config)
    else
      require("sl-fugitive.ui").warn("Review not available (redline.nvim not installed)")
    end
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

function M.undo()
  local result = M.run_vcs({ "undo" })
  if result then
    vim.notify("Undid last sl operation", vim.log.levels.INFO)
    M.refresh_views()
    return true
  end
  return false
end

function M.complete(arglead, cmdline, cursorpos)
  return require("sl-fugitive.completion").complete(arglead, cmdline, cursorpos)
end

return M
