local M = {}

local core_browse = require("fugitive-core.views.browse")

local function strip_repo_prefix(url)
  local repo_root = require("sl-fugitive").repo_root()
  if not repo_root or not url then
    return url
  end

  local prefix = repo_root .. "/"
  if url:sub(1, #prefix) == prefix then
    return url:sub(#prefix + 1)
  end
  return url
end

local function get_paths()
  local output = require("sl-fugitive").run_vcs({ "paths" })
  if not output then
    return {}
  end

  local paths = {}
  for _, line in ipairs(vim.split(output, "\n", { plain = true })) do
    local name, url = line:match("^([^%s=]+)%s*=%s*(.-)%s*$")
    if name and url and url ~= "" then
      paths[name] = strip_repo_prefix(url)
    end
  end
  return paths
end

local function pick_remote(paths, requested)
  if requested and requested ~= "" then
    return requested, paths[requested]
  end

  for _, name in ipairs({ "origin", "default-push", "default", "upstream" }) do
    if paths[name] then
      return name, paths[name]
    end
  end

  local names = vim.tbl_keys(paths)
  table.sort(names)
  local first = names[1]
  return first, first and paths[first] or nil
end

local function relpath_for_current_buffer()
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" or vim.bo.buftype ~= "" then
    return nil
  end

  local repo_root = require("sl-fugitive").repo_root()
  if not repo_root then
    return nil
  end

  if file:sub(1, #repo_root + 1) ~= repo_root .. "/" then
    return nil
  end

  return file:sub(#repo_root + 2)
end

local node_from_line = require("sl-fugitive.ui").node_from_line

local function current_node()
  local bufnr = vim.api.nvim_get_current_buf()
  local ui = require("sl-fugitive.ui")
  local ctx = ui.buf_var(bufnr, "sl_buffer_context", {})
  if ctx.node and ctx.node ~= "" then
    return ctx.node
  end
  if ctx.rev and ctx.rev ~= "." and ctx.rev ~= "@" then
    return ctx.rev
  end

  local explicit = ui.buf_var(bufnr, "sl_changeset_node", nil)
  if explicit then
    return explicit
  end

  local inline = node_from_line(vim.api.nvim_get_current_line())
  if inline then
    return inline
  end

  local output = require("sl-fugitive").run_vcs({ "log", "-r", ".", "-T", "{node|short}\\n" })
  if not output then
    return nil
  end
  return output:gsub("%s+$", "")
end

local function current_target()
  local bufnr = vim.api.nvim_get_current_buf()
  local ctx = require("sl-fugitive.ui").buf_var(bufnr, "sl_buffer_context", {})
  local file = relpath_for_current_buffer() or ctx.file
  local rev = current_node()

  if file then
    local start_line, end_line = core_browse.line_range()
    return {
      kind = "file",
      path = file,
      rev = rev,
      line_start = start_line,
      line_end = end_line,
    }
  end

  if rev then
    return {
      kind = "commit",
      rev = rev,
    }
  end

  return nil
end

function M.browse(remote_name)
  local ui = require("sl-fugitive.ui")
  local paths = get_paths()
  local name, remote_url = pick_remote(paths, remote_name)
  if not remote_url then
    ui.err("No Sapling remote path configured")
    return
  end

  local target = current_target()
  if not target then
    ui.err("No browse target in the current buffer")
    return
  end

  -- Try custom forges first
  local url
  if target.kind == "file" then
    url = core_browse.build_custom_file_url(remote_url, target.path, target.line_start, target.line_end)
  end

  if not url then
    local remote, err = core_browse.parse_remote_url(remote_url)
    if not remote then
      ui.err(err)
      return
    end

    if target.kind == "file" then
      url = core_browse.build_file_url(
        remote,
        target.path,
        target.rev,
        target.line_start,
        target.line_end
      )
    else
      url = core_browse.build_commit_url(remote, target.rev)
    end
  end

  if not url then
    ui.err("Failed to build browse URL")
    return
  end

  core_browse.open_url(url)
  ui.info("Opened " .. (name or "remote") .. " URL")
end

return M
