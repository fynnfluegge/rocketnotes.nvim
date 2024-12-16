local utils = require("rocketnotes.utils")

---@class InstallModule
local M = {}

M.get_tree = function(access_token, apiUrl)
	local decoded_token = utils.decode_token(access_token)
	local user_id = decoded_token.username

	local command = string.format(
		'curl -s -X GET "%s/documentTree/%s" -H "Authorization: Bearer %s"',
		apiUrl,
		user_id,
		access_token
	)

	local handle = io.popen(command)
	local result = handle:read("*a")
	handle:close()
	return result
end

M.get_document = function(access_token, documentId, apiUrl)
	local command =
		string.format('curl -s -X GET "%s/document/%s" -H "Authorization: Bearer %s"', apiUrl, documentId, access_token)

	local handle = io.popen(command)
	local result = handle:read("*a")
	handle:close()
	return result
end

M.post_document = function(access_token, apiUrl, body)
	local command = string.format(
		'curl -s -X POST "%s/saveDocument" -H "Authorization: Bearer %s" -H "Content-Type: application/json" -d \'%s\'',
		apiUrl,
		access_token,
		utils.table_to_json(body)
	)

	local handle = io.popen(command)
	local result = handle:read("*a")
	handle:close()
	return result
end

return M
