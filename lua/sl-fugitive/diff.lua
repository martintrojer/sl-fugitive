local M = {}

local core_diff = require("fugitive-core.views.diff")

local function working_copy_file(filename)
  local repo_root = require("sl-fugitive").repo_root()
  if not repo_root or not filename then
    return ""
  end
  local path = repo_root .. "/" .. filename
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return ""
  end
  return table.concat(lines, "\n")
end

local function get_diff(file, rev)
  local init = require("sl-fugitive")
  local args = { "diff", "--git", "--color=always" }
  if rev and rev ~= "" then
    table.insert(args, "-c")
    table.insert(args, rev)
  end
  if file and file ~= "" then
    table.insert(args, file)
  end
  return init.run_vcs(args)
end

local function setup_diff_keymaps(bufnr, filename, review_ctx)
  local ui = require("sl-fugitive.ui")
  if ui.buf_var(bufnr, "sl_diff_keymaps_set", false) then
    return
  end
  pcall(vim.api.nvim_buf_set_var, bufnr, "sl_diff_keymaps_set", true)

  local init = require("sl-fugitive")
  if init.review_config then
    ui.map(bufnr, "n", "cR", function()
      require("redline").comment_unified_diff(init.review_config, bufnr, review_ctx)
    end)
  end

  if filename then
    ui.map(bufnr, "n", "o", function()
      vim.cmd("edit " .. vim.fn.fnameescape(filename))
    end)
  end

  ui.map(bufnr, "n", "D", function()
    if filename then
      M.show_sidebyside(filename)
      return
    end
    local files = core_diff.parse_diff_files(bufnr)
    if #files == 0 then
      ui.warn("No files found in diff")
    elseif #files == 1 then
      M.show_sidebyside(files[1])
    else
      vim.ui.select(files, { prompt = "Side-by-side diff for: " }, function(choice)
        if choice then
          M.show_sidebyside(choice)
        end
      end)
    end
  end)

  ui.setup_view_keymaps(bufnr, {
    log = function()
      vim.cmd(ui.close_cmd())
      require("sl-fugitive").sl("log")
    end,
    status = function()
      vim.cmd(ui.close_cmd())
      require("sl-fugitive.status").show()
    end,
    bookmark = function()
      vim.cmd(ui.close_cmd())
      require("sl-fugitive").sl("bookmark")
    end,
    review = init.review_config and function()
      require("redline").show(init.review_config)
    end,
    help = function()
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
    end,
  })
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

  local file_desc = filename or rev or "working copy"
  local bufname = "sl-diff: " .. file_desc

  local ctx = {
    source = rev and "commit diff" or "working copy diff",
    file = filename,
    rev = rev or ".",
    node = rev,
  }

  core_diff.show({
    get_diff = function()
      return get_diff(filename, rev)
    end,
    on_empty = function()
      require("sl-fugitive.ui").warn("No changes in " .. file_desc)
    end,
    buf_name = bufname,
    buf_pattern = "^" .. vim.pesc(bufname) .. " %[%d+%]$",
    ansi_prefix = "SlDiff",
    header = { "", "# Diff: " .. file_desc, "# Press g? for help, q to close", "" },
    statusline = "sl-diff: " .. file_desc,
    setup = function(bufnr)
      pcall(vim.api.nvim_buf_set_var, bufnr, "sl_buffer_context", ctx)
      setup_diff_keymaps(bufnr, filename, ctx)
    end,
  })
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
