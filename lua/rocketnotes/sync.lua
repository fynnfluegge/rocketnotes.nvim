local login = require("rocketnotes.login")

---@class SyncModule
local M = {}

---@return string
M.sync = function()
	local id_token, access_token, refresh_token = login.get_tokens()
	print("Syncing RocketNotes...")
end

return M
