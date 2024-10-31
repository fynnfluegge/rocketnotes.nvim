local login = require("rocketnotes.login")

---@class InstallModule
local M = {}

---@return string
M.install = function()
	local id_token, access_token, refresh_token = login.get_tokens()
	print("Installing RocketNotes...")

	local jq_command = string.format(
		"echo '%s' | jq -R 'split(\".\") | select(length > 0) | .[1] | @base64d | fromjson'",
		access_token
	)

	-- Execute the command and capture the output
	local handle = io.popen(jq_command) -- Open a pipe to the command
	local result = handle:read("*a") -- Read the output
	if string.sub(result, -1) == "\n" then
		result = string.sub(result, 1, -2) -- Remove the last character if it's a line break
	end
	local decoded_token = vim.fn.json_decode(result)
	local user_id = decoded_token.username
	handle:close() -- Close the pipe

	local command = string.format(
		'curl -X GET "https://<APIURL>.execute-api.eu-central-1.amazonaws.com/documentTree/%s" -H "Authorization: Bearer %s"',
		user_id,
		access_token
	)

	-- Capture the output
	local handle = io.popen(command)
	local result = handle:read("*a") -- read all output
	handle:close()
end

return M
