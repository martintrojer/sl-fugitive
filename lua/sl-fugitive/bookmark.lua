local M = {}

local core_list = require("fugitive-core.views.list")

local BUF_PATTERN = "sl%-bookmarks"
local BUF_NAME = "sl-bookmarks"

local function get_bookmarks()
  return require("sl-fugitive").run_vcs({ "bookmarks" })
end

local function bookmark_from_line(line)
  if not line or line == "" or line:match("^%s*#") then
    return nil
  end
  return line:match("^%s*%*?%s*([%w%._/@-]+)%s+[0-9a-f]+%s*$")
end

local node_from_line = require("sl-fugitive.ui").node_from_line

local function run_and_refresh(args, msg)
  local result = require("sl-fugitive").run_vcs(args)
  if result then
    if msg then
      require("sl-fugitive.ui").info(msg)
    end
    M.refresh()
    require("sl-fugitive").refresh_views()
  end
end

local function format_lines(output)
  local lines = {
    "",
    "# sl Bookmarks",
    "# Press g? for help",
    "",
  }
  local saw = false
  for _, line in ipairs(vim.split(output or "", "\n", { plain = true })) do
    if line ~= "" then
      saw = true
      table.insert(lines, line)
    end
  end
  if not saw then
    table.insert(lines, "no bookmarks set")
  end
  return lines
end

local function setup_keymaps(bufnr)
  local ui = require("sl-fugitive.ui")
  if ui.buf_var(bufnr, "sl_bookmark_keymaps_set", false) then
    return
  end
  pcall(vim.api.nvim_buf_set_var, bufnr, "sl_bookmark_keymaps_set", true)

  ui.map(bufnr, "n", "c", function()
    vim.ui.input({ prompt = "New bookmark name: " }, function(name)
      if not name or name == "" then
        return
      end
      vim.ui.input({ prompt = "At revision (default .): " }, function(rev)
        if not rev or rev == "" then
          rev = "."
        end
        run_and_refresh({ "bookmark", name, "-r", rev }, "Created bookmark: " .. name)
      end)
    end)
  end)

  ui.map(bufnr, "n", "d", function()
    local name = bookmark_from_line(vim.api.nvim_get_current_line())
    if name and ui.confirm("Delete bookmark '" .. name .. "'?") then
      run_and_refresh({ "bookmark", "-d", name }, "Deleted bookmark: " .. name)
    end
  end)

  ui.map(bufnr, "n", "m", function()
    local name = bookmark_from_line(vim.api.nvim_get_current_line())
    if not name then
      return
    end
    vim.ui.input({ prompt = "Move '" .. name .. "' to revision: " }, function(rev)
      if rev and rev ~= "" then
        run_and_refresh({ "bookmark", name, "-r", rev }, "Moved " .. name .. " -> " .. rev)
      end
    end)
  end)

  ui.map(bufnr, "n", "r", function()
    local name = bookmark_from_line(vim.api.nvim_get_current_line())
    if not name then
      return
    end
    vim.ui.input({ prompt = "Rename '" .. name .. "' to: " }, function(new_name)
      if new_name and new_name ~= "" then
        run_and_refresh(
          { "bookmark", "-m", name, new_name },
          "Renamed " .. name .. " -> " .. new_name
        )
      end
    end)
  end)

  ui.map(bufnr, "n", "go", function()
    local name = bookmark_from_line(vim.api.nvim_get_current_line())
    local node = node_from_line(vim.api.nvim_get_current_line())
    local target = name or node
    if target then
      run_and_refresh({ "goto", target }, "Goto " .. target)
    end
  end)

  ui.map(bufnr, "n", "p", function()
    local name = bookmark_from_line(vim.api.nvim_get_current_line())
    if not name then
      return
    end
    vim.ui.input(
      { prompt = "Push bookmark '" .. name .. "' to remote name: " },
      function(remote_name)
        if remote_name and remote_name ~= "" then
          run_and_refresh(
            { "push", "--to", remote_name, "--create" },
            "Pushed bookmark to " .. remote_name
          )
        end
      end
    )
  end)

  ui.map(bufnr, "n", "R", function()
    M.refresh()
  end)

  ui.map(bufnr, "n", "gl", function()
    vim.cmd(ui.close_cmd())
    require("sl-fugitive.log").show()
  end)

  ui.map(bufnr, "n", "gs", function()
    vim.cmd(ui.close_cmd())
    require("sl-fugitive.status").show()
  end)

  local init = require("sl-fugitive")
  if init.review_config then
    ui.map(bufnr, "n", "gR", function()
      require("redline").show(init.review_config)
    end)
  end

  ui.map(bufnr, "n", "q", function()
    vim.cmd(ui.close_cmd())
  end)

  ui.map(bufnr, "n", "g?", function()
    ui.help_popup("sl-fugitive Bookmarks", {
      "Bookmarks view",
      "",
      "Actions:",
      "  c       Create bookmark",
      "  d       Delete bookmark",
      "  m       Move bookmark to revision",
      "  r       Rename bookmark",
      "  go      Goto bookmark commit",
      "  p       Push to remote bookmark",
      "",
      "Views:",
      "  gl      Switch to smartlog",
      "  gs      Switch to status view",
      "  gR      Open review buffer",
      "",
      "Other:",
      "  R       Refresh",
      "  q       Close",
      "  g?      This help",
    })
  end)
end

function M.refresh()
  core_list.refresh({
    get_data = get_bookmarks,
    format_lines = format_lines,
    buf_pattern = BUF_PATTERN,
  })
end

function M.show()
  core_list.show({
    get_data = get_bookmarks,
    format_lines = format_lines,
    buf_pattern = BUF_PATTERN,
    buf_name = BUF_NAME,
    statusline = "sl-bookmarks",
    first_item = bookmark_from_line,
    setup = function(bufnr)
      vim.api.nvim_buf_call(bufnr, function()
        vim.cmd("syntax match SlBookmarkHeader '^#.*'")
        vim.cmd("syntax match SlBookmarkActive '^ \\* .*'")
        vim.cmd("syntax match SlBookmarkName '^\\s*\\*\\?\\s*[[:alnum:]_.\\/-]\\+\\s\\+'")
        vim.cmd("highlight default link SlBookmarkHeader Comment")
        vim.cmd("highlight default link SlBookmarkActive Identifier")
        vim.cmd("highlight default link SlBookmarkName Identifier")
      end)
      setup_keymaps(bufnr)
    end,
  })
end

return M
