---@class LoginModule
local M = {}

-- Function to create a directory if it does not exist
local function create_directory_if_not_exists(dir)
	local command = 'mkdir -p "' .. dir .. '"'
	os.execute(command)
	return dir
end

local function get_token_file_path()
	local home = os.getenv("HOME") or os.getenv("USERPROFILE")
	local token_file

	if package.config:sub(1, 1) == "\\" then
		-- Windows
		local dir = create_directory_if_not_exists(home .. "\\AppData\\Local\\rocketnotes")
		token_file = dir .. "/tokens.json"
	else
		-- macOS and Linux
		local dir = create_directory_if_not_exists(home .. "/Library/Application Support/rocketnotes")
		token_file = dir .. "/tokens.json"
	end

	return token_file
end

local function save_tokens(id_token, access_token, refresh_token)
	local token_file = get_token_file_path()
	local file = io.open(token_file, "w")
	if file then
		file:write(
			string.format(
				'{"IdToken": "%s", "AccessToken": "%s", "RefreshToken": "%s"}',
				id_token:gsub("\n", ""),
				access_token:gsub("\n", ""),
				refresh_token:gsub("\n", "")
			)
		)
		file:close()
	else
		print("Failed to open token file for writing.")
	end
end

local function load_tokens()
	local token_file = get_token_file_path()
	local file = io.open(token_file, "r")
	if file then
		local content = file:read("*all")
		file:close()
		print("Token file found.")
		local tokens = vim.fn.json_decode(content)
		return tokens.IdToken, tokens.AccessToken, tokens.RefreshToken
	else
		print("Token file not found.")
		return nil, nil, nil
	end
end

M.get_tokens = function()
	local id_token, access_token, refresh_token = load_tokens()
	if id_token and access_token and refresh_token then
		return id_token, access_token, refresh_token
	else
		print("No tokens found.")
		return nil, nil, nil, nil
	end
end

M.login = function()
	local clientId = vim.fn.input("Enter your clientId: ")
	local username = vim.fn.input("Enter your username: ")
	local password = vim.fn.inputsecret("Enter your password: ")

	print("Logging in to RocketNotes...")
	local url = "https://cognito-idp.eu-central-1.amazonaws.com/"
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

				save_tokens(id_token, access_token, refresh_token)
			else
				print("Login failed:", response)
			end
		end
	else
		print("Curl command failed with result code:", result)
	end
end

return M
