-- main module file
local login = require("rocketnotes.login")
local install = require("rocketnotes.install")
local sync = require("rocketnotes.sync")

---@class Config
---@field opt string Your config option
local config = {
	opt = "Hello!",
}

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

-- M.hello = function()
-- 	return module.my_first_function(M.config.opt)
-- end

M.install = function()
	return install.install()
end

M.login = function()
	return login.login()
end

M.sync = function()
	return sync.sync()
end

return M
