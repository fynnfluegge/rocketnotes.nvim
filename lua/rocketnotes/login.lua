local utils = require("rocketnotes.utils")

---@class LoginModule
local M = {}

local function get_token_file()
	return utils.get_config_path() .. "/tokens.json"
end

local function save_tokens(id_token, access_token, refresh_token, client_id, apiUrl, domain, region, username, password)
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

local function load_tokens()
	local token_file = get_token_file()
	local file = io.open(token_file, "r")
	if file then
		local content = file:read("*all")
		file:close()
		if content == "" then
			print("Token file is empty.")
			return nil, nil, nil, nil, nil, nil, nil, nil, nil
		end
		local tokens = vim.fn.json_decode(content)
		return tokens.IdToken,
			tokens.AccessToken,
			tokens.RefreshToken,
			tokens.ClientId,
			tokens.ApiUrl,
			tokens.Domain,
			tokens.Region,
			tokens.Username,
			tokens.Password
	else
		print("Token file not found.")
		return nil, nil, nil, nil, nil, nil, nil, nil, nil
	end
end

M.get_tokens = function()
	local id_token, access_token, refresh_token, clientId, domain, apiUrl, region, username, password = load_tokens()
	if id_token and access_token and refresh_token and clientId and domain and apiUrl and region then
		return id_token, access_token, refresh_token, clientId, domain, apiUrl, region, username, password
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
			local id_token = tokens.id_token
			local access_token = tokens.access_token

			save_tokens(id_token, access_token, refresh_token, clientId, apiUrl, domain, region, username, password)
		end
	end
end

M.login = function()
	local id_token, access_token, refresh_token, clientId, api_url, domain, region, username, password = M.get_tokens()
	local domain_input = vim.fn.input(domain and string.format("Enter domain (%s): ", domain) or "Enter domain: ")
	domain = domain_input ~= "" and domain_input or domain
	local apiUrl_input = vim.fn.input(api_url and string.format("Enter API URL (%s): ", api_url) or "Enter API URL: ")
	local apiUrl = apiUrl_input ~= "" and apiUrl_input or api_url
	local region_input = vim.fn.input(region and string.format("Enter region (%s): ", region) or "Enter region: ")
	region = region_input ~= "" and region_input or region
	local clientId_input =
		vim.fn.input(clientId and string.format("Enter client ID (%s): ", clientId) or "Enter client ID: ")
	clientId = clientId_input ~= "" and clientId_input or clientId
	local username_input =
		vim.fn.input(username and string.format("Enter your username (%s): ", username) or "Enter your username: ")
	username = username_input ~= "" and username_input or username
	local password_input = vim.fn.inputsecret(
		password and string.format("Enter your password (********): ", password) or "Enter your password: "
	)
	password = password_input ~= "" and password_input or password

	local url = string.format("https://cognito-idp.%s.amazonaws.com/", region)
	local body = string.format(
		'{"AuthParameters": {"USERNAME": "%s", "PASSWORD": "%s"}, "AuthFlow": "USER_PASSWORD_AUTH", "ClientId": "%s"}',
		username,
		password,
		clientId
	)

	local temp_file = "/tmp/cognito_login_response.json"
	local curl_command = string.format(
		'curl -s -X POST %s -H "Content-Type: application/x-amz-json-1.1" -H "X-Amz-Target: AWSCognitoIdentityProviderService.InitiateAuth" -d \'%s\' -o %s',
		url,
		body,
		temp_file
	)

	local result = os.execute(curl_command)

	if result == 0 then
		local jq_command = string.format("jq . %s", temp_file)
		local handle = io.popen(jq_command)
		local response = handle:read("*all")
		handle:close()
		os.remove(temp_file)

		if response:find("NotAuthorizedException") then
			print("Login failed: Incorrect username or password.")
		else
			local auth_result = io.popen(string.format("echo '%s' | jq .AuthenticationResult", response)):read("*all")
			if auth_result and auth_result ~= "" then
				local id_token = io.popen(string.format("echo '%s' | jq -r .IdToken", auth_result)):read("*all")
				local access_token = io.popen(string.format("echo '%s' | jq -r .AccessToken", auth_result)):read("*all")
				local refresh_token = io.popen(string.format("echo '%s' | jq -r .RefreshToken", auth_result))
					:read("*all")

				print("Login successful!")
				-- print("ID Token:", id_token)
				-- print("Access Token:", access_token)
				-- print("Refresh Token:", refresh_token)

				save_tokens(id_token, access_token, refresh_token, clientId, apiUrl, domain, region, username, password)
			else
				print("Login failed:", response)
			end
		end
	else
		print("Curl command failed with result code:", result)
	end
end

return M
