local save_tokens = require("rocketnotes.tokens").save_tokens
local get_tokens = require("rocketnotes.tokens").get_tokens
local utils = require("rocketnotes.utils")
local assert = require("luassert")
local mock = require("luassert.mock")
local json = require("dkjson") -- You can use any JSON library for Lua

local token_file_path = "/tmp/tokens.json"

describe("save_tokens", function()
	-- Mock data
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
		local test = mock(utils, true)
		test.get_config_path.returns("/tmp")
	end)

	after_each(function()
		-- Remove the mock token file
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

		print(content)

		assert.are.equal(expected_content, content)
	end)
end)

describe("get_tokens", function()
	before_each(function()
		-- Mock the get_token_file function
		local test = mock(utils, true)
		test.get_config_path.returns("/tmp")

		-- Create a mock token file with content
		local file = io.open(token_file_path, "w")
		file:write(
			'{"IdToken": "id_token", "AccessToken": "access_token", "RefreshToken": "refresh_token", "ClientId": "client_id", "ApiUrl": "apiUrl", "Domain": "domain", "Region": "region", "Username": "username", "Password": "password"}'
		)
		file:close()

		-- Mock the vim global object and its fn.json_decode function
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
		-- Remove the mock token file
		os.remove(token_file_path)

		-- Clear the vim global object
		_G.vim = nil
	end)

	it("should return tokens from the mocked file path", function()
		-- Call the get_tokens function
		local id_token, access_token, refresh_token, clientId, apiUrl, domain, region, username, password = get_tokens()

		-- Assert the returned values
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

		-- Call the get_tokens function
		local id_token, access_token, refresh_token, clientId, apiUrl, domain, region, username, password = get_tokens()

		-- Assert the returned values are nil
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
		-- Create an empty mock token file
		local file = io.open(token_file_path, "w")
		file:write("")
		file:close()

		-- Call the get_tokens function
		local id_token, access_token, refresh_token, clientId, apiUrl, domain, region, username, password = get_tokens()

		-- Assert the returned values are nil
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
