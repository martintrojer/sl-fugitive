local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

local T = new_set()

local parse = require("sl-fugitive.annotate")._parse_annotation_line

-- We need to expose the parser for testing
-- For now, test via the module's show function signature
T["annotate"] = new_set()

T["annotate"]["module loads"] = function()
  local m = require("sl-fugitive.annotate")
  eq(type(m.show), "function")
end

return T
