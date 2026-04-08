local M = {}

local core_annotate = require("fugitive-core.views.annotate")

local function parse_annotation_line(line)
  if not line then
    return nil
  end
  local user, node, date, content =
    line:match("^(%S+)%s+([0-9a-f]+)%s+(%d%d%d%d%-%d%d%-%d%d):%s?(.*)$")
  if node then
    return { user = user, node = node, date = date, content = content or "" }
  end
  local user_only
  user_only, node, content = line:match("^(%S+)%s+([0-9a-f]+):%s?(.*)$")
  if node then
    return { user = user_only, node = node, content = content or "" }
  end
  node, content = line:match("^([0-9a-f]+):%s?(.*)$")
  if node then
    return { node = node, content = content or "" }
  end
  return nil
end

function M.show(filename, rev)
  local init = require("sl-fugitive")
  local ui = require("sl-fugitive.ui")

  filename = core_annotate.resolve_filename(filename, init.repo_root())
  if not filename then
    ui.err("No file to annotate")
    return false
  end

  local args = { "annotate", "-c", "-u", filename }
  if rev and rev ~= "" then
    table.insert(args, 2, "-r")
    table.insert(args, 3, rev)
  end

  local output = init.run_vcs(args)
  if not output then
    return false
  end

  local annotations = {}
  local line_nodes = {}
  local source_lines = {}

  for _, line in ipairs(vim.split(output, "\n", { plain = true })) do
    if line ~= "" then
      local parsed = parse_annotation_line(line)
      if parsed then
        local ann
        if parsed.user then
          ann = string.format("%-12s %s", parsed.node, parsed.user)
        else
          ann = parsed.node
        end
        table.insert(annotations, ann)
        table.insert(line_nodes, parsed.node)
        table.insert(source_lines, parsed.content)
      else
        table.insert(annotations, line)
        table.insert(line_nodes, nil)
        table.insert(source_lines, "")
      end
    end
  end

  local rev_suffix = rev and (" @ " .. rev) or ""
  local ann_buf, _, close = core_annotate.open_split({
    ann_name = "sl-annotate: " .. filename .. rev_suffix,
    src_name = filename .. rev_suffix,
    annotations = annotations,
    source_lines = source_lines,
    filename = filename,
    ann_syntax = function(bufnr)
      vim.api.nvim_buf_call(bufnr, function()
        vim.cmd("syntax match SlAnnotateNode '^\\x\\+'")
        vim.cmd("syntax match SlAnnotateUser '^\\x\\+\\s\\+\\S\\+'")
        vim.cmd("highlight default link SlAnnotateNode Identifier")
        vim.cmd("highlight default link SlAnnotateUser Comment")
        vim.cmd("setlocal nowrap nonumber norelativenumber")
      end)
    end,
    statusline_ann = "sl-annotate:" .. filename,
    statusline_src = filename,
  })

  pcall(vim.api.nvim_buf_set_var, ann_buf, "sl_annotate_nodes", line_nodes)

  local function current_node()
    local line_nr = vim.api.nvim_win_get_cursor(0)[1]
    local nodes = ui.buf_var(ann_buf, "sl_annotate_nodes", {})
    return nodes[line_nr]
  end

  ui.map(ann_buf, "n", "<CR>", function()
    local node = current_node()
    if node then
      require("sl-fugitive.log").show_changeset(node, { split_cmd = "botright split" })
    end
  end)

  ui.setup_view_keymaps(ann_buf, {
    close = close,
    log = function()
      close()
      require("sl-fugitive").sl("log")
    end,
    status = function()
      close()
      require("sl-fugitive").sl("status")
    end,
    bookmark = function()
      close()
      require("sl-fugitive").sl("bookmark")
    end,
    review = init.review_config and function()
      require("redline").show(init.review_config)
    end,
    help = function()
      ui.help_popup("sl-fugitive Annotate", {
        "Annotate view",
        "",
        "Actions:",
        "  <CR>    Show changeset for this line",
        "  gR      Open review buffer",
        "",
        "Views:",
        "  gb      Switch to bookmark view",
        "  gl      Switch to smartlog",
        "  gs      Switch to status view",
        "",
        "Other:",
        "  q       Close annotation",
        "  g?      This help",
      })
    end,
  })

  return true
end

return M
