local M = {}

local ansi = require("sl-fugitive.ansi")
local ui = require("sl-fugitive.ui")

local BUF_PATTERN = "sl%-log"
local BUF_NAME = "sl-log"

local ws_ns = vim.api.nvim_create_namespace("sl_workspace_status")

local function workspace_status()
  local init = require("sl-fugitive")

  -- Check for unresolved conflicts
  local conflicts = init.run_vcs({ "resolve", "--list" })
  if conflicts and conflicts:match("^U ") then
    local count = 0
    for _ in conflicts:gmatch("\nU ") do
      count = count + 1
    end
    if conflicts:match("^U ") then
      count = count + 1
    end
    return " CONFLICTS: " .. count .. " unresolved — sl resolve ", "conflict"
  end

  -- Check working copy status
  local status = init.run_vcs({ "status" })
  if not status or status:match("^%s*$") then
    return " Working copy clean ", "clean"
  end

  local m, a, r, u = 0, 0, 0, 0
  for line in status:gmatch("[^\n]+") do
    local code = line:match("^(%S)")
    if code == "M" then
      m = m + 1
    elseif code == "A" then
      a = a + 1
    elseif code == "R" or code == "!" then
      r = r + 1
    elseif code == "?" then
      u = u + 1
    end
  end

  local parts = {}
  if m > 0 then
    table.insert(parts, m .. " modified")
  end
  if a > 0 then
    table.insert(parts, a .. " added")
  end
  if r > 0 then
    table.insert(parts, r .. " removed")
  end
  if u > 0 then
    table.insert(parts, u .. " untracked")
  end
  return " Working copy: " .. table.concat(parts, ", ") .. " ", "dirty"
end

-- Define workspace status highlight groups once
vim.api.nvim_set_hl(0, "SlWsClean", { default = true, bg = "#2d4f2d", fg = "#a3d9a3", bold = true })
vim.api.nvim_set_hl(0, "SlWsDirty", { default = true, bg = "#4f4f2d", fg = "#d9d9a3", bold = true })
vim.api.nvim_set_hl(0, "SlWsConflict", { default = true, bg = "#4f2d2d", fg = "#d9a3a3", bold = true })

local WS_HL_MAP = { clean = "SlWsClean", dirty = "SlWsDirty", conflict = "SlWsConflict" }

local function highlight_workspace_status(bufnr, status_line_nr, state)
  local hl_map = WS_HL_MAP
  local hl = hl_map[state]
  if hl and status_line_nr then
    vim.api.nvim_buf_clear_namespace(bufnr, ws_ns, 0, -1)
    vim.api.nvim_buf_set_extmark(bufnr, ws_ns, status_line_nr, 0, {
      end_row = status_line_nr,
      end_col = #(vim.api.nvim_buf_get_lines(bufnr, status_line_nr, status_line_nr + 1, false)[1] or ""),
      hl_group = hl,
      hl_eol = true,
    })
  end
end

local function log_header()
  local ws_text, ws_state = workspace_status()
  local ws_line = 3 -- 0-indexed position of ws_text in lines below
  local lines = {
    "",
    "# sl Smartlog",
    "# Press g? for help",
    ws_text,
    "",
  }
  return lines, ws_state, ws_line
end

local function get_log_output()
  return require("sl-fugitive").run_vcs({
    "sl",
    "--color=always",
  })
end

local node_from_line = ui.node_from_line

local function selected_node()
  local node = node_from_line(vim.api.nvim_get_current_line())
  if not node then
    ui.warn("Place the cursor on a changeset line")
    return nil
  end
  return node
end

local function get_changeset_metadata(node)
  local output = require("sl-fugitive").run_vcs({
    "log",
    "-r",
    node,
    "-T",
    "{node|short}\\n{desc|firstline}\\n{author|person}\\n{date|isodate}\\n",
  })
  if not output then
    return { node = node }
  end

  local lines = vim.split(output:gsub("%s+$", ""), "\n", { plain = true })
  return {
    node = lines[1] ~= "" and lines[1] or node,
    summary = lines[2] or "",
    author = lines[3] or "",
    date = lines[4] or "",
  }
end

function M.show_changeset(node, opts)
  local meta = get_changeset_metadata(node)
  local output = require("sl-fugitive").run_vcs({ "log", "-p", "-r", node })
  if not output then
    return
  end

  local header = {
    "",
    "# Changeset: " .. (meta.node or node),
    "# Press g? for help, q to close",
    "",
  }

  if meta.summary and meta.summary ~= "" then
    table.insert(header, "# Summary: " .. meta.summary)
    table.insert(header, "")
  end

  local bufname = "sl-show: " .. (meta.node or node)
  local bufnr = ui.find_buf("^" .. vim.pesc(bufname) .. " %[%d+%]$")
  if bufnr then
    ansi.update_colored_buffer(bufnr, output, header, { prefix = "SlShow" })
  else
    bufnr = ansi.create_colored_buffer(output, bufname, header, { prefix = "SlShow" })
  end

  local ctx = {
    source = "changeset detail",
    rev = meta.node or node,
    node = meta.node or node,
    summary = meta.summary,
    author = meta.author,
    date = meta.date,
  }
  pcall(vim.api.nvim_buf_set_var, bufnr, "sl_buffer_context", ctx)
  pcall(vim.api.nvim_buf_set_var, bufnr, "sl_changeset_node", meta.node or node)
  M.setup_detail_keymaps(bufnr, ctx)
  if opts and opts.split_cmd then
    ui.open_pane({ split_cmd = opts.split_cmd })
    vim.api.nvim_set_current_buf(bufnr)
  else
    ui.ensure_visible(bufnr)
  end
  ui.set_statusline(bufnr, "sl-show:" .. node)
end

local function run_goto(node)
  local result = require("sl-fugitive").run_vcs({ "goto", node })
  if result then
    ui.info("Goto " .. node)
    M.refresh()
    require("sl-fugitive.status").refresh()
  end
end

local function run_rebase(node, include_descendants)
  local flag = include_descendants and "-s" or "-r"
  local label = include_descendants and "Rebase stack from " or "Rebase "
  vim.ui.input({ prompt = label .. node .. " onto: " }, function(dest)
    if not dest or dest:match("^%s*$") then
      return
    end
    local result = require("sl-fugitive").run_vcs({ "rebase", flag, node, "-d", dest })
    if result then
      ui.info("Rebased " .. node .. " onto " .. dest)
      require("sl-fugitive").refresh_views()
    end
  end)
end

local function run_interactive_rebase(node)
  local init = require("sl-fugitive")
  -- Go to the top of the stack so all commits from node to tip are included
  init.run_vcs({ "next", "--top", "-q" })
  init.run_vcs_terminal({ "rebase", "-i", "-s", node, "-d", node .. "^" })
end

local function run_split(node)
  require("sl-fugitive").run_vcs_terminal({ "split", "-r", node })
end

local function run_fold_from(node)
  if not ui.confirm("Fold linearly from current commit to " .. node .. "?") then
    return
  end
  vim.ui.input({ prompt = "Folded commit message: " }, function(message)
    if not message or message:match("^%s*$") then
      return
    end
    local result = require("sl-fugitive").run_vcs({ "fold", "--from", "-r", node, "-m", message })
    if result then
      ui.info("Folded from current commit to " .. node)
      require("sl-fugitive").refresh_views()
    end
  end)
end

local function run_restack()
  local result = require("sl-fugitive").run_vcs({ "restack" })
  if result then
    ui.info("Restacked current stack")
    M.refresh()
  end
end

local function run_rebase_continue()
  local result = require("sl-fugitive").run_vcs({ "rebase", "--continue" })
  if result then
    ui.info("Continued rebase")
    M.refresh()
  end
end

local function run_rebase_abort()
  if not ui.confirm("Abort the current rebase?") then
    return
  end
  local result = require("sl-fugitive").run_vcs({ "rebase", "--abort" })
  if result then
    ui.info("Aborted rebase")
    M.refresh()
  end
end

local function run_absorb()
  local result = require("sl-fugitive").run_vcs({ "absorb", "-a" })
  if result then
    ui.info("Absorbed working changes into current stack")
    M.refresh()
    require("sl-fugitive.status").refresh()
  end
end

local function run_metaedit(node)
  local meta = get_changeset_metadata(node)
  vim.ui.input({
    prompt = "Metaedit message for " .. (meta.node or node) .. ": ",
    default = meta.summary or "",
  }, function(message)
    if not message or message:match("^%s*$") then
      return
    end
    local result = require("sl-fugitive").run_vcs({ "metaedit", "-r", node, "-m", message })
    if result then
      ui.info("Updated metadata for " .. (meta.node or node))
      M.refresh()
    end
  end)
end

local function run_amend_to(node)
  if not ui.confirm("Amend current working changes into " .. node .. "?") then
    return
  end
  local result = require("sl-fugitive").run_vcs({ "amend", "--to", node })
  if result then
    ui.info("Amended working changes into " .. node)
    M.refresh()
    require("sl-fugitive.status").refresh()
  end
end

local function run_hide(node)
  if not ui.confirm("Hide " .. node .. " and its descendants?") then
    return
  end
  local result = require("sl-fugitive").run_vcs({ "hide", "-r", node })
  if result then
    ui.info("Hid " .. node)
    M.refresh()
    require("sl-fugitive.status").refresh()
  end
end

function M.setup_detail_keymaps(bufnr, review_ctx)
  ui.map(bufnr, "n", "q", function()
    vim.cmd(ui.close_cmd())
  end)

  local init = require("sl-fugitive")
  if init.review_config then
    ui.map(bufnr, "n", "cR", function()
      require("redline").comment_unified_diff(init.review_config, bufnr, review_ctx)
    end)
    ui.map(bufnr, "n", "gR", function()
      require("redline").show(init.review_config)
    end)
  end

  ui.map(bufnr, "n", "gl", function()
    vim.cmd(ui.close_cmd())
    M.show()
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
    ui.help_popup("sl-fugitive Changeset", {
      "Changeset detail view",
      "",
      "Actions:",
      "  cR      Add review comment",
      "  gR      Open review buffer",
      "",
      "Views:",
      "  gb      Switch to bookmark view",
      "  gl      Switch to smartlog",
      "  gs      Switch to status view",
      "",
      "Other:",
      "  q       Close",
      "  g?      This help",
    })
  end)
end

local function setup_keymaps(bufnr)
  if ui.buf_var(bufnr, "sl_log_keymaps_set", false) then
    return
  end
  pcall(vim.api.nvim_buf_set_var, bufnr, "sl_log_keymaps_set", true)

  ui.map(bufnr, "n", "<CR>", function()
    local node = selected_node()
    if node then
      M.show_changeset(node)
    end
  end)

  ui.map(bufnr, "n", "d", function()
    local node = selected_node()
    if node then
      require("sl-fugitive.diff").show({ rev = node })
    end
  end)

  ui.map(bufnr, "n", "go", function()
    local node = selected_node()
    if node then
      run_goto(node)
    end
  end)

  ui.map(bufnr, "n", "rr", function()
    local node = selected_node()
    if node then
      run_rebase(node, false)
    end
  end)

  ui.map(bufnr, "n", "rs", function()
    local node = selected_node()
    if node then
      run_rebase(node, true)
    end
  end)

  ui.map(bufnr, "n", "rS", function()
    local node = selected_node()
    if node then
      run_split(node)
    end
  end)

  ui.map(bufnr, "n", "ri", function()
    local node = selected_node()
    if node then
      run_interactive_rebase(node)
    end
  end)

  ui.map(bufnr, "n", "rf", function()
    local node = selected_node()
    if node then
      run_fold_from(node)
    end
  end)

  ui.map(bufnr, "n", "rR", function()
    run_restack()
  end)

  ui.map(bufnr, "n", "rc", function()
    run_rebase_continue()
  end)

  ui.map(bufnr, "n", "rA", function()
    run_rebase_abort()
  end)

  ui.map(bufnr, "n", "ra", function()
    run_absorb()
  end)

  ui.map(bufnr, "n", "rm", function()
    local node = selected_node()
    if node then
      run_metaedit(node)
    end
  end)

  ui.map(bufnr, "n", "rt", function()
    local node = selected_node()
    if node then
      run_amend_to(node)
    end
  end)

  ui.map(bufnr, "n", "rh", function()
    local node = selected_node()
    if node then
      run_hide(node)
    end
  end)

  local init = require("sl-fugitive")
  if init.review_config then
    ui.map(bufnr, "n", "gR", function()
      require("redline").show(init.review_config)
    end)
  end

  ui.map(bufnr, "n", "gs", function()
    vim.cmd(ui.close_cmd())
    require("sl-fugitive.status").show()
  end)

  ui.map(bufnr, "n", "gb", function()
    vim.cmd(ui.close_cmd())
    require("sl-fugitive").sl("bookmark")
  end)

  ui.map(bufnr, "n", "R", function()
    M.refresh()
  end)

  ui.map(bufnr, "n", "q", function()
    vim.cmd(ui.close_cmd())
  end)

  ui.map(bufnr, "n", "g?", function()
    ui.help_popup("sl-fugitive Smartlog", {
      "Smartlog view",
      "",
      "Actions:",
      "  <CR>     Show changeset detail",
      "  d        Show diff for changeset",
      "  go       Goto selected commit",
      "  ra       Absorb current working changes into the stack",
      "  rm       Edit selected commit metadata/message",
      "  rr       Rebase selected commit onto a destination",
      "  rs       Rebase selected commit and descendants onto a destination",
      "  ri       Interactive rebase from selected commit (:q to cancel)",
      "  rS       Split selected commit (:q to cancel)",
      "  rt       Amend working changes into selected commit",
      "  rf       Fold linearly from current commit to selected commit",
      "  rh       Hide selected commit and descendants",
      "  rR       Restack current stack",
      "  rc       Continue interrupted rebase",
      "  rA       Abort interrupted rebase",
      "  gR       Open review buffer",
      "",
      "Views:",
      "  gb       Switch to bookmark view",
      "  gs       Switch to status view",
      "",
      "Other:",
      "  R        Refresh",
      "  q        Close",
      "  g?       This help",
    })
  end)
end

function M.refresh()
  local bufnr = ui.find_buf(BUF_PATTERN)
  if not bufnr then
    return
  end
  local output = get_log_output()
  if not output then
    return
  end
  local header, ws_state, ws_line = log_header()
  ansi.update_colored_buffer(bufnr, output, header, { prefix = "SlLog" })
  highlight_workspace_status(bufnr, ws_line, ws_state)
end

function M.show()
  local output = get_log_output()
  if not output then
    return
  end

  local header, ws_state, ws_line = log_header()
  local bufnr = ui.find_buf(BUF_PATTERN)
  if bufnr then
    ansi.update_colored_buffer(bufnr, output, header, { prefix = "SlLog" })
  else
    bufnr = ansi.create_colored_buffer(output, BUF_NAME, header, { prefix = "SlLog" })
  end
  highlight_workspace_status(bufnr, ws_line, ws_state)

  setup_keymaps(bufnr)
  ui.ensure_visible(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for i, line in ipairs(lines) do
    if node_from_line(line) then
      pcall(vim.api.nvim_win_set_cursor, 0, { i, 0 })
      break
    end
  end
  ui.set_statusline(bufnr, "sl-log")
end

return M
