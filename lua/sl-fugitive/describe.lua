local M = {}

local function get_description(rev)
  local init = require("sl-fugitive")
  local result = init.run_vcs({ "log", "-r", rev, "-T", "{desc}\\n" })
  return result and result:gsub("%s+$", "") or ""
end

local function open_editor(buffer_name, initial_text, help_lines, save_fn)
  local ui = require("sl-fugitive.ui")

  local bufnr = vim.api.nvim_create_buf(false, false)
  vim.bo[bufnr].buftype = "acwrite"
  vim.bo[bufnr].filetype = "gitcommit"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].bufhidden = "hide"
  pcall(vim.api.nvim_buf_set_name, bufnr, buffer_name)

  local lines = {}
  for _, line in ipairs(help_lines) do
    table.insert(lines, line)
  end
  table.insert(lines, "")
  for _, line in ipairs(vim.split(initial_text or "", "\n", { plain = true })) do
    table.insert(lines, line)
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = bufnr,
    callback = function()
      local content = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local filtered = {}
      for _, line in ipairs(content) do
        if not line:match("^%s*#") then
          table.insert(filtered, line)
        end
      end

      local text = table.concat(filtered, "\n"):gsub("^%s+", ""):gsub("%s+$", "")
      if save_fn(text) then
        vim.bo[bufnr].modified = false
        vim.cmd(ui.close_cmd())
      end
    end,
  })

  ui.map(bufnr, "n", "q", function()
    vim.bo[bufnr].modified = false
    vim.cmd(ui.close_cmd())
  end)

  ui.map(bufnr, "n", "gl", function()
    vim.bo[bufnr].modified = false
    vim.cmd(ui.close_cmd())
    require("sl-fugitive").sl("log")
  end)

  ui.map(bufnr, "n", "gs", function()
    vim.bo[bufnr].modified = false
    vim.cmd(ui.close_cmd())
    require("sl-fugitive").sl("status")
  end)

  ui.map(bufnr, "n", "gb", function()
    vim.bo[bufnr].modified = false
    vim.cmd(ui.close_cmd())
    require("sl-fugitive").sl("bookmark")
  end)

  ui.map(bufnr, "n", "g?", function()
    ui.help_popup("sl-fugitive Editor", {
      "Sapling editor buffer",
      "",
      "Views:",
      "  gb      Switch to bookmark view",
      "  gl      Switch to smartlog",
      "  gs      Switch to status view",
      "",
      "Other:",
      "  :w      Save and run Sapling command",
      "  q       Close without saving",
      "  g?      This help",
    })
  end)

  ui.open_pane()
  vim.api.nvim_win_set_buf(0, bufnr)
  vim.api.nvim_win_set_cursor(0, { #help_lines + 2, 0 })
  ui.set_statusline(bufnr, buffer_name)

  return bufnr
end

function M.describe(rev)
  rev = rev and rev ~= "" and rev or "."

  local description = get_description(rev)
  open_editor("sl-describe:" .. rev, description, {
    "# Edit Sapling commit message for " .. rev,
    "# Lines starting with # are ignored",
    "# :w to save, q to abort",
  }, function(text)
    local result = require("sl-fugitive").run_vcs({ "metaedit", "-r", rev, "-m", text })
    if result then
      require("sl-fugitive.ui").info("Updated commit message for " .. rev)
      require("sl-fugitive").refresh_views()
      return true
    end
    return false
  end)
end

function M.commit()
  open_editor("sl-commit", "", {
    "# Create a new Sapling commit from the current working copy",
    "# Lines starting with # are ignored",
    "# :w to save, q to abort",
  }, function(text)
    if text == "" then
      require("sl-fugitive.ui").warn("Commit message cannot be empty")
      return false
    end
    local result = require("sl-fugitive").run_vcs({ "commit", "-m", text })
    if result then
      require("sl-fugitive.ui").info("Created commit: " .. text:match("^[^\n]*"))
      require("sl-fugitive").refresh_views()
      return true
    end
    return false
  end)
end

return M
