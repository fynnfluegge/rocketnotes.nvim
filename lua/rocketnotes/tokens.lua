local utils = require("rocketnotes.utils")

---@class TokensModule
local M = {}

local function get_token_file()
	return utils.get_config_path() .. "/tokens.json"
end

M.save_tokens = function(id_token, access_token, refresh_token, client_id, apiUrl, domain, region, username, password)
	local token_file = get_token_file()
	local file = io.open(token_file, "w")
	if file then
		file:write(
			string.format(
				'{"IdToken": "%s", "AccessToken": "%s", "RefreshToken": "%s", "ClientId": "%s", "ApiUrl": "%s", "Domain": "%s", "Region": "%s", "Username": "%s", "Password": "%s"}',
				id_token:gsub("\n", ""),
				access_token:gsub("\n", ""),
				refresh_token:gsub("\n", ""),
				client_id:gsub("\n", ""),
				apiUrl:gsub("\n", ""),
				domain:gsub("\n", ""),
				region:gsub("\n", ""),
				username:gsub("\n", ""),
				password:gsub("\n", "")
			)
		)
		file:close()
	else
		print("Failed to open token file for writing.")
	end
end

M.get_tokens = function()
	local token_file = get_token_file()
	local file = io.open(token_file, "r")
	if not file then
		print("Token file not found.")
		return nil, nil, nil, nil, nil, nil, nil, nil
	end

	local content = file:read("*all")
	file:close()

	if content == "" then
		print("Token file is empty.")
		return nil, nil, nil, nil, nil, nil, nil, nil
	end

	local tokens = vim.fn.json_decode(content)
	local id_token = tokens.IdToken
	local access_token = tokens.AccessToken
	local refresh_token = tokens.RefreshToken
	local clientId = tokens.ClientId
	local apiUrl = tokens.ApiUrl
	local domain = tokens.Domain
	local region = tokens.Region
	local username = tokens.Username
	local password = tokens.Password

	if id_token and access_token and refresh_token and clientId and apiUrl and domain and region then
		return id_token, access_token, refresh_token, clientId, apiUrl, domain, region, username, password
	else
		return nil, nil, nil, nil, nil, nil, nil, nil
	end
end

M.refresh_token = function()
	local id_token, access_token, refresh_token, clientId, apiUrl, domain, region, username, password = M.get_tokens()
	local temp_file = "/tmp/cognito_login_response.json"
	local url = string.format("https://%s.auth.%s.amazoncognito.com/oauth2/token", domain, region)
	local body = string.format("grant_type=refresh_token&refresh_token=%s&client_id=%s", refresh_token, clientId)
	local curl_command = string.format(
		"curl -s -X POST %s -H \"Content-Type: application/x-www-form-urlencoded\" -d '%s' -o %s",
		url,
		body,
		temp_file
	)
	local result = os.execute(curl_command)

	if result == 0 then
		print("Refreshing tokens...")
		local jq_command = string.format("jq . %s", temp_file)
		local handle = io.popen(jq_command)
		local response = handle:read("*all")
		handle:close()
		os.remove(temp_file)

		if response:find("NotAuthorizedException") then
			print("Refresh token expired.")
			-- TODO login again
		else
			local tokens = vim.fn.json_decode(response)
			id_token = tokens.id_token
			access_token = tokens.access_token

			M.save_tokens(id_token, access_token, refresh_token, clientId, apiUrl, domain, region, username, password)
		end
	end
end

return M
