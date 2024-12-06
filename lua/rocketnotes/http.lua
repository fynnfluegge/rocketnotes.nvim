local utils = require("rocketnotes.utils")

---@class InstallModule
local M = {}

M.getTree = function(access_token, apiUrl, region)
	local decoded_token = utils.decodeToken(access_token)
	local user_id = decoded_token.username

	local command = string.format(
		'curl -X GET "https://%s.execute-api.%s.amazonaws.com/documentTree/%s" -H "Authorization: Bearer %s"',
		apiUrl,
		region,
		user_id,
		access_token
	)

	local handle = io.popen(command)
	local result = handle:read("*a")
	handle:close()
	return result
end

M.getDocument = function(access_token, documentId, apiUrl, region)
	local command = string.format(
		'curl -X GET "https://%s.execute-api.%s.amazonaws.com/document/%s" -H "Authorization: Bearer %s"',
		apiUrl,
		region,
		documentId,
		access_token
	)

	local handle = io.popen(command)
	local result = handle:read("*a")
	handle:close()
	return result
end

M.postDocument = function(access_token, apiUrl, region, body)
	local command = string.format(
		'curl -X POST "https://%s.execute-api.%s.amazonaws.com/saveDocument" -H "Authorization: Bearer %s" -H "Content-Type: application/json" -d \'%s\'',
		apiUrl,
		region,
		access_token,
		utils.table_to_json(body)
	)

	local handle = io.popen(command)
	local result = handle:read("*a")
	handle:close()
	return result
end

return M
