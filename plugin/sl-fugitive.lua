if vim.g.loaded_sl_fugitive == 1 then
  return
end
vim.g.loaded_sl_fugitive = 1

local sl_fugitive = require("sl-fugitive")

vim.api.nvim_create_user_command("S", function(opts)
  sl_fugitive.sl(opts.args)
end, {
  nargs = "*",
  complete = function(arglead, cmdline, cursorpos)
    return sl_fugitive.complete(arglead, cmdline, cursorpos)
  end,
})

vim.api.nvim_create_user_command("SBrowse", function()
  sl_fugitive.sl("browse")
end, { nargs = 0 })
