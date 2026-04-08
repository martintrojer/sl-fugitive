local M = {}

local open_editor = require("fugitive-core.views.describe").open_editor

local function get_description(rev)
  local result = require("sl-fugitive").run_vcs({ "log", "-r", rev, "-T", "{desc}\\n" })
  return result and result:gsub("%s+$", "") or ""
end

local function setup_keymaps(bufnr, discard_and_close)
  local ui = require("sl-fugitive.ui")

  ui.setup_view_keymaps(bufnr, {
    close = discard_and_close,
    log = function()
      discard_and_close()
      require("sl-fugitive").sl("log")
    end,
    status = function()
      discard_and_close()
      require("sl-fugitive").sl("status")
    end,
    bookmark = function()
      discard_and_close()
      require("sl-fugitive").sl("bookmark")
    end,
    help = function()
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
    end,
  })
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
  end, {
    setup_keymaps = setup_keymaps,
    statusline = "sl-describe:" .. rev,
  })
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
  end, {
    setup_keymaps = setup_keymaps,
    statusline = "sl-commit",
  })
end

return M
