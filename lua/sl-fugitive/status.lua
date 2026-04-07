local M = {}

local BUF_PATTERN = "sl%-status"
local BUF_NAME = "sl-status"

local function get_status()
  return require("sl-fugitive").run_vcs({ "status", "-C" })
end

local function file_from_line(line)
  if not line or line == "" or line:match("^%s*#") or line:match("^%s*$") then
    return nil
  end
  local status, filename = line:match("^%s*([MARC!%?I])%s+(.+)$")
  if not status then
    return nil
  end
  local renamed = filename:match("^.+%s+->%s+(.+)$")
  return renamed or filename
end

local function status_code_from_line(line)
  return line and line:match("^%s*([MARC!%?I])%s+")
end

local function inline_diff_state(bufnr)
  return require("sl-fugitive.ui").buf_var(bufnr, "jj_status_inline_diffs", {})
end

local function set_inline_diff_state(bufnr, state)
  pcall(vim.api.nvim_buf_set_var, bufnr, "jj_status_inline_diffs", state)
end

local function shift_inline_ranges(state, from_line, delta)
  for _, item in ipairs(state) do
    if item.start_line > from_line then
      item.start_line = item.start_line + delta
      item.end_line = item.end_line + delta
    end
  end
end

local function supports_diff(code)
  return code == "M" or code == "A" or code == "R"
end

local function toggle_inline_diff(bufnr)
  local ui = require("sl-fugitive.ui")
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line_nr = cursor[1]
  local line = vim.api.nvim_buf_get_lines(bufnr, line_nr - 1, line_nr, false)[1]
  local file = file_from_line(line)
  local status = status_code_from_line(line)
  if not file then
    return
  end

  local state = inline_diff_state(bufnr)
  for i, item in ipairs(state) do
    if item.start_line == line_nr + 1 then
      vim.bo[bufnr].modifiable = true
      vim.api.nvim_buf_set_lines(bufnr, item.start_line - 1, item.end_line, false, {})
      vim.bo[bufnr].modifiable = false
      vim.bo[bufnr].modified = false

      local removed = item.end_line - item.start_line + 1
      table.remove(state, i)
      shift_inline_ranges(state, item.start_line - 1, -removed)
      set_inline_diff_state(bufnr, state)
      return
    end
  end

  if not supports_diff(status) then
    ui.warn("Inline diff is only available for tracked changes")
    return
  end

  local diff_output = require("sl-fugitive").run_vcs({ "diff", "--git", file })
  if not diff_output or diff_output:match("^%s*$") then
    ui.warn("No diff available for " .. file)
    return
  end

  local diff_lines = {}
  for _, dl in ipairs(vim.split(diff_output, "\n", { plain = true })) do
    if dl ~= "" then
      table.insert(diff_lines, "    " .. dl)
    end
  end

  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, line_nr, line_nr, false, diff_lines)
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].modified = false

  shift_inline_ranges(state, line_nr, #diff_lines)
  table.insert(state, {
    start_line = line_nr + 1,
    end_line = line_nr + #diff_lines,
    file = file,
    rev = ".",
  })
  set_inline_diff_state(bufnr, state)

  for i = line_nr, line_nr + #diff_lines - 1 do
    local dl = diff_lines[i - line_nr + 1]
    local hl
    if dl:match("^    %+") then
      hl = "DiffAdd"
    elseif dl:match("^    %-") then
      hl = "DiffDelete"
    elseif dl:match("^    @@") then
      hl = "DiffChange"
    end
    if hl then
      vim.api.nvim_buf_add_highlight(bufnr, -1, hl, i, 0, -1)
    end
  end
end

local function comment_inline_diff(bufnr)
  local init = require("sl-fugitive")
  if not init.review_config then
    require("sl-fugitive.ui").warn("Review not available (redline.nvim not installed)")
    return
  end
  local ranges = inline_diff_state(bufnr)
  require("redline").comment(init.review_config, bufnr, function(b)
    return require("redline").extract_inline_diff_entry(b, ranges)
  end)
end

local function format_lines(output)
  local lines = {
    "",
    "# sl Status",
    "# Press g? for help",
    "# Copy metadata is shown on indented lines",
    "",
  }
  local saw_files = false
  for _, line in ipairs(vim.split(output or "", "\n", { plain = true })) do
    if line ~= "" then
      saw_files = true
      table.insert(lines, line)
    end
  end
  if not saw_files then
    table.insert(lines, "Working copy clean")
  end
  return lines
end

local function setup_keymaps(bufnr)
  local ui = require("sl-fugitive.ui")
  if ui.buf_var(bufnr, "hg_status_keymaps_set", false) then
    return
  end
  pcall(vim.api.nvim_buf_set_var, bufnr, "hg_status_keymaps_set", true)

  ui.map(bufnr, "n", "<CR>", function()
    local file = file_from_line(vim.api.nvim_get_current_line())
    if file then
      vim.cmd(ui.close_cmd())
      vim.cmd("edit " .. vim.fn.fnameescape(file))
    end
  end)

  ui.map(bufnr, "n", "o", function()
    local file = file_from_line(vim.api.nvim_get_current_line())
    if file then
      vim.cmd(ui.close_cmd())
      vim.cmd("split " .. vim.fn.fnameescape(file))
    end
  end)

  ui.map(bufnr, "n", "=", function()
    toggle_inline_diff(bufnr)
  end)

  ui.map(bufnr, "n", "cR", function()
    comment_inline_diff(bufnr)
  end)

  local init = require("sl-fugitive")
  if init.review_config then
    ui.map(bufnr, "n", "gR", function()
      require("redline").show(init.review_config)
    end)
  end

  ui.map(bufnr, "n", "d", function()
    local file = file_from_line(vim.api.nvim_get_current_line())
    if file then
      require("sl-fugitive.diff").show(file)
    end
  end)

  ui.map(bufnr, "n", "D", function()
    local file = file_from_line(vim.api.nvim_get_current_line())
    if file then
      require("sl-fugitive.diff").show_sidebyside(file)
    end
  end)

  ui.map(bufnr, "n", "x", function()
    local file = file_from_line(vim.api.nvim_get_current_line())
    local status = status_code_from_line(vim.api.nvim_get_current_line())
    if not file then
      return
    end
    if status == "?" then
      ui.warn("Use normal file deletion for untracked files")
      return
    end
    if ui.confirm("Revert " .. file .. " to parent revision?") then
      local result = require("sl-fugitive").run_vcs({ "revert", "--no-backup", file })
      if result then
        ui.info("Reverted: " .. file)
        M.refresh()
      end
    end
  end)

  ui.map(bufnr, "n", "R", function()
    M.refresh()
  end)

  ui.map(bufnr, "n", "gu", function()
    require("sl-fugitive").undo()
  end)

  ui.map(bufnr, "n", "gb", function()
    vim.cmd(ui.close_cmd())
    require("sl-fugitive").sl("bookmark")
  end)

  ui.map(bufnr, "n", "gl", function()
    vim.cmd(ui.close_cmd())
    require("sl-fugitive").sl("log")
  end)

  ui.map(bufnr, "n", "q", function()
    vim.cmd(ui.close_cmd())
  end)

  ui.map(bufnr, "n", "g?", function()
    ui.help_popup("sl-fugitive Status", {
      "Status view",
      "",
      "Actions:",
      "  <CR>     Open file",
      "  o        Open file in split",
      "  =        Toggle inline diff",
      "  cR       Add review comment from inline diff",
      "  gR       Open review buffer",
      "  d        Show diff for file",
      "  D        Side-by-side diff",
      "  x        Revert file to parent revision",
      "",
      "Views:",
      "  gb       Switch to bookmark view",
      "  gl       Switch to smartlog",
      "",
      "Other:",
      "  indented lines show copy sources",
      "  gu       Undo placeholder",
      "  R        Refresh",
      "  q        Close",
      "  g?       This help",
    })
  end)
end

function M.refresh()
  local ui = require("sl-fugitive.ui")
  local bufnr = ui.find_buf(BUF_PATTERN)
  if not bufnr then
    return
  end

  local output = get_status()
  if not output then
    return
  end

  ui.set_buf_lines(bufnr, format_lines(output))
  set_inline_diff_state(bufnr, {})
end

function M.show()
  local output = get_status()
  if not output then
    return
  end

  local lines = format_lines(output)
  local ui = require("sl-fugitive.ui")
  local bufnr = ui.find_buf(BUF_PATTERN)

  if bufnr then
    ui.set_buf_lines(bufnr, lines)
  else
    bufnr = ui.create_scratch_buffer({ name = BUF_NAME })
    ui.set_buf_lines(bufnr, lines)
  end

  set_inline_diff_state(bufnr, {})
  setup_keymaps(bufnr)

  vim.api.nvim_buf_call(bufnr, function()
    vim.cmd(
      "silent! syntax clear SlStatusHeader SlStatusModified SlStatusAdded SlStatusRemoved SlStatusUnknown SlStatusCopySource"
    )
    vim.cmd("syntax match SlStatusHeader '^#.*'")
    vim.cmd("syntax match SlStatusModified '^M .*'")
    vim.cmd("syntax match SlStatusAdded '^[ARC] .*'")
    vim.cmd("syntax match SlStatusRemoved '^! .*'")
    vim.cmd("syntax match SlStatusUnknown '^? .*'")
    vim.cmd("syntax match SlStatusCopySource '^  .*'")
    vim.cmd("highlight default link SlStatusHeader Comment")
    vim.cmd("highlight default link SlStatusModified DiffChange")
    vim.cmd("highlight default link SlStatusAdded DiffAdd")
    vim.cmd("highlight default link SlStatusRemoved DiffDelete")
    vim.cmd("highlight default link SlStatusUnknown Directory")
    vim.cmd("highlight default link SlStatusCopySource Comment")
  end)

  ui.ensure_visible(bufnr)
  for i, line in ipairs(lines) do
    if file_from_line(line) then
      pcall(vim.api.nvim_win_set_cursor, 0, { i, 0 })
      break
    end
  end
  ui.set_statusline(bufnr, "sl-status")
end

return M
