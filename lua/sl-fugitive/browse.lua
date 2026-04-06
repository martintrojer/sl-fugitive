local M = {}

local init = require("sl-fugitive")

local function strip_repo_prefix(url)
  local repo_root = init.repo_root()
  if not repo_root or not url then
    return url
  end

  local prefix = repo_root .. "/"
  if url:sub(1, #prefix) == prefix then
    return url:sub(#prefix + 1)
  end
  return url
end

function M.parse_remote_url(url)
  if not url or url == "" then
    return nil, "Empty remote URL"
  end

  url = strip_repo_prefix(url)

  local host, owner, repo = url:match("^git@([^:]+):([^/]+)/([^%.]+)%.?git?$")
  if host and owner and repo then
    return {
      host = host,
      owner = owner,
      repo = repo,
      web_base = string.format("https://%s/%s/%s", host, owner, repo),
    }
  end

  host, owner, repo = url:match("^ssh://git@([^/]+)/([^/]+)/([^%./]+)%.?git?/?$")
  if host and owner and repo then
    return {
      host = host,
      owner = owner,
      repo = repo,
      web_base = string.format("https://%s/%s/%s", host, owner, repo),
    }
  end

  local scheme
  scheme, host, owner, repo = url:match("^(https?)://([^/]+)/([^/]+)/([^/]+)$")
  if host and owner and repo then
    repo = repo:gsub("%.git$", "")
    repo = repo:gsub("/$", "")
    return {
      host = host,
      owner = owner,
      repo = repo,
      web_base = string.format("%s://%s/%s/%s", scheme, host, owner, repo),
    }
  end

  return nil, "Unsupported or unrecognized remote URL: " .. url
end

local function get_paths()
  local output = init.run_vcs({ "paths" })
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

local function line_range()
  local start_line
  local end_line
  local mode = vim.fn.mode()

  if mode:match("^[vV\22]") then
    local s = vim.fn.getpos("<")[2]
    local e = vim.fn.getpos(">")[2]
    if s and e then
      start_line = math.min(s, e)
      end_line = math.max(s, e)
    end
  else
    start_line = vim.fn.line(".")
  end

  return start_line, end_line
end

local function relpath_for_current_buffer()
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" or vim.bo.buftype ~= "" then
    return nil
  end

  local repo_root = init.repo_root()
  if not repo_root then
    return nil
  end

  if file:sub(1, #repo_root + 1) ~= repo_root .. "/" then
    return nil
  end

  return file:sub(#repo_root + 2)
end

local function node_from_line(line)
  if not line then
    return nil
  end
  return line:match("%f[%x]([0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f])%f[^%x]")
end

local function current_node()
  local bufnr = vim.api.nvim_get_current_buf()
  local ctx = require("sl-fugitive.ui").buf_var(bufnr, "jj_review_context", {})
  if ctx.node and ctx.node ~= "" then
    return ctx.node
  end
  if ctx.rev and ctx.rev ~= "." and ctx.rev ~= "@" then
    return ctx.rev
  end

  local explicit = require("sl-fugitive.ui").buf_var(bufnr, "sl_changeset_node", nil)
  if explicit then
    return explicit
  end

  local inline = node_from_line(vim.api.nvim_get_current_line())
  if inline then
    return inline
  end

  local output = init.run_vcs({ "log", "-r", ".", "-T", "{node|short}\\n" })
  if not output then
    return nil
  end
  return output:gsub("%s+$", "")
end

local function current_target()
  local bufnr = vim.api.nvim_get_current_buf()
  local ctx = require("sl-fugitive.ui").buf_var(bufnr, "jj_review_context", {})
  local file = relpath_for_current_buffer() or ctx.file
  local rev = current_node()

  if file then
    local start_line, end_line = line_range()
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

function M.build_file_url(remote, path, rev, line_start, line_end)
  if not remote or not remote.web_base or not path or not rev then
    return nil, "Missing parameters to build file URL"
  end

  local encoded_path = path:gsub(" ", "%%20")
  local url

  if remote.host:match("gitlab%.com$") then
    url = string.format("%s/-/blob/%s/%s", remote.web_base, rev, encoded_path)
    if line_start and line_end and line_start ~= line_end then
      url = string.format("%s#L%d-%d", url, line_start, line_end)
    elseif line_start then
      url = string.format("%s#L%d", url, line_start)
    end
    return url
  end

  url = string.format("%s/blob/%s/%s", remote.web_base, rev, encoded_path)
  if line_start and line_end and line_start ~= line_end then
    url = string.format("%s#L%d-L%d", url, line_start, line_end)
  elseif line_start then
    url = string.format("%s#L%d", url, line_start)
  end
  return url
end

function M.build_commit_url(remote, rev)
  if not remote or not remote.web_base or not rev then
    return nil, "Missing parameters to build commit URL"
  end

  if remote.host:match("gitlab%.com$") then
    return string.format("%s/-/commit/%s", remote.web_base, rev)
  end
  return string.format("%s/commit/%s", remote.web_base, rev)
end

local function open_url(url)
  if vim.ui and vim.ui.open then
    local ok = vim.ui.open(url)
    if ok ~= nil then
      return ok
    end
  end

  if vim.fn.has("mac") == 1 then
    vim.fn.jobstart({ "open", url }, { detach = true })
    return true
  end
  if vim.fn.executable("xdg-open") == 1 then
    vim.fn.jobstart({ "xdg-open", url }, { detach = true })
    return true
  end
  if vim.fn.has("win32") == 1 then
    vim.fn.jobstart({ "cmd", "/c", "start", url }, { detach = true })
    return true
  end

  vim.fn.setreg("+", url)
  vim.notify("Browse URL copied to clipboard: " .. url, vim.log.levels.INFO)
  return true
end

function M.browse(remote_name)
  local ui = require("sl-fugitive.ui")
  local paths = get_paths()
  local name, remote_url = pick_remote(paths, remote_name)
  if not remote_url then
    ui.err("No Sapling remote path configured")
    return
  end

  local remote, err = M.parse_remote_url(remote_url)
  if not remote then
    ui.err(err)
    return
  end

  local target = current_target()
  if not target then
    ui.err("No browse target in the current buffer")
    return
  end

  local url
  if target.kind == "file" then
    url = M.build_file_url(remote, target.path, target.rev, target.line_start, target.line_end)
  else
    url = M.build_commit_url(remote, target.rev)
  end

  if not url then
    ui.err("Failed to build browse URL")
    return
  end

  open_url(url)
  ui.info("Opened " .. (name or "remote") .. " URL")
end

return M
