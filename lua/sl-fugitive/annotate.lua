local M = {}

local function resolve_filename(filename)
  local init = require("sl-fugitive")
  local ui = require("sl-fugitive.ui")

  if filename and filename ~= "" then
    return filename
  end

  local buf_name = vim.api.nvim_buf_get_name(0)
  if buf_name == "" or vim.bo.buftype ~= "" then
    ui.err("No file to annotate")
    return nil
  end

  local root = init.repo_root()
  if root and buf_name:find(root, 1, true) == 1 then
    return buf_name:sub(#root + 2)
  end
  return buf_name
end

local function parse_annotation_line(line)
  if not line then
    return nil
  end
  -- Try verbose format: user hash date: content
  local user, node, date, content = line:match("^(%S+)%s+([0-9a-f]+)%s+(%d%d%d%d%-%d%d%-%d%d):%s?(.*)$")
  if node then
    return { user = user, node = node, date = date, content = content or "" }
  end
  -- Sapling format with -c -u: user hash: content
  local user_only
  user_only, node, content = line:match("^(%S+)%s+([0-9a-f]+):%s?(.*)$")
  if node then
    return { user = user_only, node = node, content = content or "" }
  end
  -- Bare hash: content
  node, content = line:match("^([0-9a-f]+):%s?(.*)$")
  if node then
    return { node = node, content = content or "" }
  end
  return nil
end

function M.show(filename, rev)
  local init = require("sl-fugitive")
  local ui = require("sl-fugitive.ui")

  filename = resolve_filename(filename)
  if not filename then
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

  local ann_buf = ui.create_scratch_buffer({
    name = "sl-annotate: " .. filename .. (rev and (" @ " .. rev) or ""),
    modifiable = true,
    bufhidden = "hide",
  })
  local src_buf = ui.create_scratch_buffer({
    name = filename .. (rev and (" @ " .. rev) or ""),
    modifiable = true,
    bufhidden = "hide",
  })

  vim.api.nvim_buf_set_lines(ann_buf, 0, -1, false, annotations)
  vim.api.nvim_buf_set_lines(src_buf, 0, -1, false, source_lines)
  vim.bo[ann_buf].modifiable = false
  vim.bo[src_buf].modifiable = false
  vim.bo[ann_buf].modified = false
  vim.bo[src_buf].modified = false

  local ft = vim.filetype.match({ filename = filename })
  if ft then
    vim.bo[src_buf].filetype = ft
  end

  pcall(vim.api.nvim_buf_set_var, ann_buf, "sl_annotate_nodes", line_nodes)

  vim.api.nvim_buf_call(ann_buf, function()
    vim.cmd("syntax match SlAnnotateNode '^\\x\\+'")
    vim.cmd("syntax match SlAnnotateUser '^\\x\\+\\s\\+\\S\\+'")
    vim.cmd("highlight default link SlAnnotateNode Identifier")
    vim.cmd("highlight default link SlAnnotateUser Comment")
    vim.cmd("setlocal nowrap nonumber norelativenumber")
  end)

  -- Remember original buffer so we can restore on close
  local orig_buf = vim.api.nvim_get_current_buf()
  -- Set source in current window, then open annotation as a left vsplit
  vim.api.nvim_set_current_buf(src_buf)
  vim.cmd("vsplit")
  vim.cmd("wincmd H")
  vim.api.nvim_set_current_buf(ann_buf)

  -- Size the annotation window to fit content
  local max_width = 0
  for _, ann in ipairs(annotations) do
    if #ann > max_width then max_width = #ann end
  end
  vim.api.nvim_win_set_width(0, math.min(max_width + 1, 60))

  vim.cmd("setlocal scrollbind nowrap nonumber norelativenumber")
  vim.cmd("wincmd l")
  vim.cmd("setlocal scrollbind")
  vim.cmd("syncbind")
  vim.cmd("wincmd h")

  local function current_node()
    local line_nr = vim.api.nvim_win_get_cursor(0)[1]
    local nodes = ui.buf_var(ann_buf, "sl_annotate_nodes", {})
    return nodes[line_nr]
  end

  local function close_annotate()
    local ann_win = vim.fn.bufwinid(ann_buf)
    local src_win = vim.fn.bufwinid(src_buf)
    if ann_win ~= -1 then
      pcall(vim.api.nvim_win_close, ann_win, true)
    end
    if src_win ~= -1 then
      vim.api.nvim_win_call(src_win, function()
        vim.cmd("setlocal noscrollbind")
      end)
      if vim.api.nvim_buf_is_valid(orig_buf) then
        vim.api.nvim_win_set_buf(src_win, orig_buf)
      end
      pcall(vim.api.nvim_set_current_win, src_win)
    end
    if vim.api.nvim_buf_is_valid(src_buf) then
      pcall(vim.api.nvim_buf_delete, src_buf, { force = true })
    end
  end

  ui.map(ann_buf, "n", "<CR>", function()
    local node = current_node()
    if node then
      require("sl-fugitive.log").show_changeset(node, { split_cmd = "botright split" })
    end
  end)

  ui.map(ann_buf, "n", "gR", function()
    require("sl-fugitive.review").show()
  end)

  ui.map(ann_buf, "n", "q", close_annotate)

  ui.map(ann_buf, "n", "g?", function()
    ui.help_popup("sl-fugitive Annotate", {
      "Annotate view",
      "",
      "Actions:",
      "  <CR>    Show changeset for this line",
      "  gR      Open review buffer",
      "",
      "Other:",
      "  q       Close annotation",
      "  g?      This help",
    })
  end)

  ui.set_statusline(ann_buf, "sl-annotate:" .. filename)
  ui.set_statusline(src_buf, filename)
  return true
end

return M
