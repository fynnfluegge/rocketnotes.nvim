-- main module file
local login = require("rocketnotes.login")
local sync = require("rocketnotes.sync")

---@class Config
---@field opt string Your config option
local config = {}

---@class MyModule
local M = {}

---@type Config
M.config = config

---@param args Config?
-- you can define your setup function here. Usually configurations can be merged, accepting outside params and
-- you can also put some validation here for those.
M.setup = function(args)
	M.config = vim.tbl_deep_extend("force", M.config, args or {})
end

M.login = function()
	return login.login()
end

M.sync = function()
	return sync.sync()
end

return M
