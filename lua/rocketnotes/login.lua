local tokens = require("rocketnotes.tokens")
local utils = require("rocketnotes.utils")

---@class LoginModule
local M = {}

M.login = function()
	local id_token, access_token, refresh_token, clientId, api_url, domain, region, username, password =
		tokens.get_tokens()

	local inputToken = vim.fn.input(
		domain and region and api_url and clientId and "Enter config token (%s, %s, %s, %s): " or "Enter config token: "
	)

	if inputToken ~= "" then
		local decoded_token = vim.fn.json_decode(utils.decode_base64(inputToken))
		domain = decoded_token.domain
		region = decoded_token.region
		api_url = decoded_token.apiUrl
		clientId = decoded_token.clientId
	end

	local username_input =
		vim.fn.input(username and string.format("Enter your username (%s): ", username) or "Enter your username: ")
	username = username_input ~= "" and username_input or username
	local password_input = vim.fn.inputsecret(
		password and string.format("Enter your password (********): ", password) or "Enter your password: "
	)
	password = password_input ~= "" and password_input or password

	tokens.update_tokens_from_username_and_password(clientId, region, api_url, domain, username, password)
end

return M
