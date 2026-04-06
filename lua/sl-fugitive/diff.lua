local M = {}

local ansi = require("sl-fugitive.ansi")

local function set_review_context(bufnr, ctx)
  pcall(vim.api.nvim_buf_set_var, bufnr, "jj_review_context", ctx)
end

local function working_copy_file(filename)
  local repo_root = require("sl-fugitive").repo_root()
  if not repo_root or not filename then
    return ""
  end
  local path = repo_root .. "/" .. filename
  local lines = vim.fn.readfile(path, "", 1)
  if vim.v.shell_error ~= 0 then
    return ""
  end
  return table.concat(lines, "\n")
end

local function get_diff(file, rev)
  local init = require("sl-fugitive")
  local args = { "diff", "--git" }
  if rev and rev ~= "" then
    table.insert(args, "-c")
    table.insert(args, rev)
  end
  if file and file ~= "" then
    table.insert(args, file)
  end
  return init.run_vcs(args)
end

local function setup_diff_keymaps(bufnr, filename)
  local ui = require("sl-fugitive.ui")
  if ui.buf_var(bufnr, "sl_diff_keymaps_set", false) then
    return
  end
  pcall(vim.api.nvim_buf_set_var, bufnr, "sl_diff_keymaps_set", true)

  ui.map(bufnr, "n", "q", function()
    vim.cmd(ui.close_cmd())
  end)

  ui.map(bufnr, "n", "cR", function()
    require("sl-fugitive.review").comment_current_line(bufnr)
  end)

  ui.map(bufnr, "n", "gR", function()
    require("sl-fugitive.review").show()
  end)

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

  if filename then
    ui.map(bufnr, "n", "o", function()
      vim.cmd("edit " .. vim.fn.fnameescape(filename))
    end)

    ui.map(bufnr, "n", "D", function()
      M.show_sidebyside(filename)
    end)
  end

  ui.map(bufnr, "n", "g?", function()
    ui.help_popup("sl-fugitive Diff", {
      "Diff view",
      "",
      "Navigation:",
      "  [c      Previous change",
      "  ]c      Next change",
      "",
      "Actions:",
      "  cR      Add review comment",
      "  gR      Open review buffer",
      "  o       Open file in editor",
      "  D       Side-by-side diff",
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

function M.show(opts)
  if type(opts) ~= "table" then
    opts = { file = opts }
  end

  local filename = opts.file
  local rev = opts.rev

  if not filename or filename == "" then
    local buf_name = vim.api.nvim_buf_get_name(0)
    if buf_name ~= "" and vim.bo.buftype == "" then
      local repo_root = require("sl-fugitive").repo_root()
      if repo_root and buf_name:find(repo_root, 1, true) == 1 then
        filename = buf_name:sub(#repo_root + 2)
      end
    end
  end

  local output = get_diff(filename, rev)
  if not output then
    return
  end
  if output:match("^%s*$") then
    require("sl-fugitive.ui").warn("No changes in " .. (filename or rev or "working copy"))
    return
  end

  local ui = require("sl-fugitive.ui")
  local file_desc = filename or rev or "working copy"
  local header = {
    "",
    "# Diff: " .. file_desc,
    "# Press g? for help, q to close",
    "",
  }
  local bufname = "sl-diff: " .. file_desc
  local bufnr = ui.find_buf("^" .. vim.pesc(bufname) .. " %[%d+%]$")

  if bufnr then
    ansi.update_colored_buffer(bufnr, output, header, { prefix = "SlDiff" })
  else
    bufnr = ansi.create_colored_buffer(output, bufname, header, { prefix = "SlDiff" })
  end

  set_review_context(bufnr, {
    kind = "unified_diff",
    source = rev and "commit diff" or "working copy diff",
    file = filename,
    rev = rev or ".",
    node = rev,
  })
  setup_diff_keymaps(bufnr, filename)
  ui.ensure_visible(bufnr)
  ui.set_statusline(bufnr, "sl-diff: " .. file_desc)
end

function M.show_sidebyside(filename)
  if not filename then
    require("sl-fugitive.ui").err("Side-by-side diff requires a filename")
    return
  end

  local ui = require("sl-fugitive.ui")
  local parent = ui.file_at_rev(filename, ".")
  local current = working_copy_file(filename)
  local left, right = ui.open_sidebyside(
    parent,
    filename .. " (parent .)",
    current,
    filename .. " (working copy)",
    filename
  )

  for _, buf in ipairs({ left, right }) do
    ui.map(buf, "n", "o", function()
      vim.cmd("edit " .. vim.fn.fnameescape(filename))
    end)
  end
end

return M
