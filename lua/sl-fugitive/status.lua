local M = {}

local core_list = require("fugitive-core.views.list")

local BUF_PATTERN = "sl%-status"
local BUF_NAME = "sl-status"
local INLINE_VAR = "sl_status_inline_diffs"

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

local function supports_diff(code)
  return code == "M" or code == "A" or code == "R"
end

local function toggle_inline_diff(bufnr)
  local ui = require("sl-fugitive.ui")
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line_nr = cursor[1]
  if core_list.collapse_inline_at_cursor(bufnr, INLINE_VAR) then
    return
  end

  local line = vim.api.nvim_buf_get_lines(bufnr, line_nr - 1, line_nr, false)[1]
  local file = file_from_line(line)
  local status = status_code_from_line(line)
  if not file then
    return
  end

  -- Check if this filename already has an expanded diff — collapse it
  local state = core_list.get_inline_state(bufnr, INLINE_VAR)
  for i, item in ipairs(state) do
    if item.start_line == line_nr + 1 then
      vim.bo[bufnr].modifiable = true
      vim.api.nvim_buf_set_lines(bufnr, item.start_line - 1, item.end_line, false, {})
      vim.bo[bufnr].modifiable = false
      vim.bo[bufnr].modified = false

      local removed = item.end_line - item.start_line + 1
      table.remove(state, i)
      core_list.shift_inline_ranges(state, item.start_line - 1, -removed)
      core_list.set_inline_state(bufnr, INLINE_VAR, state)
      return
    end
  end

  if not supports_diff(status) then
    ui.warn("Inline diff is only available for tracked changes")
    return
  end

  local diff_output = require("sl-fugitive").run_vcs({ "diff", "--git", "--color=always", file })
  if not diff_output or diff_output:match("^%s*$") then
    ui.warn("No diff available for " .. file)
    return
  end

  local ansi = require("fugitive-core.ansi")
  local diff_lines = {}
  local line_highlights = {}
  for _, dl in ipairs(vim.split(diff_output, "\n", { plain = true })) do
    if dl ~= "" then
      local clean, highlights = ansi.parse_ansi_colors(dl)
      table.insert(diff_lines, "    " .. clean)
      table.insert(line_highlights, highlights)
    end
  end

  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, line_nr, line_nr, false, diff_lines)
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].modified = false

  core_list.shift_inline_ranges(state, line_nr, #diff_lines)
  table.insert(state, {
    start_line = line_nr + 1,
    end_line = line_nr + #diff_lines,
    file = file,
    rev = ".",
  })
  core_list.set_inline_state(bufnr, INLINE_VAR, state)

  ansi.setup_diff_highlighting(bufnr, nil, { prefix = "SlStatus" })
  for i, highlights in ipairs(line_highlights) do
    local buf_line = line_nr + i - 1
    for _, hl in ipairs(highlights) do
      local group = hl.group
      if group == "Green" or group == "LightGreen" then
        group = "SlStatusAdd"
      elseif group == "Red" or group == "LightRed" then
        group = "SlStatusDelete"
      elseif group == "Yellow" or group == "LightYellow" then
        group = "SlStatusChange"
      end
      pcall(
        vim.api.nvim_buf_add_highlight,
        bufnr,
        ansi.ns,
        group,
        buf_line,
        hl.col_start + 4,
        hl.col_end + 4
      )
    end
  end
end

local function comment_inline_diff(bufnr)
  local init = require("sl-fugitive")
  if not init.review_config then
    require("sl-fugitive.ui").warn("Review not available (redline.nvim not installed)")
    return
  end
  local ranges = core_list.get_inline_state(bufnr, INLINE_VAR)
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

local function file_at_cursor(bufnr)
  return file_from_line(vim.api.nvim_get_current_line())
    or core_list.file_from_inline_state(bufnr, INLINE_VAR)
end

local function setup_keymaps(bufnr)
  local ui = require("sl-fugitive.ui")
  if ui.buf_var(bufnr, "sl_status_keymaps_set", false) then
    return
  end
  pcall(vim.api.nvim_buf_set_var, bufnr, "sl_status_keymaps_set", true)

  ui.map(bufnr, "n", "<CR>", function()
    local file = file_at_cursor(bufnr)
    if file then
      vim.cmd(ui.close_cmd())
      vim.cmd("edit " .. vim.fn.fnameescape(file))
    end
  end)

  ui.map(bufnr, "n", "o", function()
    local file = file_at_cursor(bufnr)
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

  ui.map(bufnr, "n", "d", function()
    local file = file_at_cursor(bufnr)
    if file then
      require("sl-fugitive.diff").show(file)
    end
  end)

  ui.map(bufnr, "n", "D", function()
    local file = file_at_cursor(bufnr)
    if file then
      require("sl-fugitive.diff").show_sidebyside(file)
    end
  end)

  ui.map(bufnr, "n", "x", function()
    local file = file_at_cursor(bufnr)
    if not file then
      return
    end
    local status = status_code_from_line(vim.api.nvim_get_current_line())
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

  local init = require("sl-fugitive")
  ui.setup_view_keymaps(bufnr, {
    log = function()
      vim.cmd(ui.close_cmd())
      init.sl("log")
    end,
    bookmark = function()
      vim.cmd(ui.close_cmd())
      init.sl("bookmark")
    end,
    review = init.review_config and function()
      require("redline").show(init.review_config)
    end,
    refresh = function()
      M.refresh()
    end,
    help = function()
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
        "  R        Refresh",
        "  q        Close",
        "  g?       This help",
      })
    end,
  })
end

function M.refresh()
  core_list.refresh({
    get_data = get_status,
    format_lines = format_lines,
    buf_pattern = BUF_PATTERN,
    on_refresh = function(bufnr)
      core_list.set_inline_state(bufnr, INLINE_VAR, {})
    end,
  })
end

function M.show()
  core_list.show({
    get_data = get_status,
    format_lines = format_lines,
    buf_pattern = BUF_PATTERN,
    buf_name = BUF_NAME,
    statusline = "sl-status",
    first_item = file_from_line,
    setup = function(bufnr)
      core_list.set_inline_state(bufnr, INLINE_VAR, {})
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
    end,
  })
end

return M
