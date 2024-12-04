local save_tokens = require("rocketnotes.tokens").save_tokens
local get_tokens = require("rocketnotes.tokens").get_tokens
local tokens = require("rocketnotes.tokens")
local utils = require("rocketnotes.utils")
local assert = require("luassert")
local mock = require("luassert.mock")
local json = require("dkjson")
local busted = require("busted")

local token_file_path = "/tmp/tokens.json"
local response_file_path = "/tmp/cognito_login_response.json"

describe("save_tokens", function()
	local id_token = "id_token_value"
	local access_token = "access_token_value"
	local refresh_token = "refresh_token_value"
	local client_id = "client_id_value"
	local apiUrl = "api_url_value"
	local domain = "domain_value"
	local region = "region_value"
	local username = "username_value"
	local password = "password_value"

	before_each(function()
		os.remove(token_file_path)
		local utils_mock = mock(utils, true)
		utils_mock.get_config_path.returns("/tmp")
	end)

	after_each(function()
		os.remove(token_file_path)
	end)

	it("should save tokens to the file", function()
		save_tokens(id_token, access_token, refresh_token, client_id, apiUrl, domain, region, username, password)

		local file = io.open(token_file_path, "r")
		assert.is_not_nil(file)

		local content = file:read("*a")
		file:close()

		local expected_content = string.format(
			'{"IdToken": "%s", "AccessToken": "%s", "RefreshToken": "%s", "ClientId": "%s", "ApiUrl": "%s", "Domain": "%s", "Region": "%s", "Username": "%s", "Password": "%s"}',
			id_token,
			access_token,
			refresh_token,
			client_id,
			apiUrl,
			domain,
			region,
			username,
			password
		)

		assert.are.equal(expected_content, content)
	end)
end)

describe("get_tokens", function()
	before_each(function()
		local utils_mock = mock(utils, true)
		utils_mock.get_config_path.returns("/tmp")

		local file = io.open(token_file_path, "w")
		file:write(
			'{"IdToken": "id_token", "AccessToken": "access_token", "RefreshToken": "refresh_token", "ClientId": "client_id", "ApiUrl": "apiUrl", "Domain": "domain", "Region": "region", "Username": "username", "Password": "password"}'
		)
		file:close()

		_G.vim = {
			fn = {
				json_decode = function(content)
					local decoded, pos, err = json.decode(content)
					if err then
						error("Invalid JSON: " .. err)
					end
					return decoded
				end,
			},
		}
	end)

	after_each(function()
		os.remove(token_file_path)
		_G.vim = nil
	end)

	it("should return tokens from the mocked file path", function()
		local id_token, access_token, refresh_token, clientId, apiUrl, domain, region, username, password = get_tokens()

		assert.are.equal("id_token", id_token)
		assert.are.equal("access_token", access_token)
		assert.are.equal("refresh_token", refresh_token)
		assert.are.equal("client_id", clientId)
		assert.are.equal("apiUrl", apiUrl)
		assert.are.equal("domain", domain)
		assert.are.equal("region", region)
		assert.are.equal("username", username)
		assert.are.equal("password", password)
	end)

	it("should return nil values if the token file is not found", function()
		os.remove(token_file_path)

		local id_token, access_token, refresh_token, clientId, apiUrl, domain, region, username, password = get_tokens()

		assert.is_nil(id_token)
		assert.is_nil(access_token)
		assert.is_nil(refresh_token)
		assert.is_nil(clientId)
		assert.is_nil(apiUrl)
		assert.is_nil(domain)
		assert.is_nil(region)
		assert.is_nil(username)
		assert.is_nil(password)
	end)

	it("should return nil values if the token file is empty", function()
		local file = io.open(token_file_path, "w")
		file:write("")
		file:close()

		local id_token, access_token, refresh_token, clientId, apiUrl, domain, region, username, password = get_tokens()

		assert.is_nil(id_token)
		assert.is_nil(access_token)
		assert.is_nil(refresh_token)
		assert.is_nil(clientId)
		assert.is_nil(apiUrl)
		assert.is_nil(domain)
		assert.is_nil(region)
		assert.is_nil(username)
		assert.is_nil(password)
	end)
end)

describe("refresh_token", function()
	local original_tokens_get_tokens
	local original_tokens_save_tokens
	before_each(function()
		local file = io.open(token_file_path, "w")
		file:write(
			'{"IdToken": "id_token", "AccessToken": "access_token", "RefreshToken": "refresh_token", "ClientId": "client_id", "ApiUrl": "apiUrl", "Domain": "domain", "Region": "region", "Username": "username", "Password": "password"}'
		)
		file:close()

		original_tokens_get_tokens = tokens.get_tokens
		tokens.get_tokens = function()
			return "id_token",
				"access_token",
				"refresh_token",
				"client_id",
				"apiUrl",
				"domain",
				"region",
				"username",
				"password"
		end

		local os_mock = mock(os, true)
		os_mock.execute.returns(0)

		original_tokens_save_tokens = tokens.save_tokens
		tokens.save_tokens = function() end

		_G.vim = {
			fn = {
				json_decode = function(content)
					local decoded, pos, err = json.decode(content)
					if err then
						error("Invalid JSON: " .. err)
					end
					return decoded
				end,
			},
		}
	end)

	after_each(function()
		_G.vim = nil
		os.remove(token_file_path)
		os.remove(response_file_path)
		tokens.get_tokens = original_tokens_get_tokens
		tokens.save_tokens = original_tokens_save_tokens
	end)

	it("should call save_tokens when tokens are refreshed successfully", function()
		local file = io.open(response_file_path, "w")
		file:write('{"id_token": "new_id_token", "access_token": "new_access_token" }')
		file:close()

		local tokens_mock = busted.mock(tokens)

		tokens.refresh_token()

		assert.spy(tokens_mock.save_tokens).was_called_with(
			"new_id_token",
			"new_access_token",
			"refresh_token",
			"client_id",
			"apiUrl",
			"domain",
			"region",
			"username",
			"password"
		)
	end)

	it("should handle refresh token expiration", function()
		local file = io.open(response_file_path, "w")
		file:write('{"error": "NotAuthorizedException"}')
		file:close()

		local tokens_mock = busted.mock(tokens)

		tokens.refresh_token()

		assert.spy(tokens_mock.save_tokens).was_not_called()
	end)
end)
