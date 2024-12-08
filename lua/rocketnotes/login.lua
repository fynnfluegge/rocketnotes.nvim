local tokens = require("rocketnotes.tokens")

---@class LoginModule
local M = {}

M.login = function()
	local id_token, access_token, refresh_token, clientId, api_url, domain, region, username, password =
		tokens.get_tokens()
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
				id_token = io.popen(string.format("echo '%s' | jq -r .IdToken", auth_result)):read("*all")
				access_token = io.popen(string.format("echo '%s' | jq -r .AccessToken", auth_result)):read("*all")
				refresh_token = io.popen(string.format("echo '%s' | jq -r .RefreshToken", auth_result)):read("*all")

				print("Login successful!")
				-- print("ID Token:", id_token)
				-- print("Access Token:", access_token)
				-- print("Refresh Token:", refresh_token)

				tokens.save_tokens(
					id_token,
					access_token,
					refresh_token,
					clientId,
					apiUrl,
					domain,
					region,
					username,
					password
				)
			else
				print("Login failed:", response)
			end
		end
	else
		print("Curl command failed with result code:", result)
	end
end

return M
